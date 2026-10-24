---
name: alien-integration
description: Implement an approved Alien design end to end in a repository, whether it deploys an agent, a cache, the part of the product that touches customer data (a control plane / data plane split), or the whole product. Covers installing the alien CLI, writing a readable alien.ts, handlers with @alienplatform/sdk, inputs and generated secrets, frozen and live resources, commands and remote bindings from your backend, local runs with alien dev, tests with @alienplatform/testing, releases from CI, the vendor control-plane integration with @alienplatform/platform-api (setup links, status, endpoints), the customer runbook, and validation in a real cloud. Use after the alien-architecture skill, when docs/alien-architecture.md exists, or when asked to add Alien, BYOC, customer-managed keys, local models, Remote Operator, single-tenant, on-prem, or Kubernetes deployments to a repo, or to move a Helm, Terraform, or Ansible deploy flow onto Alien.
license: Apache-2.0
compatibility: Requires Node.js 20+, Docker for alien dev, and network access to alien.dev. Cloud validation needs an AWS, Google Cloud, or Azure account the user controls.
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien integration

You are implementing a design that is already decided. The work is mostly understanding the
existing system and a little code. Do not write integration code until you can answer from the
code itself: how is this deployed today, and where does each process get its configuration?

## Before you start

1. **Read the decision record.** `docs/alien-architecture.md` names the option, what runs where,
   and what crosses the boundary. If it is missing or not approved, run the `alien-architecture`
   skill first. For a standalone path (only customer-managed keys, only local models, only Remote
   Operator), a short record is enough.
2. **Read the docs for what you will build.** Fetch pages as Markdown from
   `https://alien.dev/docs/<path>.md`; the index is `https://alien.dev/llms.txt`. Start with
   `quickstart`, `build/stacks`, `build/frozen-and-live`, `build/inputs-and-secrets`, and the
   pages for each resource you use under `reference/resources/`. Docs win over this skill and
   over memory when they differ.
3. **Pin versions.** Use one version for every `@alienplatform/*` package. Check the published
   types (`node_modules/@alienplatform/*/dist/*.d.ts`) before using an API.

## Approval gates

Stop and ask the user before each of these. They are visible to customers or cost money.

| Action | Why |
|---|---|
| `alien release` to a real project, or `alien releases promote` | Every deployment on the channel updates |
| Creating or onboarding a customer deployment, or sending a setup link | Creates resources in someone's cloud |
| Changing CI workflows, or pushing to a branch that triggers them | A push can be a release or a deploy |
| Deploying to a real cloud account | Costs money, may hit quotas |
| Deleting deployments or cloud resources | Irreversible |
| Changing the product's core code outside the integration surface | Reviewers must accept it |

## Phases

Load each reference when you reach its phase.

### 1. Profile → `references/profiling.md`

Profile only what the decision record moves. Write the effect inventory of the current deploy
path, how config and secrets reach each process, what must survive an upgrade, and special
compute. Check cloud quotas for special compute on day one.

### 2. Install and scaffold

```bash
curl -fsSL https://alien.dev/install | sh     # or: brew install alienplatform/tap/alien
alien init                                     # interactive template choice
```

Inside an existing repository, `alien init` writes to an `alien/` directory by default. You can
also write `alien.ts` by hand. Docker must be running for `alien dev`. Keep the integration in its own directory or workspace
package with its own lockfile when the repo's dependency graph is sensitive.

### 2b. Existing chart or images → `references/existing-app.md`

If the repo already ships container images with a Helm chart or compose file and the whole
product installs remotely, follow that file before writing `alien.ts`: render the chart, check
every image, show the mapping, then convert Jobs, sidecars, and config files as it describes. A
chart that looks unsupported at first reading almost never is.

### 3. Write `alien.ts` → `references/alien-ts.md`

Declare what the decision record deploys and nothing else. Rules that reviewers check:

- Named declarations, one per resource, with a comment saying what it holds and why it is frozen
  or live. No loops that generate workloads from a list.
- Frozen or live per resource. Lead every choice with permissions: frozen needs fewer management
  permissions and changes need the admin; live is updated by Alien on every release.
- Inputs: `providedBy: "developer"` for values you set per deployment (your API URL, public
  keys), `providedBy: "deployer"` only for real choices the customer's admin makes. Generate
  internal secrets with `generate: { length }`. Credentials for linked resources come from
  `.link()`, never from inputs.
- Name every linked resource in a permission profile. Avoid `"*"` in production stacks.
- Pick compute from how requests behave: `Worker` for request/response and commands, `Container`
  for long-running services, ports, GPUs, or vendor images, `Daemon` for one process per host.

### 4. Write the code that runs in the deployment

Use `@alienplatform/sdk` in the workload: `command()` for functions your backend calls,
`storage()`, `kv()`, `queue()`, `vault()`, `postgres()` for linked resources. Return counts and
status from commands, not content. Do not edit the product's core to fit Alien; wrap it, and put
any required core change behind an opt-in flag that leaves current behavior unchanged.

### 5. Reach the deployment from your backend → `references/reach-a-deployment.md`

Implement every row of the decision record's "what crosses" table, and nothing else: deployment
to your backend over outbound HTTPS, your backend to the deployment with commands or remote
bindings, browser to the deployment with a short-lived token.

### 6. Run locally and test → `references/local-dev-and-tests.md`

`alien dev` builds, releases, and deploys once. It does not watch files: restart it to pick up
code changes. Local deployments are addressed as `local-dev/<name>`. Write tests with
`@alienplatform/testing` that call real commands and assert the product's behavior.

### 7. Release from CI → `references/releases-and-ci.md` (approval gate)

Release first, then deploy to a customer. `alien release` builds, pushes images, and moves the
`production` channel. Published is not deployed: deployments follow a channel or a pin.

### 8. Integrate the vendor control plane → `references/control-plane-integration.md`

Your backend creates setup links by `externalId`, polls deployment status, reads endpoints, and
owns product activation. Use `@alienplatform/platform-api`. The workspace API key never reaches a
browser.

### 9. Standalone paths → `references/standalone-paths.md`

Customer-managed keys, local models, Remote Operator on an existing install, single-tenant,
Kubernetes, and Linux machines. Use when the decision record picks one of these.

### 10. Design patterns → `references/patterns.md`

Load when the record picks a service overlay, a local cache, host daemons, stateless execution,
or AI access from a workload.

### 11. Customer runbook and white-label → `references/customer-runbook.md`

Write the runbook the customer's admin and your support team will follow. Check every
customer-visible surface for leftover internal names.

### 12. Validate → `references/validation.md` (approval gate for cloud steps)

Local → real cloud with the white-labeled customer CLI → a second release while the first is live
→ teardown audit. Record exact commands; they become the verify section of the PR.

## Classify every blocker

When something fails, decide which kind it is before changing anything:

| Kind | Examples | Action |
|---|---|---|
| Integration config | wrong permission profile, missing link, input not set, wrong platform list | Fix in `alien.ts` or the deployment |
| Environment | quota, model access not enabled, Docker not running, stale binary, expired token, third-party outage | Fix the environment; document it in the runbook |
| Product defect (Alien) | documented behavior does not happen, a crash in the CLI | Write a minimal reproduction and tell the user; do not work around it in the product core |
| Product defect (the user's app) | the app fails the same way without Alien | Report to the user; do not hide it in the integration |

Rule out the boring causes first: stale local builds, a stale API key in `.env`, laptop sleep,
a provider outage.

## Rules

1. Prefer existing primitives (`Postgres`, `Vault`, `Kv`, setup containers, commands) over
   adapters or new infrastructure. If a primitive is missing, say so; do not build a parallel
   system.
2. Inventory every effect of the legacy deploy path before replacing any of it.
3. Never fall back across the trust boundary. A lookup error refuses the request.
4. Model infrastructure health, runtime activation, and product readiness separately. Running is
   not usable.
5. If a supervisor adopts a running process, include the rendered config in its identity (hash
   it). Otherwise config-only releases never apply.
6. Pin CPU architecture at artifact boundaries. AWS Workers build for arm64 by default; vendor
   amd64 images need a `Container`.
7. If a client can fall back to its own provider key, a working request proves nothing. Unset the
   key and watch the deployment's counter move.
8. Before exposing a tool that trusts loopback callers, make its token mandatory, fail startup
   without it, and probe admin routes (with a spoofed `Host`) for any `200`.
9. After changing a port, entrypoint, or path, grep every kept workflow, health check, and compose
   file for the old value.
10. Explain product-specific concepts in the user's terms before using them. Keep Alien's internal
    vocabulary out of the product's customer-facing text.
11. Never commit credentials, private plans, or evidence screenshots to the repository.
12. No customer or prospect names in code, commits, or docs; use `customer-1`.

## Deliver

A branch the maintainers will merge: added surface large, changed surface small. The PR body
lists what this adds, the architecture in five lines (link the decision record), every change to
the core with its justification, and the validation commands a maintainer can rerun. Run a
minimum-diff audit twice: for each hunk outside the integration, ask whether it is still needed
and whether it can move into the integration.
