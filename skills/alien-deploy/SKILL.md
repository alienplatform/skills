---
name: alien-deploy
description: Adds customer deployment to a vendor's product with Alien, so the customer's admin can set up, watch, resize, and remove a deployment from inside the product. Use when building a settings page where a customer connects their cloud (BYOC), customer-managed keys, their AI models, or their storage; creating setup links; adding a Deploy button that opens the hosted deployment portal; building a custom setup screen or CloudFormation launch; branding the portal; showing deployment status; resizing; or removing a deployment. Asks a few multiple-choice questions, reads the product, writes the backend and UI, and verifies with a real deployment in a test account. Not for writing alien.ts (alien-integration) or debugging a running deployment (alien-operate).
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien deploy

The customer's admin should be able to set up, watch, change, and remove your deployment from
inside your product. This skill builds that flow: the backend calls to Alien, the settings page,
and the checks that prove it works.

Your backend holds the Alien API key and makes every call. The browser never sees the key. The
customer's admin gets a **setup link**, opens it in the **deployment portal** (the setup page Alien
hosts) or on your own setup screen, and runs **initial setup**, the one-time step in their own
account with their own credentials. After that, Alien rolls out releases without the admin.

## Docs

Fetch these as Markdown. They are the source of truth for every API field.

- https://alien.dev/docs/deployment-ux.md (how to offer setup)
- https://alien.dev/docs/deployment-ux/setup-links.md
- https://alien.dev/docs/deployment-ux/deploy-button.md
- https://alien.dev/docs/deployment-ux/setup-screen.md (only for your own setup screen)
- https://alien.dev/docs/deployment-ux/deployment-progress.md
- https://alien.dev/docs/deployment-ux/errors-and-retries.md
- https://alien.dev/docs/deployment-ux/verify-and-activate.md
- https://alien.dev/docs/deployment-ux/sizes-and-networks.md
- https://alien.dev/docs/deployment-ux/resize-a-deployment.md
- https://alien.dev/docs/deployment-ux/remove-a-deployment.md
- https://alien.dev/docs/deployment-ux/follow-removal.md
- https://alien.dev/docs/deployment-ux/branding.md
- https://alien.dev/docs/deployment-ux/deployment-portal.md
- https://alien.dev/docs/production/webhooks.md
- REST reference: https://alien.dev/docs/reference/api.md, and the TypeScript client at
  https://alien.dev/docs/reference/sdk/platform-api.md

## Workflow

Copy this checklist and tick it off:

```text
- [ ] 1. Ask the questions
- [ ] 2. Read the product
- [ ] 3. Build the Deploy button flow
- [ ] 4. Build your own setup screen (only if chosen)
- [ ] 5. Go through the production checklist; fix and recheck
- [ ] 6. Verify end to end in a test account; fix and rerun
```

### 1. Ask

One batch, multiple choice, each with **Other**. Pre-select from what the code shows.

1. **What should the customer connect?** (multi-select) Their cloud account for a deployment /
   their encryption key / their AI models / their storage / remote sandboxes / Other
2. **Which platforms?** (multi-select) AWS / Google Cloud / Azure / Kubernetes / Linux servers /
   Other
3. **How does the admin set up?** A Deploy button that opens the deployment portal (recommended) /
   your own setup screen in your product / both: your screen for your main cloud, the portal for
   the rest / Other
4. **What is one deployment for?** One per customer organization / one per customer environment
   (for example per project or workspace) / several per customer / Other

### 2. Read the product

Find, with file paths: the settings area and its UI framework; how the signed-in session resolves
your customer's organization (this becomes the **external ID**, your own immutable ID for the
customer); the background job system; any existing per-customer records and locks; how the
backend calls other APIs (language, HTTP client). Many backends aren't TypeScript: use plain HTTP
when the TypeScript client doesn't fit.

### 3. Build the Deploy button flow

Build this first even if the user chose their own setup screen. It is the fallback, and the only
path for Google Cloud sign-in and Linux servers.

1. A backend route that creates a setup link for the signed-in customer's external ID, on click.
2. A button on the settings page that opens the returned portal link in a new tab.
3. A background job, or a webhook receiver, that finds the deployment in your customer's
   deployment group and stores its status in your own record.
4. Status shown on the page, mapped to a few product states (see `deployment-progress`).
5. Verify and activate: your own check that the deployment serves, then your own "active" flag.
6. A remove action.
7. Branding: portal title, colors, support and docs URLs, and a custom domain, in the dashboard
   or with `alien projects portal set`.

### 4. Build your own setup screen (when chosen)

Add on top of step 3:

1. Create the deployment with the setup link's token: `POST /v1/deployments` with
   `setupHandoff: "await-registration"` and `installation`. The response holds the setup step:
   `installation.launchUrl` for CloudFormation, or the Terraform, Helm, or setup CLI commands.
2. Save the deployment ID before you return. **Reopen setup** calls
   `POST /v1/deployments/{id}/installation`, which returns the same setup step.
3. Show the waiting states: `pending` with no heartbeat, CloudFormation stack building, stack
   rolled back.
4. Sizes and networks, missing customer secrets (`runtimeMetadata.deployerSecrets`), resize, and
   retry.

Put every Alien call behind one interface with a local implementation, so development and CI run
without Alien or a cloud account.

### 5. Production checklist

Go through every item in [references/production-checklist.md](references/production-checklist.md).
Fix what fails, then check those items again. Report which items don't apply and why.

### 6. Verify end to end

1. Create a setup link in a staging project and open it in a private window.
2. Run initial setup in a test cloud account you control. Watch every status your page shows.
3. Release again and see the update arrive without the admin.
4. Resize, if offered.
5. Remove it. Go through `teardown-required` if the cloud needs it, until the deployment is
   `deleted` (or `retained` when data was kept).
6. Check that your own records match Alien's at each step.

If a step fails or your page shows the wrong state, fix the code and run the loop again from the
step that failed.

## Rules

1. The Alien API key stays on your backend. Return only the fields your page shows.
2. Resolve the external ID from the session, never from the request body.
3. Create setup links on click, not on page render, with `maxDeployments` and `expiresAt`.
4. A setup link only authorizes initial setup. Each deployment gets its own deployment token, so
   an expired or revoked link doesn't break deployments it created. Revoke links you no longer
   need after the deployment is `deleted`.
5. Don't parse `stackState`. Don't show percentages or ETAs: resources finish in parallel. Show
   a resource's `progress` text as is and never branch on it.
6. Hide the first automatic retry error of a step; show the second.
7. `running` means Alien finished. Your product decides when the customer is active.
8. Send the whole `containers` section on every resize. Disks only grow.
9. Removal is part of the first version, not a follow-up.
10. No customer names in code, fixtures, or UI copy. Use `acme` and `customer-1`.

## References

- [references/production-checklist.md](references/production-checklist.md): every check before the
  first customer sees a setup link. Load at step 5, and again before a launch to a new cloud.

## Output

- The backend routes, job, records, and settings page in the user's repository.
- A short report: what the admin sees at each step, checklist items that don't apply, and what was
  verified in a real account.
