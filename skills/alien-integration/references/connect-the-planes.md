# Connecting the planes

Implement exactly the rows in the decision record's "what crosses" table. Docs:
`https://alien.dev/docs/design/connect-the-planes.md`, `build/commands.md`,
`build/remote-bindings.md`, `build/networking.md`.

| Direction | Mechanism | Carries |
|---|---|---|
| Data plane → control plane | Outbound HTTPS to your API | Counts, status, thin events |
| Control plane → data plane | Commands or remote bindings | Instructions and small results |
| Browser → data plane | Endpoint plus a short-lived token | Customer content |

None of these needs an inbound port in the customer's environment.

## Data plane to control plane

Give the data plane your API URL as a developer input and a credential (a developer secret, or a
token your control plane mints per deployment). Send metadata only: IDs, counts, status. If you
would not store it in the control plane's database, do not send it. Retry with backoff; the
control plane being down must not break content operations in the data plane.

## Commands

A command is a function in the data plane that your control plane calls by name. The data plane
picks it up over its own outbound connection. Enable with `.commandsEnabled(true)` on the
workload and register with `command()` from `@alienplatform/sdk`.

```ts title="control-plane/process.ts"
import { CommandsClient } from "@alienplatform/commands"

const commands = await CommandsClient.forDeployment({
  deploymentId: customer.deploymentId,
  apiKey: process.env.ALIEN_API_KEY!,
})

const result = await commands.invoke("process-document", { path: "inbox/contract.pdf" })
```

- Return the smallest result the control plane needs.
- Validate parameters with a schema (`zod`) in the handler.
- From the CLI: `alien commands invoke --deployment <group>/<name> --command <name> --params '<json>'`.
  Locally: `alien dev commands invoke --deployment local-dev/<name> ...`.
- `alien commands invoke` targets your app's commands. Remote Operator operations use
  `alien operations invoke`. Do not mix them.

## Remote bindings

When the control plane must read or write one resource directly (for example, keep a cache
current), add the resource with `remoteAccess: true`:

```ts title="alien.ts"
.add(jobs, "frozen", { remoteAccess: true })
```

The control plane gets short-lived credentials scoped to that resource and uses cloud APIs:

```ts title="control-plane/sync.ts"
import { Bindings } from "@alienplatform/bindings"

const bindings = await Bindings.forRemoteCustomer({
  project: "docproc",
  externalId: customer.id,
  token: process.env.ALIEN_REMOTE_BINDINGS_TOKEN!,
})

await bindings.kv("jobs").setJson("settings", { retentionDays: 30 })
```

- Only resources you mark are reachable. Mark as few as possible.
- The remote bindings token has its own role; do not reuse the workspace API key.
- Use the same `externalId` you use for setup links (your customer or org ID).

## Browser to data plane

1. User signs in to your product.
2. Your control plane issues a short-lived token signed with your private key, naming the
   customer and the user.
3. The browser calls the data plane endpoint with it. The data plane verifies with your public key,
   passed as a developer input.

Audit the whole browser path: request bodies, URL paths and queries, navigation, telemetry, and
error reporting. On a tenant switch, discard the previous endpoint, token, and cached content.
The endpoint can be public or private to the customer's network (`build/networking`).

## Uploads

The data plane creates a signed upload URL for its own storage and returns it to the browser. The
browser uploads straight into the customer's bucket. The control plane sees the job, not the file.

## Checks before moving on

- Every call in the code maps to a row in the decision record, with the same fields.
- No handler returns content to the control plane.
- Every failure path returns an error; none falls back to hosted processing.
