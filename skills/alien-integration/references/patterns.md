# Implementation patterns

Load the section the decision record calls for.

## Service overlay on an existing SaaS

Sensitive routes move to a runtime in the customer's account; identity, policy, billing, and
metadata stay in the existing SaaS. Clients keep the same API contract and one base URL.

- **Ownership before routing.** Persist one authoritative mode per tenant
  (`execution_mode = hosted | customer`). Starting customer mode is an atomic product transition.
  Once it begins, hosted handlers for sensitive routes reject calls, and revocation never
  silently switches the tenant back to hosted storage.
- **Classify every route**: `local` (customer runtime), `intercept` (commit at the authority,
  then apply locally), `proxy` (reviewed metadata-only), `denied` (default for anything new or
  unreviewed). Never pass a whole prefix through a generic proxy.
- **Two credentials.** A runtime credential proves which deployed runtime is calling; the user's
  credential proves tenant and scope. Forward the user's credential to the existing authorizer;
  do not duplicate authorization in the runtime.
- **Executable data contract.** Strict schemas on every hosted callback and event: enumerated
  fields, unknown keys rejected, sensitive fields absent from the schema.
- **Thin events.** Keep hosted webhook delivery; send IDs, and let the receiver fetch content from
  the customer runtime with an authenticated read.
- **Capabilities, not one ready flag.** Track installation complete, runtime active, product
  dependencies converging, and each capability ready. Gate only the surfaces that need the
  missing one.
- **Setup links are concurrent credentials.** A customer may click setup twice. First valid
  activation wins; later ones are rejected and recorded.

## A cache the customer reads locally

One `Kv` in the customer's account, written by the control plane through remote bindings, read by
the customer's app with its own identity.

- Define which reads tolerate lag. Locks, reservations, and atomic enforcement stay at the
  authority.
- Publish versioned snapshots from your existing evaluator; do not reimplement decision logic.
  Define snapshot identity, schema version, freshness, stale-on-error, and hard expiry.
- Enqueue refresh after the authoritative write. Inventory every mutation path, scheduled reset,
  and deletion; add periodic reconciliation for gaps.
- Use conditional writes (the KV `version`) to close read/write races.
- Separate identities: the app reads; only the control plane's binding writes.
- Test: upstream unreachable, stale window honored, hard expiry enforced, sync outage repaired
  without a manual step.

## Stateless execution in the customer's account

A hosted service runs sandboxes or jobs in the customer's account. Docs:
`integrate/remote-sandboxes`, `reference/resources/sandbox`.

- Route per tenant with a placement record. A tenant with no record takes today's path unchanged.
- Make the tenant ID a required field on the provision call so the compiler finds every caller.
- Handles carry a prefix (`<runtime>:<customer>:<id>`); unprefixed means hosted, so stored handles
  need no migration. A malformed prefixed handle fails.
- A placement lookup error refuses the job. Never default to hosted.
- Activate only after a real command runs in the customer runtime.
- Say exactly which outputs (command output, file contents) return to the hosted side.

## Host daemons (loader and supervisor)

For products that own host state (`/dev/kvm`, network bridges, kernel modules) and run
long-lived child processes that must survive upgrades.

- A privileged `Daemon` runs a small **loader** you write. The loader prepares the host and starts
  the real daemon through the host's systemd (a scope, with `--collect`), so it is not a child of
  the container and survives loader rollouts.
- Each loop tick classifies the host: **adopt** (healthy, right version), **drift** (older version,
  use the product's zero-downtime upgrade if it has one), **down** (restart).
- Hash the rendered config and startup environment into the process identity. A config-only
  release must count as drift.
- Secrets never in argv or unit files: a 0600 env file sourced and deleted before `exec`.
- Drain on SIGTERM: stop placement, wait for local work to finish, then stop. Set
  `stopGracePeriod` long enough for real work.
- Replace imperative provisioning (Ansible, setup scripts) with idempotent steps named after their
  effects, each with a fast check, so a crash at any point can resume.

## AI access from a workload

- Gate in-account AI with a deployer boolean input and `.enabled(input)` on the `AI` resource when
  customers choose between in-account models and their own keys. One image serves both.
- Without `.link(llm)` there is no binding and no gateway: keyless AI is silently off.
- Scope `ai/invoke` to the AI resource.
- For images you build yourself, use the gateway launcher as the entrypoint and map its URL into
  the product's own upstream setting in a small shim.
- Prove traffic goes through the deployment: unset the provider key in the client's environment
  and watch the deployment's request counter move.

## Endpoints and TLS

- Model endpoints by name with `publicEndpoint(name, port, options)`. Wildcard surfaces use
  `wildcardSubdomains: true`. The product derives its domains from Alien's endpoint metadata at
  startup, not from a hardcoded domain variable.
- Behind a cloud load balancer that terminates TLS, add a plaintext listener that is off by
  default and blocks internal routes. On Machines, the product receives certificate files.
- Health routes stay unauthenticated and return no deployment data.
