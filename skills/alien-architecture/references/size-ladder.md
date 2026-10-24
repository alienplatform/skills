# The size ladder

Each rung below is a candidate data plane. Use the smallest rung that meets the requirement.
For every rung: when it fits, what Alien provides, what crosses the boundary, failure behavior,
operational cost, the plain alternative, and signals that you picked the wrong rung.

Diagrams in the decision record follow one convention: control plane on the LEFT, data plane on
the RIGHT, and arrows pointing from the side that opens the connection.

```text
┌─ CONTROL PLANE (your cloud) ─┐           ┌─ DATA PLANE (customer) ─┐
│ sign-in · billing · UI       │ ◀── https │ your code · their data  │
│ releases · monitoring        │  outbound │                         │
└──────────────────────────────┘           └─────────────────────────┘
```

## 1. A key

- **Fits**: "we must be able to revoke your access to our data". Product stays SaaS.
- **Alien provides**: the Encryption Gateway (`https://encryption.alien.dev/v1/encrypt` and
  `/decrypt`, header `X-Alien-External-ID`) for field-level encryption, or an AWS Virtual Key: an
  ordinary KMS key in the vendor's account backed by the customer's key, usable by Aurora, S3,
  and EBS. Inside a data plane: `new alien.Key()` passed to `Storage().encryptionKey()`,
  `Postgres().encryptionKey()`, or container `persistentStorage(size, { encryptionKey })`. The key
  choice is fixed when the resource is created.
- **Crosses**: with the gateway, plaintext passes through it. The root key is cached up to 5
  minutes, so revocation takes effect within minutes. Say both in the record.
- **Failure**: revoked or unavailable key returns `KEY_UNAVAILABLE` (503). Resources are kept and
  recover when the key is restored.
- **Cost**: per-call latency for gateway calls; key setup per customer.
- **Plain alternative**: per-tenant keys in your own KMS. The customer cannot revoke them, which is
  the point of the requirement.
- **Wrong rung if**: the buyer says data must not leave their account. A key does not move data.
- Docs: `use-cases/customer-managed-keys`, `deploy/customer-managed-keys`,
  `integrate/customer-keys-settings`.

## 2. A model account

- **Fits**: "prompts must go through our AI agreement", committed cloud spend, zero data retention.
- **Alien provides**: the hosted AI Gateway (`https://ai.alien.dev/v1`, OpenAI and Anthropic SDK
  compatible, header `X-Alien-External-ID`) routes to the provider the customer connected with
  short-lived credentials. Inside a data plane: `new alien.AI("llm")` linked to a workload calls
  Amazon Bedrock, Vertex AI, or Azure AI Foundry with the workload's own identity. Open-weight
  models: managed on those providers, or served by the vendor in a GPU `Container` (for example
  vLLM).
- **Crosses**: with the hosted gateway, prompts pass through Alien to the customer's provider.
  With the `AI` resource, prompts never leave the customer's cloud.
- **Failure**: provider refusals (model access not enabled, quota) surface as errors. Do not fall
  back to the vendor's own model account for that customer unless the customer agreed to it.
- **Plain alternative**: ask for the customer's API key. Then the vendor stores a customer secret.
- **Wrong rung if**: the rest of the request (retrieved documents, tool results) is also content
  that must stay put.
- Docs: `use-cases/local-models`, `deploy/local-models`, `integrate/ai-models-settings`.

## 3. A cache the customer reads locally

- **Fits**: a check on every request of the customer's app (entitlements, feature flags, policy),
  latency or offline tolerance matters, authoritative writes can stay hosted.
- **Alien provides**: one `Kv` added with `remoteAccess: true`, usually frozen. The control plane
  writes through remote bindings (`Bindings.forRemoteCustomer`) with short-lived credentials
  scoped to that one resource. The customer's app reads it with its own identity.
- **Crosses**: control plane writes versioned snapshots through cloud APIs. No network path into
  the customer's VPC, no open port, no proxy.
- **Failure**: reads keep working when the vendor is down, within a stale window you define. Locks,
  reservations, and atomic enforcement stay at the authority.
- **Cost**: one resource per customer; snapshot publishing and repair in the control plane.
- **Plain alternative**: the customer runs their own Redis. When it breaks, they blame the vendor.
- **Wrong rung if**: the cached values are content the buyer wants out of the vendor's cloud
  entirely. Then the writer is in the wrong place.

## 4. Remote Operator beside an existing install

- **Fits**: the vendor already ships a Helm chart, Terraform module, or ECS task, and the problem is
  operating it (debugging, restarts, upgrades) without inbound access.
- **Alien provides**: one Operator container, outbound HTTPS only, running named operations
  (Read-only, Mutating, Destructive tiers) under time-boxed access requests (default and maximum
  6 hours), debug sessions, and a full audit log. Versionless releases
  (`alien release --no-stack --version <v>`) record the version each environment runs.
- **Crosses**: operation requests and results. Specify which outputs (logs, events, metrics) leave
  the environment and filter them.
- **Failure**: if the Operator loses its connection, the product keeps running; operations wait.
- **Cost**: one container and one ServiceAccount or cloud identity per install.
- **Plain alternative**: screen-share debugging or a VPN and bastion. Security teams refuse the
  second.
- **Wrong rung if**: the real problem is upgrades drifting across installs. Then Alien-managed
  deployments may be the next step; adopting them is a separate choice.
- Docs: `use-cases/remote-operator`, `operate/remote-operator/add-to-existing-install`.

## 5. A service

- **Fits**: an API over customer content (email, documents, records) where only content must stay
  in the customer's account.
- **Alien provides**: `Worker` or `Container` for the content routes, with `Storage`, `Kv`,
  `Postgres`, `Queue` as needed, linked with named permission profiles.
- **Crosses**: the control plane keeps identity, policy, billing, and metadata. Content routes are
  served by the data plane. Events to the control plane are thin (IDs and counts). Clients keep
  one base URL; the SDK or a router sends content calls to the data plane.
- **Failure**: content routes fail closed when the data plane is down. Metadata pages stay usable.
- **Cost**: one service and its storage per customer; a route classification to maintain
  (`local`, `intercept`, `proxy`, `denied`, default `denied`).
- **Plain alternative**: rebuild the product as a new control plane plus shared data plane. Usually
  far more migration than the requirement needs.
- **Wrong rung if**: "add search" turned into "move the database". Move content and what is derived
  from it, not everything near it.

## 6. A full data plane

- **Fits**: "all processing of our data happens in our cloud", or the buyer requires the whole
  data-handling half (often a migration from a Helm chart).
- **Alien provides**: the stack in `alien.ts`: containers or workers, `Postgres`, `Storage`, queues,
  setup containers, `Vault`, compute pools. Push or pull per customer.
- **Crosses**: usage counts, health, status to the control plane. Browser content goes direct to
  the data plane.
- **Failure**: data plane keeps running when Alien or the control plane is unreachable; releases
  and commands wait.
- **Cost**: the largest per-customer footprint; quotas and instance types per cloud; more frozen
  resources and setup reruns when they change.
- **Plain alternative**: ship the Helm chart and let the customer operate it. Versions drift and
  debugging needs their engineers.
- **Wrong rung if**: sign-in, billing, or analytics ended up inside it. Those stay in the control
  plane.

## 7. Host capacity

- **Fits**: the product needs the host: sandboxes with nested virtualization, local disks, kernel
  features, or servers the customer already owns.
- **Alien provides**: `Daemon` and `Container` on `ComputeCluster` pools in a cloud account, or on
  Machines (Linux hosts that join a deployment with a join command, update automatically, and keep
  running offline). Machines have no GPU support today.
- **Crosses**: scheduling and status from the control plane; results back as metadata.
- **Failure**: hosts keep running on the last plan they received, across reboots.
- **Cost**: host lifecycle, drain, and upgrade semantics are now the vendor's problem.
- **Wrong rung if**: a container on managed compute would do. Check before choosing hosts.
- Docs: `use-cases/on-prem`, `deploy/machines`, `deploy/kubernetes`, `build/compute`.

## Stateless execution in the customer's account

A variant between rungs 3 and 5: the vendor's hosted service runs sandboxes or jobs in the
customer's account and drives them through remote bindings, while everything stored stays hosted.
Route per tenant with an explicit placement record; never fall back to hosted execution on error.
Say exactly which outputs (command output, file contents) return to the hosted side. Docs:
`integrate/remote-sandboxes`.
