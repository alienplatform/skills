# Production checklist

Check every item before the first customer sees a setup link. Copy the list, tick what passes, fix
what fails, and check it again. Details are on the matching pages under
`https://alien.dev/docs/deployment-ux.md` and in
`https://alien.dev/docs/production/go-live-checklist.md`.

## Credentials and identity

- [ ] The Alien API key lives on your backend. It is a project-scoped key with only the roles you need (`alien api-keys create --for deployments`).
- [ ] Removal uses a separate key with the `project.admin` role (`alien api-keys create --for project-admin`), used only where removal runs.
- [ ] Staging uses a separate Alien project, with its own key and its own portal domain, so tests never create setup links next to real customers.
- [ ] The external ID comes from the signed-in session, never from the request body. It is an immutable ID, not a name or a slug.
- [ ] The setup token is the only credential the customer sees. It can set up deployments for one customer and nothing else. Still treat the link as a credential: don't log it or store it longer than needed.
- [ ] Raw Alien responses never reach the browser. Your backend returns only the fields your page shows.
- [ ] If each deployment needs a credential for your service, pass it as a setup input or env var on the link and derive it deterministically (for example an HMAC of the customer ID), so a new link doesn't rotate it.
- [ ] Before you store a deployment group, check that its external ID is the one you asked for.

## Setup links

- [ ] Links are created when the admin clicks, not when the page renders. A page view never mints credentials.
- [ ] Each link sets `maxDeployments` (usually 1) and an `expiresAt` (for example 7 days). A customer who starts over gets a new link for the same group.
- [ ] `allowedPlatforms` and `allowedSetupMethods` list only what you support and tested. Sizes and network are in `stackSettings.defaults`.
- [ ] `setupItems` lists what the customer connects (keys, models, bucket, sandbox), each with `required`. Omit it for a link that only deploys your stack.
- [ ] The group name is short and DNS-safe. It becomes a prefix on resources in the customer's account.
- [ ] You decided what one group is: usually one customer organization, sometimes one customer environment.
- [ ] To find the deployment, list `GET /v1/deployments?project=…&deploymentGroup=…` and skip `delete-pending`, `deleting`, `deleted`, and `retained`. A lost group ID comes back from `GET /v1/deployment-groups/by-external-id`.
- [ ] Links you no longer need are revoked only after the deployment is `deleted`. Revoking doesn't break deployments that hold their own token, but older CloudFormation stacks launched with the link's token can be deleted only after Alien removed their resources.

## Launch

- [ ] Start with the Deploy button and the portal. The portal records the deployment before the cloud console opens and resumes on reload. Build your own setup screen only for your main cloud.
- [ ] Google Cloud sign-in and Linux servers go through the portal. Your own screen can't run them.
- [ ] On your own setup screen, create the deployment with the setup token (`POST /v1/deployments`, `setupHandoff: "await-registration"`) and use the `installation` it returns. Don't build or cache the launch URL yourself.
- [ ] Right after a release, `409` `INSTALLATION_NOT_READY` means the setup package is still building. Show "Preparing the setup" and try again in a minute.
- [ ] The browser tab opens before you await your backend, so popup blockers allow it.

## Tracking progress

- [ ] A background job polls, or a webhook receiver listens (`deployment.running`, `deployment.failed`, `deployment.update_blocked`, `deployment.teardown_required`). The browser doesn't poll Alien.
- [ ] Polling is every 10 to 30 seconds while someone watches and every few minutes otherwise. On API errors it doubles the delay up to two minutes. It stops when the state settles.
- [ ] `pending` with no heartbeat shows "Waiting for setup". Opening the cloud console proves nothing. A rolled-back CloudFormation stack (`setupMetadata.setupReservation.rolledBackAt`) asks the admin to delete it and start again.
- [ ] Statuses map to a few product states. Waiting is not an error. No percentage from elapsed time. A first deployment usually takes 10 to 20 minutes; say so once.
- [ ] The first automatic retry error of a step is hidden; the second shows. Final failures and anything the customer must do now always show.
- [ ] On failure, the page shows `error.message` and a **Retry** button, except when `error.retryable` is `false`. `stackState` is internal: don't parse it.

## Verify and activate

- [ ] `running` means Alien finished. Prove the service works from where your product calls it (a real request, a test document), then flip your own "active" flag.
- [ ] For private endpoints, the check runs from the caller's network.
- [ ] A stale heartbeat reads as "not connected", not "down".
- [ ] Product readiness rests on your own signal (your service's heartbeat or health endpoint), so a brief Alien API outage doesn't mark a healthy deployment as down.
- [ ] If the stack needs secrets from the customer, your page shows the missing ones from `runtimeMetadata.deployerSecrets`, with where to add each. You never see the values.

## Sizes and cost

- [ ] Two or three sizes map to container CPU, memory, and disk. Disk is separate: it only grows.
- [ ] Each size shows an approximate monthly cloud cost, labeled as an estimate. Alien doesn't return prices; compute it from the machine and disk sizes.
- [ ] After a resize, your page follows the returned operation and shows the new size only when it succeeds.

## Concurrency and idempotency

- [ ] A per-customer lock covers create, resize, retry, and remove.
- [ ] Your own record (group ID, deployment ID, state) is reconciled from Alien. Alien is the source of truth for deployment state; you are for activation.

## Removal

- [ ] Normal removal uses `action: "cleanup"`. `forget` (needs a workspace admin key) is only for a deployment whose initial setup never ran or whose resources are already gone.
- [ ] `teardown-required` and `retention-required` tell the admin exactly which stack to delete.
- [ ] Your record stays "removing" until Alien reports `deleted` or `retained`.
- [ ] Removal is built in before launch. Deleting only your own database row leaves the deployment running in the customer's cloud.

## Branding and support

- [ ] Portal title, colors, support and docs URLs, and a custom domain are set before the first customer sees a link.
- [ ] The setup CLI has your own command name, and Google sign-in uses your own OAuth client if customers use Google Cloud.
- [ ] Someone opens a setup link in a private window before every major release to see what the admin sees.

## Testing

- [ ] A test cloud account exists for each platform you offer. The full initial setup, update, resize, and remove loop runs there before you announce a new cloud.
- [ ] The Alien calls sit behind an interface in your backend, so local development and CI run without a cloud account.
