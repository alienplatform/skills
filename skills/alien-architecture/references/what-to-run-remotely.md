# What to run remotely

## Contents

- Options at a glance
- 1. Only your customer's own services: a key, a model account, a bucket
- 2. An agent or connector, and stateless execution in your customer's account
- 3. A local cache
- 4. The part that touches the data: a content service, a processing pipeline, the whole
  data-handling half, single-tenant
- 5. The whole product, and products that need the host
- Remote Operator beside any option

## Options at a glance

The options run from nothing of yours in your customer's environment to the whole product. Each one
is a candidate. Use the smallest one that meets the requirement. Docs:
`https://alien.dev/docs/guide/design.md`.

| Option | Requirement it meets | Main reason |
|---|---|---|
| 1. Only your customer's own services | "We need to revoke access." "Prompts stay under our AI agreement." | Sensitive data |
| 2. An agent or connector | "Our cluster and databases aren't reachable from the internet." | Private networks |
| 3. A local cache | "Checks must be fast and keep working if you're down." | Latency |
| 4. The part that touches the data | "Our content can't leave our account." | Sensitive data |
| 5. The whole product | "Everything runs in our cloud, or on our hardware." | Any of these |

Remote Operator fits next to any of these, and next to software you already ship. See the last
section.

Each option below covers when it fits, what Alien provides, what crosses, failure behavior,
operational cost, the plain alternative, and signals that you picked the wrong option.

Diagrams in the decision record: your cloud on the LEFT, the remote environment on the RIGHT, and
arrows pointing from the side that opens the connection.

```text
┌─ YOUR CLOUD ─────────────────┐           ┌─ REMOTE ENVIRONMENT ────┐
│ your backend · sign-in · UI  │ ◀── https │ what you deploy         │
│ releases · monitoring        │  outbound │ their data or systems   │
└──────────────────────────────┘           └─────────────────────────┘
```

## 1. Only your customer's own services

Nothing of yours runs in your customer's account. Initial setup creates a key, a bucket, or model
access there, and your backend uses it with short-lived credentials.

### A key

- **Fits**: "we must be able to revoke your access to our data". The product stays hosted.
- **Alien provides**: a `Key` added with `remoteAccess: true`, used from your backend through
  remote bindings. Or the hosted Encrypt/Decrypt API
  (`https://encryption.alien.dev/v1/encrypt` and `/decrypt`, header `X-Alien-External-ID`) for
  field-level encryption, or an AWS Virtual Key: an ordinary KMS key in your account backed by the
  customer's key, usable by Aurora, S3, and EBS. Inside a deployment: `new alien.Key()` passed to
  `Storage().encryptionKey()`, `Postgres().encryptionKey()`, or container
  `persistentStorage(size, { encryptionKey })`. The key choice is fixed when the resource is
  created.
- **Crosses**: with the Encrypt/Decrypt API, plaintext passes through it. The root key is cached
  for up to 5 minutes, so revocation takes effect within minutes. Say both in the record.
- **Failure**: a revoked or unavailable key returns `KEY_UNAVAILABLE` (503). Resources are kept and
  recover when the key is restored.
- **Cost**: per-call latency for Encrypt/Decrypt API calls; key setup per customer.
- **Plain alternative**: per-tenant keys in your own KMS. The customer cannot revoke them, which is
  the point of the requirement.
- **Wrong option if**: the buyer says data must not leave their account. A key does not move data.
- Docs: `guide/customer-managed-keys`, `guide/customer-managed-keys/in-a-deployment`,
  `guide/customer-managed-keys/add-to-your-product`, `examples/customer-keys`.

### A model account

- **Fits**: "prompts must go through our AI agreement", committed cloud spend, zero data retention.
- **Alien provides**: the hosted AI Gateway (`https://ai.alien.dev/v1`, OpenAI and Anthropic SDK
  compatible, header `X-Alien-External-ID`) routes to the provider the customer connected, with
  short-lived credentials. Inside a deployment: `new alien.AI("llm")` linked to a workload calls
  Amazon Bedrock, Vertex AI, or Azure AI Foundry with the workload's own identity. Open-weight
  models: managed on those providers, or served by you in a GPU `Container` (for example vLLM).
- **Crosses**: with the AI Gateway, prompts pass through Alien to your customer's provider. With the
  `AI` resource, prompts never leave your customer's cloud.
- **Failure**: provider refusals (model access not enabled, quota) surface as errors. Do not fall
  back to your own model account for that customer unless the customer agreed to it.
- **Plain alternative**: ask for your customer's API key. Then you store a customer secret.
- **Wrong option if**: the rest of the request (retrieved documents, tool results) is also content
  that must stay put.
- Docs: `guide/local-ai-models`, `guide/local-ai-models/in-a-deployment`,
  `guide/local-ai-models/add-to-your-product`, `examples/customer-models`.

### A bucket

- **Fits**: the buyer wants files at rest in their own account (residency, their own retention,
  delete everything by deleting one bucket), and processing can stay hosted.
- **Alien provides**: initial setup creates a dedicated bucket and a role scoped to it. Your
  backend gets short-lived credentials through remote bindings and calls the bucket directly. No
  compute runs in your customer's cloud, and object data does not pass through Alien.
- **Crosses**: the content itself, between the bucket and your backend. Say so: this meets "stored
  in our account", not "never leaves our account".
- **Plain alternative**: ask each customer for a long-lived access key and store it.
- **Wrong option if**: the buyer means processing must also stay in their account. Then use
  option 4.
- Docs: `infrastructure/storage/customer-buckets`, `examples/customer-storage`.

## 2. An agent or connector

- **Fits**: part of the product needs a system reachable only from inside your customer's network:
  a Kubernetes API, a database in a private subnet, an internal API, servers or devices on site.
  AI agents use it for tool calls; data connectors and security scanners use it to run queries and
  report findings.
- **Alien provides**: one small workload next to the system. `Worker` with
  `.commandsEnabled(true)` scales to zero between calls. `Container` for a long-running process (an
  agent that watches a cluster). `Daemon` for one process per host. Your backend calls it with
  commands, or the agent posts to your API on its own schedule.
- **Crosses**: instructions in, results out. Specify which results (query rows, findings, logs)
  leave the environment, and keep them small.
- **Failure**: when the agent is unreachable, the feature that needs the private system returns an
  error. Nothing else in the product is affected.
- **Cost**: one small workload per customer; the permissions it needs on the private system.
- **Plain alternative**: a VPN, an allowlisted public endpoint on your customer's database, or a
  customer-run connector you cannot update. Security teams refuse the first two; the third
  drifts.
- **Wrong option if**: the agent ends up storing customer data the product then serves. That is
  option 4.
- Docs: `guide/design/agent-or-connector`, `examples/private-database`, `examples/remote-tools`,
  `examples/endpoint-agent`, `guide/commands`.

### Variant: stateless execution in your customer's account

Your backend runs sandboxes or jobs in your customer's account and drives them through remote
bindings, while everything stored stays hosted. Route per tenant with an explicit placement record;
never fall back to hosted execution on error. Say exactly which outputs (command output, file
contents) return to the hosted side. Docs: `infrastructure/sandbox/customer-sandboxes`.

## 3. A local cache

- **Fits**: a check on every request of your customer's app (entitlements, feature flags, policy),
  where latency or offline tolerance matters and authoritative writes can stay hosted.
- **Alien provides**: one `Kv` added with `remoteAccess: true`, usually frozen, or a small service
  in front of one. Your backend writes through remote bindings (`Bindings.forRemoteCustomer`) with
  short-lived credentials scoped to that one resource. The customer's app reads it with its own
  identity and sends writes to your hosted API.
- **Crosses**: your backend writes versioned snapshots through cloud APIs. No network path into
  your customer's VPC, no open port, no proxy.
- **Failure**: reads keep working when your backend is down, within a stale window you define.
  Reads can be stale while an update is in flight. Locks, reservations, and atomic enforcement stay
  at the authority.
- **Cost**: one resource per customer; snapshot publishing and repair in your backend.
- **Plain alternative**: the customer runs their own Redis. When it breaks, they blame you.
- **Wrong option if**: the cached values are content the buyer wants out of your cloud entirely.
  Then the writer is in the wrong place.

## 4. The part that touches the data

The product stays hosted: sign-in, billing, the UI, and metadata. The code that reads and writes
customer content runs in your customer's account, with the storage it uses. This is the control
plane / data plane split, and the usual answer when the requirement is "our data stays in our
account". Docs: `guide/design/control-plane-data-plane`.

### A service that owns the content

- **Fits**: an API over customer content (email, documents, records) where only content must stay
  in your customer's account.
- **Alien provides**: `Worker` or `Container` for the content routes, with `Storage`, `Kv`,
  `Postgres`, `Queue` as needed, linked with named permission profiles.
- **Crosses**: the control plane keeps identity, policy, billing, and metadata. The data plane
  serves content routes. Events to the control plane are thin (IDs and counts). Clients keep one
  base URL; the SDK or a router sends content calls to the data plane.
- **Failure**: content routes fail closed when the data plane is down. Metadata pages stay usable.
- **Cost**: one service and its storage per customer; a route classification to maintain
  (`local`, `intercept`, `proxy`, `denied`, default `denied`).
- **Plain alternative**: rebuild the product as a new control plane plus shared data plane. Usually
  far more migration than the requirement needs.
- **Wrong option if**: "add search" turned into "move the database". Move content and what is
  derived from it, not everything near it.

### A processing pipeline

- **Fits**: customers upload files the product parses or indexes.
- **Alien provides**: `Storage` as the upload target, a `Queue`, and `Worker`s in your customer's
  account. The browser uploads straight to their storage with a signed URL.
- **Crosses**: job status and counts to the control plane. Never the file.
- **Failure**: uploads and jobs fail closed when the data plane is down.
- Docs: `examples/trace-history`, `examples/vector-database`, `examples/github-agent`.

### The whole data-handling half

- **Fits**: "all processing of our data happens in our cloud", or the buyer requires every
  component that touches content (often a migration from a Helm chart).
- **Alien provides**: the stack in `alien.ts`: containers or workers, `Postgres`, `Storage`,
  queues, setup containers, `Vault`, compute pools. Push or pull per customer.
- **Crosses**: usage counts, health, and status to the control plane. Browser content goes directly
  to the data plane.
- **Failure**: the data plane keeps running when Alien or the control plane is unreachable;
  releases and commands wait.
- **Cost**: a large per-customer footprint; quotas and instance types per cloud; more frozen
  resources, and initial setup reruns when they change.
- **Wrong option if**: sign-in, billing, or analytics ended up inside it. Those stay in the control
  plane.

### Single-tenant

Single-tenant is the same deployment placed in a dedicated account in your cloud. It is a
placement, not a separate design, and the same `alien.ts` can move to your customer's account
later. Docs: `infrastructure/platforms/single-tenant`, `guide/design/control-plane-data-plane`.

## 5. The whole product

- **Fits**: the buyer requires everything, for example on-prem or air-gapped, or you already ship
  a Helm chart and want it managed.
- **Alien provides**: the full stack: databases, containers, setup jobs. Keep sign-in, billing,
  and telemetry hosted where you can, so you still operate one product. Air-gapped sites use the
  air-gapped deployment model, where releases are carried in.
- **Crosses**: health and status. Releases arrive over the deployment's outbound connection.
- **Failure**: the deployment keeps running when your backend or Alien is unreachable; releases
  wait.
- **Cost**: the largest per-customer footprint. Every component is something you support in every
  environment.
- **Plain alternative**: ship the Helm chart and let the customer operate it. Versions drift and
  debugging needs their engineers.
- **Wrong option if**: only part of the product touches the content the requirement is about.
  Then option 4 keeps the rest hosted.
- Docs: `guide/design/whole-product`, `infrastructure/platforms/machines`,
  `infrastructure/platforms/deployment-models`, `examples/full-application`,
  `examples/customer-kubernetes`.

### When the product needs the host

Sandboxes with nested virtualization, local disks, kernel features, or servers the customer
already owns. Run a `Daemon` on every machine and schedule work onto it, either on `ComputeCluster`
pools in a cloud account or on Linux hosts that join a deployment with a join command. Joined hosts
update automatically and keep running offline, on the last plan they received, across reboots. Machines (Linux hosts the customer joins) don't support GPUs. Check first whether a
container on managed compute would do. Docs: `infrastructure/platforms/machines`,
`infrastructure/platforms/kubernetes`, `infrastructure/compute`.

## Remote Operator beside any option

- **Fits**: you already ship a Helm chart, Terraform module, or ECS task, and the problem is
  operating it (debugging, restarts, upgrades) without inbound access. Alien pull deployments
  include it too.
- **Alien provides**: one Operator container, outbound HTTPS only, running named operations
  (read-only, mutating, and destructive risk tiers) under access requests that last at most 6
  hours, debug sessions, and a full audit log. Versionless releases
  (`alien release --no-stack --version <v>`) record the version each environment runs.
- **Crosses**: operation requests and results. Specify which outputs (logs, events, metrics) leave
  the environment, and filter them.
- **Failure**: if the Operator loses its connection, the product keeps running; operations wait.
- **Cost**: one container and one ServiceAccount or cloud identity per installation.
- **Plain alternative**: screen-share debugging, or a VPN and bastion. Security teams refuse the
  second.
- **Wrong option if**: the real problem is upgrades drifting across installations. Then
  Alien-managed deployments may be the next step; adopting them is a separate choice.
- Docs: `production/remote-operator`, `production/remote-operator/add-to-existing-product`.
