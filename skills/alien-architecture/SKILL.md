---
name: alien-architecture
description: Decide which part of a product should run outside your own cloud, and write the decision down before any code changes. Use when a customer or prospect asks for BYOC (bring your own cloud), single-tenant or dedicated deployments, customer-managed keys (BYOK), their own AI models or model account, access to systems only reachable inside their network (a cluster, a private database, devices), low latency next to their app, on-prem, Kubernetes or bare-metal installs, or updates and remote operations for an install you already ship; when asked "what should run in the customer's cloud" or to design a control plane / data plane split; or when evaluating Alien for a repository. Asks a few multiple-choice questions, classifies which data is sensitive, then produces docs/alien-architecture.md with 2-3 candidates, a recommendation, and rejected options, and stops for approval. Hand implementation to the alien-integration skill.
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien architecture

Alien provides infrastructure for deploying and operating software in remote environments at
scale: customer cloud accounts, dedicated accounts in the vendor's cloud, Kubernetes clusters, Linux
servers, and devices. Software runs there to be close to:

- **Sensitive data**: keep it in the customer's environment, or isolated (single-tenant,
  customer-managed keys, the customer's model account).
- **Private networks**: reach a database in their VPC or the API of their cluster.
- **Local resources**: read files and processes on specific machines.
- **Latency-critical workloads**: answer next to the app that calls you.

What gets deployed can be nothing at all (only the customer's key or model account), a small
agent, the part of the product that touches the data, or the whole product. The vendor's backend
stays in the vendor's cloud.

This skill finds the smallest piece that meets the requirement, asks the user a few questions to
get there, and ends with a written decision record and the user's approval. Do not write
`alien.ts`, change application code, or create cloud resources while using it. Building is the
`alien-integration` skill.

## Terms

Use these meanings in everything you write. Define them for the user the first time.

- **Deployment**: what runs in one remote environment (a customer cloud account, a dedicated
  account in the vendor's cloud, a Kubernetes cluster, Linux servers). It connects out to the
  vendor's backend and to Alien; nothing connects in unless an endpoint is declared.
- **Your backend**: the vendor's hosted product. Calls deployments with commands or remote
  bindings.
- **Control plane / data plane**: one common split, used when the requirement is about sensitive
  data. The control plane is the shared hosted part (sign-in, billing, UI, analytics, monitoring)
  and stores only metadata. The data plane is the deployment that holds customer data and the code
  that touches it. Use these words only when the candidate is that split.
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

- https://alien.dev/docs/use-cases.md
- https://alien.dev/docs/design/what-to-run-remotely.md
- https://alien.dev/docs/design/reach-a-deployment.md
- https://alien.dev/docs/how-alien-works.md
- https://alien.dev/docs/design/control-plane-data-plane.md, when a candidate is the split
- Index of every page: https://alien.dev/llms.txt

Read the use-case page that matches the requirement:
`use-cases/single-tenant`, `use-cases/byoc`, `use-cases/customer-managed-keys`,
`use-cases/local-models`, `use-cases/on-prem`, `use-cases/remote-operator`
(each at `https://alien.dev/docs/<path>.md`). For private systems, read the matching example:
`examples/private-database`, `examples/remote-tools`, `examples/endpoint-agent`.

## Workflow

Work through the steps in order. Do not skip to a design.

### 1. Read before asking

Read the conversation and the repository: README, deploy files (Dockerfiles, Helm, Terraform,
compose), data models, and anything that talks to customer systems. Quote the customer's
requirement if one was given.

### 2. Ask the questions

Ask the batch in `references/questions.md`: three or four multiple-choice questions in one turn,
each with **Other**, with likely answers pre-selected from what you read. Don't ask what the code
or conversation already answers, and don't ask follow-ups one at a time. Restate the answers in two
lines before going on.

### 3. Inventory the components

Read the code, not only the README. Fill the worksheet in `references/inventory.md`: every
service, database, queue, job, and external dependency, with file paths, the data each touches,
the private systems it reaches, special hardware, latency budget, and how it's deployed today. If
the product already ships an installer (Helm chart, Terraform, Docker Compose), record it.

### 4. Classify the data

When the user cares about sensitive data, run `references/classify-data.md`. Find every field and
every path that carries data, sort them into classes, and settle the judgment calls with the user,
a few at a time, multiple choice. This decides how big the data plane is. Skip this step when
sensitive data isn't one of the answers.

### 5. Propose 2–3 candidates

Apply `references/decision-rules.md` to the answers and the worksheet. Always include the smallest
candidate that could meet the requirement, and one larger alternative. Details and wrong-option
signals are in `references/what-to-run-remotely.md`.

For each candidate, write all of these. A candidate missing one is not finished:

1. **What runs where**: a diagram with the vendor's cloud on the LEFT and the remote environment
   on the RIGHT, arrows showing who opens each connection.
2. **What crosses the boundary, per call**: every call between the vendor's cloud and the
   deployment, its direction, its mechanism (outbound HTTPS, command, remote binding, browser
   direct), and the exact fields it carries. Content should not cross.
3. **Alien resources**: what the deployment declares (`Worker`, `Container`, `Daemon`, `Storage`,
   `Kv`, `Queue`, `Postgres`, `Vault`, `Key`, `AI`, ...) or the hosted service used.
4. **Setup and permissions**: which resources are frozen and which are live, push or pull, and
   which changes would need the customer's admin to rerun setup.
5. **Failure behavior**: what happens when the deployment, the vendor's backend, or Alien is
   unreachable. Fail closed: no fallback to processing the customer's data in the vendor's cloud.
6. **Operational cost**: what now runs in every customer environment, what the vendor supports
   there, and the cloud cost the customer pays.
7. **Why not without Alien?**: the plain alternative (ship a Helm chart, a per-customer Terraform
   run, a VPN) and why it's worse or better here. If the plain alternative wins, say so.

### 6. Run the boundary checks

Apply every check in `references/boundary-checks.md` to every candidate. The four that catch most
mistakes:

- Does customer content transit the vendor's cloud, or a hosted Alien gateway? If a gateway, the
  record must say plaintext passes through it.
- Is something declared in the deployment that belongs in the vendor's cloud (sign-in, billing,
  tenancy, UI, analytics, release logic)?
- Is "metadata" defined by the buyer's security review, or assumed by the vendor? File names,
  email addresses, and counterparty IDs are often content.
- Is there a fallback path that quietly processes the customer's data in the vendor's cloud?

Fix the candidate or reject it, and record why.

### 7. Recommend one

Prefer the smallest candidate that meets the requirement as the customer stated it. Designs
usually shrink during this step. Say what would make you choose a larger option later.

### 8. Write the decision record

Write `docs/alien-architecture.md` in the user's repository from
`references/decision-record-template.md`. Include the answers to the questions, the data worksheet, and the rejected candidates with the
reason for each.

### 9. Stop for approval

Summarize the recommendation in five lines, list open questions for the buyer, and ask the user to
approve, change, or reject it. Do not start implementation in the same turn. After approval, use
the `alien-integration` skill, which reads the decision record.

## Standalone paths

Some requirements need no deployment of your code at all, or only one piece. Propose these directly when they
fit; each one works on its own.

| Path | When | How |
|---|---|---|
| Customer-managed keys only | Product stays SaaS; buyer wants a revocable key | Hosted Encryption Gateway for fields, or an AWS Virtual Key for whole databases and buckets. In a deployment, a `Key` passed to `Storage`, `Postgres`, or container volumes. |
| Local models only | Product stays SaaS; prompts must use the customer's model account | Hosted AI Gateway (OpenAI and Anthropic SDK compatible). In a deployment, an `AI` resource linked to the workload; no API keys. |
| Customer buckets only | Product stays SaaS; files must be at rest in the customer's account | A `Storage` the vendor's backend reaches with remote bindings. No compute in their cloud. |
| Remote Operator only | Vendor already ships Helm, Terraform, or ECS and needs to operate it | Add the Operator container to the existing install. Versionless releases record which version each environment runs. |
| Single-tenant | Isolation and region choice, customer installs nothing | A deployment in a dedicated account in the vendor's cloud. Can use a customer key on AWS. |

Even the gateway paths need the customer to connect their key or model account through a setup
link. Docs: `use-cases/customer-managed-keys`, `use-cases/local-models`,
`integrate/customer-storage`, `use-cases/remote-operator`, `use-cases/single-tenant`.

## Rules

1. Start from the requirement and the smallest piece that meets it. Every component you deploy
   runs in every customer environment and costs the vendor support work there.
2. Do not describe the outcome as "running the product in the customer's cloud" unless the
   chosen option is the whole product. Say which piece runs there.
3. Do not default to the control plane / data plane split. Use it when the requirement is about
   where customer content is stored and processed. An agent answers private-systems requirements;
   a cache answers latency.
4. Customer content never passes through the vendor's cloud unless the record says so (a hosted
   gateway, a customer bucket the vendor's backend reads). Browsers fetch content from the
   deployment directly with a short-lived token from the vendor's backend; uploads go straight to
   the deployment's storage with a signed URL.
5. Fail closed across a trust boundary. A latency cache with a documented fallback is a different
   policy and must be stated as such.
6. Security teams usually refuse cross-account access, not outbound HTTPS. If the customer will
   not grant a cross-account role, use pull.
7. Frozen or live is chosen per resource, not per resource type. Lead with the permission
   trade-off, not with "data persists".
8. Customer-provided secrets go into the customer's own secret store. Alien never reads them. Do
   not design a flow where the vendor collects a customer secret.
9. Only propose capabilities the docs describe. If the design needs something the docs do not
   cover, list it under open questions instead of assuming it exists.
10. Write in plain language. No customer or prospect names in the record unless the user asks;
    use "Customer 1".

## Output

- `docs/alien-architecture.md` in the user's repository.
- A short message: requirement, reason, recommended option, what crosses the boundary, open
  questions, and the approval request.
