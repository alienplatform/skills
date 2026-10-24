---
name: alien-deploy
description: Add customer deployment to a vendor's product with Alien. Use when building a Settings page where a customer connects their cloud (BYOC), customer-managed keys, their AI models, or their storage; creating setup links; sending customers to the hosted deployment portal or building a custom CloudFormation launch; branding the portal; showing deployment status; resizing; or removing a deployment. Asks a few multiple-choice questions, reads the product, writes the backend and UI, and verifies with a real install in a test account. Not for writing alien.ts (alien-integration) or debugging a running deployment (alien-operate).
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien deploy

Your customer's admin should be able to install, watch, change, and remove your deployment from
inside your product. This skill builds that flow: the backend calls to Alien, the settings page, and
the checks that prove it works.

Your backend holds the Alien API key and makes every call. The browser never sees the key. The
customer's admin gets a setup link, opens it in the deployment portal (or your own page), and runs
setup in their own account with their own credentials.

## Read the docs first

Fetch these as Markdown. They are the source of truth for every API field.

- https://alien.dev/docs/integrate.md
- https://alien.dev/docs/integrate/setup-links.md
- https://alien.dev/docs/integrate/byoc-settings.md (only when building your own launch)
- https://alien.dev/docs/integrate/deployment-status.md
- https://alien.dev/docs/integrate/sizes-and-networks.md
- https://alien.dev/docs/integrate/remove-a-deployment.md
- https://alien.dev/docs/integrate/white-label.md
- https://alien.dev/docs/deploy/deployment-portal.md
- REST reference: https://alien.dev/docs/reference/api and the TypeScript client at
  https://alien.dev/docs/reference/sdk/platform-api.md

## Workflow

### 1. Ask

One batch, multiple choice, each with **Other**. Pre-select from what the code shows.

1. **What should the customer connect?** (multi-select) Their cloud account for a deployment /
   their encryption key / their AI models / their storage / remote sandboxes / Other
2. **Which platforms?** (multi-select) AWS / Google Cloud / Azure / Kubernetes / Linux servers /
   Other
3. **How does the admin install?** The hosted deployment portal (recommended) / your own settings
   page with your own launch button / both: your page for your main cloud, the portal for the rest
   / Other
4. **What is one deployment for?** One per customer organization / one per customer environment
   (for example per project or workspace) / several per customer / Other

### 2. Read the product

Find, with file paths: the settings area and its UI framework; how the signed-in session resolves
the customer's organization (this becomes the external ID); the background job system; any
existing per-customer records and locks; how the backend calls other APIs (language, HTTP client).
Many backends aren't TypeScript: use plain HTTP when the TS client doesn't fit.

### 3. Build the default flow

Do this first even if the user chose their own page; it's the fallback.

1. A backend route that creates a setup link for the signed-in customer's external ID, on click.
2. A button on the settings page that opens the returned link in a new tab.
3. A background job that finds the deployment by external ID and stores its status in your own
   record.
4. Status shown on the page, mapped to a few product states (see the docs page on status).
5. A remove action.
6. Branding: portal title, colors, support and docs URLs, custom domain, through the dashboard or
   the CLI.

### 4. Build your own page (when chosen)

Add on top of step 3: launch URL from `GET /v1/deployment-info` with the setup token, sizes and
networks, deployer-secret status, verify-and-activate using your own health signal, resize, retry.
Put every Alien call behind one interface with a local implementation, so development and CI run
without Alien or a cloud account.

### 5. Check the production checklist

Go through every item in `references/production-checklist.md` and fix what fails. Report which
items don't apply and why.

### 6. Verify end to end

1. Create a setup link in a staging project and open it in a private window.
2. Install into a test cloud account you control. Watch every status your page shows.
3. Release again and see the update arrive without the admin.
4. Resize, if offered.
5. Remove, through `teardown-required` if the cloud needs it, until the deployment is `deleted`.
6. Check your own records match Alien's at each step.

## Rules

1. The Alien API key stays on your backend. Return only the fields your page shows.
2. Resolve the external ID from the session, never from the request body.
3. Create setup links on click, with `maxDeployments`, `expiresAt`, and `setupItems`.
4. Never revoke a setup link while a deployment created from it exists.
5. Don't parse `stackState`. Don't show percentages computed from elapsed time.
6. Hide the first automatic retry error of a step; show the second.
7. "Running" means Alien finished. Your product decides when the customer is active.
8. Compute changes replace the whole section. Disk only grows.
9. Removal is part of the first version, not a follow-up.
10. No customer names in code, fixtures, or UI copy. Use `acme` and `customer-1`.

## Output

- The backend routes, job, records, and settings page in the user's repository.
- A short report: what the admin sees at each step, checklist items that don't apply, and what was
  verified in a real account.
