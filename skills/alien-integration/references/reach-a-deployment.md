# Reach a deployment from your backend

Implement exactly the rows in the decision record's "what crosses" table. Docs:
`https://alien.dev/docs/guide/design/connect-your-backend.md`, `guide/commands.md`,
`guide/remote-bindings.md`, `guide/networking.md`, `guide/inputs-and-secrets.md`.

## Contents

- Deployment to your backend
- Commands
- Remote bindings
- Browser to the deployment
- Uploads
- Checks before moving on

Your backend and each deployment talk in three directions:

| Direction | Mechanism | Carries |
|---|---|---|
| Deployment → your backend | Outbound HTTPS to your API | Usage counts, status, events |
| Your backend → deployment | Commands or remote bindings | Instructions and small results |
| Browser → deployment | A public or private endpoint with a short-lived token | Customer content |

Only the third needs an endpoint in the customer's environment, and that endpoint can stay on the
customer's private network. None of them needs an inbound port for your backend.

## Deployment to your backend

Code in the deployment calls your API like any other client. Give it your API's URL and a
credential as developer inputs, which you set when you create each deployment:

```ts title="alien.ts"
const config = alien.inputs({
  acmeApiUrl: alien.string({
    providedBy: "developer",
    required: true,
    label: "Acme API URL",
    description: "Where this deployment reports usage and status.",
    env: "ACME_API_URL",
  }),
  acmeApiToken: alien.secret({
    providedBy: "developer",
    required: true,
    label: "Acme API token",
    description: "Authenticates this deployment to your API.",
    env: "ACME_API_TOKEN",
  }),
})
```

Pass `config` to the stack with `.inputs(config)`; the code reads `process.env.ACME_API_URL`.
Rename `acme` to the product. The credential can also be a token your backend mints per
deployment.

- Send metadata only: IDs, counts, status. If you would not store it in your own database, do not
  send it.
- Retry with backoff. Your backend being down must not break content operations in the
  deployment.

## Commands

A command is a function in the deployment that your backend calls by name. The call goes through
Alien; the deployment picks it up over its own outbound connection, runs it, and returns the
result. Enable with `.commandsEnabled(true)` on the workload and register with `command()` from
`@alienplatform/sdk`.

```ts title="backend/process.ts"
import { CommandsClient } from "@alienplatform/commands"

const commands = await CommandsClient.forDeployment({
  deploymentId: customer.deploymentId,
  apiKey: process.env.ALIEN_API_KEY!,
})

const result = await commands.invoke("process-document", { path: "inbox/contract.pdf" })
```

- Return the smallest result your backend needs, such as a total or a status. A command that
  returns rows moves those rows.
- Validate parameters with a schema (`zod`) in the handler.
- From the CLI: `alien commands invoke --deployment <group>/<name> --command <name> --params '<json>'`.
  Locally: `alien dev commands invoke --deployment local-dev/<name> ...`.
- `alien commands invoke` targets your app's commands. Remote Operator operations use
  `alien operations invoke`. Do not mix them.

## Remote bindings

When your backend must read or write one resource in the customer's environment directly (for
example, keep a cache current, or use a customer's bucket or key), add the resource with
`remoteAccess: true`:

```ts title="alien.ts"
.add(jobs, "frozen", { remoteAccess: true })
```

Your backend gets short-lived cloud credentials scoped to that resource and calls the cloud's own
APIs. No network path into the customer's environment is involved.

```ts title="backend/sync.ts"
import { Bindings } from "@alienplatform/bindings"

const bindings = await Bindings.forRemoteCustomer({
  project: "docproc",
  externalId: customer.id,
  token: process.env.ALIEN_REMOTE_BINDINGS_KEY!,
})

await bindings.kv("jobs").setJson("settings", { retentionDays: 30 })
```

- Only resources you mark are reachable. Mark as few as possible.
- The remote bindings key has its own role (`alien api-keys create --for remote-bindings`); do not
  reuse the workspace API key.
- Use the same `externalId` you use for setup links (your customer or org ID).

## Browser to the deployment

1. The user signs in to your product as usual.
2. Your backend issues a short-lived token, signed with your private key, naming the customer and
   the user.
3. The browser calls the deployment's endpoint with that token. The deployment verifies the
   signature with your public key, passed as a developer input.

To rotate keys without a release, serve a JWKS from your backend instead. The deployment caches
it, refetches on an unknown key ID, and pins the issuer to your backend's URL. Put the
deployment's ID in the token's audience so a token for one deployment fails at another.

Details that break first:

- A plain link or download can't carry a header. Fetch the URL with the token, then navigate to
  the result.
- Event streams that put the token in the query string must keep it out of logs.
- Add every deployment origin to your app's CSP `connect-src`.
- The deployment checks the token on every request, and checks that the customer still belongs to
  this deployment. A valid token must not keep working after a customer moves.
- Prove it in the browser's network tab: content requests go to the deployment's origin, and
  your backend's origin shows only sign-in and metadata calls.

Audit the whole browser path: request bodies, URL paths and queries, navigation, telemetry, and
error reporting. On a tenant switch, discard the previous endpoint, token, and cached content.
The endpoint can be public or reachable only from the customer's network (`guide/networking`).

## Uploads

The deployment creates a signed upload URL for its own storage and returns it to the browser. The
browser uploads straight into the customer's bucket. Your backend sees the job, not the file.

A browser upload needs the bucket's CORS rules to allow `PUT` from your app's origin. Check the
Storage docs for upload CORS before relying on it, and test the upload from a real browser in a
cloud deployment. If it isn't available, the deployment can accept the upload and write it to
storage itself.

## Checks before moving on

- Every call in the code maps to a row in the decision record, with the same fields.
- No handler returns content to your backend unless the record says it does.
- Logs carry no request bodies or rows; logs reach the manager.
- Every failure path returns an error; none falls back to hosted processing.
