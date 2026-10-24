---
name: alien-architecture
description: Decide which part of a product should run outside your own cloud, and write the decision down before any code changes. Use when a customer or prospect asks for BYOC (bring your own cloud), single-tenant or dedicated deployments, customer-managed keys (BYOK), their own AI models or model account, on-prem, Kubernetes or bare-metal installs, or remote operations access to an install you already ship; when asked to design a control plane / data plane split or "what should run in the customer's cloud"; or when evaluating Alien for a repository. Produces docs/alien-architecture.md with 2-3 candidate splits, a recommendation, and rejected options, then stops for approval. Hand implementation to the alien-integration skill.
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien architecture

Alien is infrastructure for software outside your cloud. It builds, deploys, updates, and operates
the **data plane**: the smallest piece of a product that has to run next to a customer's data, a
private system, or special hardware. Everything else stays in the vendor's **control plane**, in
the vendor's cloud, as ordinary SaaS. Alien does not host the control plane.

This skill decides what that smallest piece is for one repository and one customer requirement.
It ends with a written decision record and the user's approval. Do not write `alien.ts`, change
application code, or create cloud resources while using it. Implementation is the
`alien-integration` skill.

## Terms

Use these meanings in everything you write. Define them for the user the first time.

- **Control plane**: the shared part in the vendor's cloud. Sign-in, billing, UI, analytics,
  releases, monitoring. Stores only metadata.
- **Data plane**: the part in each remote environment (customer cloud account, a dedicated account
  in the vendor's cloud, Kubernetes, Linux servers). Holds customer data and the code that touches
  it. Connects out to the control plane; nothing connects in.
- **Metadata vs customer data**: metadata is who the customers are, plans, settings, versions,
  health. Customer data is what the product exists to store and process. The buyer's security
  review decides where the line is, not the vendor.
- **Setup vs runtime**: the customer's admin runs setup once with their own credentials. It creates
  the **frozen** resources and a scoped management identity. After that, Alien updates the **live**
  resources on every release without the admin.
- **Push vs pull**: push applies releases through cloud APIs with the management identity (default
  on AWS, Google Cloud, Azure). Pull runs an Operator inside the environment that polls outbound
  over HTTPS (required on Kubernetes and Linux hosts, available everywhere, no cross-account role).
- **Remote Operator**: one container, outbound HTTPS only, that runs named, audited operations under
  time-boxed access. Built into every Alien deployment; can also be added alone to an existing
  Helm chart, Terraform module, or ECS task.

## Read the docs first

Fetch these as Markdown before proposing anything. They are the source of truth; this skill keeps
only decision rules.

- https://alien.dev/docs/design/control-plane-data-plane.md
- https://alien.dev/docs/design/smallest-piece.md
- https://alien.dev/docs/design/connect-the-planes.md
- https://alien.dev/docs/how-alien-works.md
- Index of every page: https://alien.dev/llms.txt

Read the use-case page that matches the requirement:
`use-cases/single-tenant`, `use-cases/byoc`, `use-cases/customer-managed-keys`,
`use-cases/local-models`, `use-cases/on-prem`, `use-cases/remote-operator`
(each at `https://alien.dev/docs/<path>.md`).

## Workflow

Work through the steps in order. Do not skip to a design.

### 1. Write down the requirement in the customer's words

Ask the user if it is not in the conversation. Quote it. Then name which question it answers.
These are independent; one does not imply another:

| Question | Typical words | Smallest answer |
|---|---|---|
| Where does the software run? | "our data can't leave our account", "on our servers" | single-tenant, BYOC, on-prem |
| Who holds the key? | "we need to revoke access", "BYOK" | customer-managed keys |
| Whose model account sees prompts? | "under our AI agreement", "no third-party LLM" | local models |
| How do you operate it? | "no inbound access", "you can't have a VPN" | Remote Operator |
| How fast or offline? | "checks must not add latency", "keep working if you're down" | a cache in their account |

Also record: which clouds or platforms, who the buyer's security reviewer is, and anything they
already ruled out. If the requirement is vague ("enterprise wants BYOC"), list the questions to
ask the buyer and propose candidates for the two most likely answers.

### 2. Inventory the components

Read the code, not only the README. Fill the worksheet in `references/inventory.md`: every
service, database, queue, job, and external dependency, with file paths, the data each touches,
the private systems it reaches, special hardware, latency budget, and how it is deployed today.
If the product already ships an installer (Helm chart, Terraform, Docker Compose), record it.

### 3. Mark what has to move

For each component ask: does it need to be next to the customer's data, a private system, or
special hardware? If not, it stays in the control plane. Derived data (indexes, caches,
embeddings over customer data) is customer data. Mark each component `stays`, `moves`, or
`depends on the buyer` with a one-line reason.

### 4. Propose 2-3 candidate splits

Pick from the size ladder, smallest first. Always include the smallest candidate that could meet
the requirement, and one larger alternative. Details and anti-signals per rung are in
`references/size-ladder.md`.

| Rung | What runs in the customer's environment | Needs an Alien deployment there |
|---|---|---|
| A key | Nothing of yours; their KMS key | No |
| A model account | Nothing of yours; their Bedrock, Vertex AI, or Azure AI Foundry | No |
| A cache | One key-value store your control plane writes to | Yes, one resource |
| Remote Operator beside an existing install | One container next to your Helm chart or ECS task | Operator only |
| A service | Routes that read and write content, plus their storage | Yes |
| A full data plane | The data-handling half: database, storage, workers | Yes |
| Host capacity | Daemons or sandboxes on the customer's servers | Yes, on machines |

Single-tenant is the same data plane placed in a dedicated account in the vendor's cloud. It is a
placement, not a separate design, and the same `alien.ts` can move to BYOC later.

For each candidate, write all of these. A candidate missing one is not finished:

1. **What runs where**: a diagram with the control plane on the LEFT and the data plane on the
   RIGHT, arrows showing who opens each connection.
2. **What crosses the boundary, per call**: every call between the planes, its direction, its
   mechanism (outbound HTTPS, command, remote binding, browser direct), and the exact fields it
   carries. Content should not cross.
3. **Alien resources**: the resources the data plane declares (`Worker`, `Container`, `Daemon`,
   `Storage`, `Kv`, `Queue`, `Postgres`, `Vault`, `Key`, `AI`, ...) or the hosted service used
   (Encryption Gateway, AI Gateway).
4. **Setup and permissions**: which resources are frozen (customer creates at setup, fewer
   management permissions) and which are live (Alien updates every release), push or pull, and
   which changes would need the customer's admin to rerun setup.
5. **Failure behavior**: what happens when the data plane, the control plane, or Alien is
   unreachable. Must fail closed: no fallback to processing that customer's data in the vendor's
   cloud.
6. **Operational cost**: what now runs in every customer environment, what the vendor must
   support, upgrade, and debug there, and cloud cost the customer pays.
7. **Why not without Alien?**: the plain alternative (ship a Helm chart, ask the customer to
   bring their own Redis, a per-customer Terraform run, a VPN) and why it is worse or better here.
   If the plain alternative wins, say so.

### 5. Run the boundary checks

Apply every check in `references/boundary-checks.md` to every candidate. The four that catch most
mistakes:

- Does customer content transit the control plane, or a hosted Alien gateway? If a gateway, the
  record must say plaintext passes through it.
- Is something declared in the data plane that belongs in the control plane (sign-in, billing,
  tenancy, UI, analytics, release logic)?
- Is "metadata" defined by the buyer's security review, or assumed by the vendor? File names,
  email addresses, and counterparty IDs are often content.
- Is there a fallback path that quietly processes the customer's data in the vendor's cloud?

Fix the candidate or reject it, and record why.

### 6. Recommend one

Prefer the smallest candidate that meets the requirement as the customer stated it. Designs
usually shrink during this step. Say what would make you choose a larger rung later.

### 7. Write the decision record

Write `docs/alien-architecture.md` in the user's repository from
`references/decision-record-template.md`. Include the rejected candidates and the reason for each.
Next customer, someone will ask again.

### 8. Stop for approval

Summarize the recommendation in five lines, list open questions for the buyer, and ask the user to
approve, change, or reject it. Do not start implementation in the same turn. After approval, use
the `alien-integration` skill, which reads the decision record.

## Standalone paths

Some requirements need no data plane at all, or only one piece. Propose these directly when they
fit; each one works on its own.

| Path | When | How |
|---|---|---|
| Customer-managed keys only | Product stays SaaS; buyer wants a revocable key | Hosted Encryption Gateway for fields, or an AWS Virtual Key for whole databases and buckets. In a data plane, a `Key` passed to `Storage`, `Postgres`, or container volumes. |
| Local models only | Product stays SaaS; prompts must use the customer's model account | Hosted AI Gateway (OpenAI and Anthropic SDK compatible). In a data plane, an `AI` resource linked to the workload; no API keys. |
| Remote Operator only | Vendor already ships Helm, Terraform, or ECS and needs to operate it | Add the Operator container to the existing install. Versionless releases record which version each environment runs. |
| Single-tenant | Isolation and region choice, customer installs nothing | Data plane in a dedicated account in the vendor's cloud. Can use a customer key on AWS. |

Even the gateway paths need the customer to connect their key or model account through a setup
link. Docs: `use-cases/customer-managed-keys`, `use-cases/local-models`,
`use-cases/remote-operator`, `use-cases/single-tenant`.

## Rules

1. Start from the smallest piece. Every component in the data plane runs in every customer
   environment and costs the vendor support work there.
2. Do not describe the outcome as "running the product in the customer's cloud" unless the
   chosen rung is a full data plane. Say which piece runs there.
3. Customer content never passes through the control plane. Browsers fetch content from the data
   plane directly with a short-lived token from the control plane; uploads go straight to the
   data plane's storage with a signed URL.
4. Fail closed across a trust boundary. A latency cache with a documented fallback is a different
   policy and must be stated as such.
5. Security teams usually refuse cross-account access, not outbound HTTPS. If the customer will
   not grant a cross-account role, use pull.
6. Frozen or live is chosen per resource, not per resource type. Lead with the permission
   trade-off, not with "data persists".
7. Customer-provided secrets go into the customer's own secret store. Alien never reads them. Do
   not design a flow where the vendor collects a customer secret.
8. Only propose capabilities the docs describe. If the design needs something the docs do not
   cover, list it under open questions instead of assuming it exists.
9. Write in plain language. No customer or prospect names in the record unless the user asks; use
   "Customer 1".

## Output

- `docs/alien-architecture.md` in the user's repository.
- A short message: requirement, recommended rung, what crosses the boundary, open questions,
  and the approval request.
