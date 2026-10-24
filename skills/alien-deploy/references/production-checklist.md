# Production checklist

Check every item before the first customer sees a setup link. Details for each group are on the matching docs page under
`https://alien.dev/docs/integrate`.

## Credentials and identity
- Keep the Alien API key on your backend. Create a project-scoped key with only the roles you need (`alien api-keys create --for deployments`); use a separate `project-admin` key only for removal.
- Use a separate Alien project for staging, with its own key and its own portal domain, so tests never create setup links for real customers.
- Resolve the external ID from the signed-in session, never from the request body. Use an immutable ID, not a name.
- The setup token is the only credential the customer sees. It can set up deployments for one customer and nothing else; still, treat the link as a credential: don't log it or store it longer than needed.
- Don't forward raw Alien responses to the browser. Return only the fields your page shows.
- If each deployment needs a credential for your service, pass it as a setup input or env var on the link and derive it deterministically (for example an HMAC of the customer ID), so a new link doesn't rotate it.
- Check that the returned deployment group's external ID is the one you asked for before storing it.

## Setup links
- Create the link when the admin clicks, not when the page renders. A page view should never mint credentials.
- Set `maxDeployments` (usually 1) and an `expiresAt` (for example 7 days). A customer who starts over gets a new link for the same group.
- Restrict `allowedPlatforms` and `allowedSetupMethods` to what you support and test. Put sizes and network in `stackSettings.defaults`.
- Always include `setupItems`.
- Keep the group name short and DNS-safe. It becomes a prefix on resources in the customer's account.
- Decide what one group is: usually one customer organization, sometimes one customer environment. Use a list filtered by `purpose=application` to find the application deployment.
- Don't revoke a link while a deployment created from it exists. The customer's stack uses that token when it is deleted.

## Launch
- Start with the portal link. It records the install before the cloud console opens and resumes on reload. Build your own launch only for your main cloud.
- If you build the CloudFormation URL yourself, read the template URL, managing role and external ID from `GET /v1/deployment-info` with the setup token every time; don't cache or hard-code them. Always pass `ManagementExternalId`.
- Open the browser tab before awaiting your backend so popup blockers allow it.
- Only pass `param_*` values the template declares, and keep them equal to the link's defaults.

## Tracking progress
- Poll from a background job, not from the browser. Poll slower while waiting for the admin, faster while provisioning; back off exponentially on API errors; stop when the state settles.
- With your own launch URL, nothing exists in Alien until the stack registers. Show "Waiting for AWS" and, after a long silence (for example a day), say the stack may have failed in AWS and offer to start over.
- Map statuses to a few product states. Waiting is not an error; don't show a percentage from elapsed time.
- Hide the first automatic retry error of a step; show the second. Show final failures and anything the customer must do immediately.
- Show `error.message` and a ### Retry###  button on failure. Don't parse `stackState`; it is internal.

## Verify and activate
- `running` means Alien finished. Prove the service works from where your product calls it (a real request, a test document), then flip your own "active" flag.
- For private endpoints, run the check from the caller's network.
- Treat a stale heartbeat as "not connected", not as "down".
- Base product readiness on your own signal (your service's heartbeat or health endpoint) so a brief Alien API outage doesn't mark a healthy deployment as down.
- If the stack needs secrets from the customer, show the missing ones on your page from the deployment's deployer-secret status, with the command to add each. You never see the values.

## Sizes and cost
- Offer two or three sizes mapped to container CPU, memory and disk. Keep disk separate: it only grows.
- Show an approximate monthly cloud cost per size, labeled as an estimate. Ask the Alien team if you need help estimating it.
- After a resize, follow the returned operation and show the new size only when it succeeds.

## Concurrency and idempotency
- Lock per customer deployment around create, resize, retry and remove.
- Store your own record (group ID, deployment ID, state) and reconcile it from Alien; Alien is the source of truth for deployment state, you are for activation.

## Removal
- Use `forget` when nothing registered, `cleanup` otherwise. Expect `teardown-required` and tell the admin exactly which stack to delete.
- Keep your record "removing" until Alien reports `deleted`.
- Build removal into the product before launch. Removal needs a key with the `project.admin` role; deleting only your own database row leaves the deployment running in the customer's cloud.

## Branding and support
- Set the portal title, colors, support and docs URLs, and a custom domain before the first customer sees a link.
- Rename the setup CLI and give Google sign-in your own OAuth client if customers use GCP.
- Open a setup link in a private window before every major release to see what the admin sees.

## Testing
- Keep a test cloud account per platform you offer and run the full install → update → resize → remove loop before you announce a new cloud.
- Put the Alien calls behind an interface in your backend so local development and CI run without a cloud account.
