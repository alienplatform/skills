---
name: alien-architecture
description: Decides which part of a product should run outside the vendor's own cloud, and writes the decision down before any code changes. Use when a customer or prospect asks for BYOC (bring your own cloud), single-tenant or dedicated deployments, customer-managed keys (BYOK), their own AI models or model account, access to systems reachable only inside their network (a cluster, a private database, devices), low latency next to their app, on-prem, air-gapped, Kubernetes or bare-metal installs, or updates and remote operations for software already shipped as a Helm chart or Terraform module; when asked "what should run in the customer's cloud" or to design a control plane / data plane split; or when evaluating Alien for a repository. Asks a few multiple-choice questions, classifies sensitive data, writes docs/alien-architecture.md with two or three candidates, a recommendation, and rejected options, then stops for approval. Implementation belongs to the alien-integration skill.
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien architecture

Alien deploys and operates software in remote environments: customer cloud accounts, dedicated
accounts in your cloud, Kubernetes clusters, Linux servers, and devices. Software runs there to be
close to one of these:

- **Sensitive data**: kept in the customer's environment, or isolated (single-tenant,
  customer-managed keys, the customer's model account).
- **Private networks**: a database in their VPC, the API of their cluster.
- **Local resources**: files and processes on specific machines.
- **Latency-critical workloads**: answers next to the app that calls you.

The piece you deploy can be nothing (only the customer's key or model account), a small agent, the
part of the product that touches the data, or the whole product. Your backend stays in your cloud.

This skill finds the smallest piece that meets the requirement and ends with a written decision
record the user approves. While using it, do not write `alien.ts`, change application code, or
create cloud resources. Building is the `alien-integration` skill.

## Terms

Use these meanings in everything you write, and define each for the user the first time.

- **Deployment**: what runs in one remote environment. It connects out to your backend and to
  Alien. Nothing connects in unless the stack declares an endpoint.
- **Your backend**: your hosted product, in your cloud. It calls deployments with commands or
  remote bindings.
- **Control plane / data plane**: one common split, for requirements about sensitive data. The
  control plane is the shared hosted part (sign-in, billing, UI, analytics, monitoring) and stores
  only metadata. The data plane is the deployment that holds customer data and the code that
  touches it. Use these words only when the candidate is that split.
- **Metadata and customer data**: metadata is who the customers are, plans, settings, versions,
  and health. Customer data is everything the product exists to store and process, plus what is
  derived from it. **Content** is the core of customer data: messages, documents, files, records.
  The buyer's security review draws the line, not you.
- **Initial setup**: the one-time step the customer's admin runs with their own credentials. It
  creates the **frozen** resources and the **management identity**, the scoped identity Alien uses
  afterwards. Alien then updates the **live** resources on every release without the admin.
- **Push and pull**: push applies releases through cloud APIs with the management identity (the
  default on AWS, Google Cloud, and Azure). Pull runs a component inside the environment that
  connects out over HTTPS: the Operator on Kubernetes, the machine agent on Linux hosts. In a cloud
  account, pull means running on a Kubernetes cluster (EKS, GKE, AKS). Pull needs no cross-account
  role.
- **Remote Operator**: one container, outbound HTTPS only, that runs named, audited operations
  under time-boxed access. Alien pull deployments include it. It can also be added on its own to
  an existing Helm chart, Terraform module, or ECS task.

## Docs

Fetch these as Markdown before proposing anything. They are the source of truth; this skill keeps
only the decision rules.

- https://alien.dev/docs/guide/design.md
- https://alien.dev/docs/guide/how-alien-works.md
- https://alien.dev/docs/guide/design/connect-your-backend.md
- https://alien.dev/docs/guide/design/control-plane-data-plane.md, when a candidate is the split
- https://alien.dev/docs/guide/design/whole-product.md, when a candidate is the whole product
- Index of every page: https://alien.dev/llms.txt

Then read the page for the requirement, each at `https://alien.dev/docs/<path>.md`:
`infrastructure/platforms/single-tenant`, `guide/customer-managed-keys`, `guide/local-ai-models`,
`guide/design/agent-or-connector`, `infrastructure/platforms/machines`,
`infrastructure/platforms/deployment-models`, `production/remote-operator`. For private systems,
read the matching example: `examples/private-database`, `examples/remote-tools`,
`examples/endpoint-agent`.

## Workflow

Work through the steps in order. Do not skip to a design. Copy this checklist and tick it off:

```text
- [ ] 1. Read the conversation and the repository
- [ ] 2. Ask the questions, restate the answers
- [ ] 3. Fill the component inventory
- [ ] 4. Classify the data (sensitive data only)
- [ ] 5. Propose two or three candidates, all eight fields each
- [ ] 6. Run the boundary checks; fix or reject, then re-run
- [ ] 7. Recommend one
- [ ] 8. Write docs/alien-architecture.md
- [ ] 9. Stop for approval
```

### 1. Read

Read the conversation and the repository: README, deploy files (Dockerfiles, Helm, Terraform,
Compose), data models, and anything that talks to customer systems. Quote the customer's
requirement if one was given.

### 2. Ask

Ask the batch in [references/questions.md](references/questions.md): three to five multiple-choice
questions in one turn, each with **Other**, likely answers pre-selected. Don't ask what the code or
conversation already answers, and don't ask follow-ups one at a time. Restate the answers in two
lines before going on.

### 3. Inventory

Read the code, not only the README. Fill the worksheet in
[references/inventory.md](references/inventory.md): every service, database, queue, job, and
external dependency, with file paths, the data each touches, the private systems it reaches,
special hardware, latency budget, and how it is deployed before Alien. Record any installer the product
already ships (Helm chart, Terraform, Docker Compose).

### 4. Classify the data

Only when sensitive data is one of the answers. Run
[references/classify-data.md](references/classify-data.md): find every field and every path that
carries data, sort them into classes, and settle the judgment calls with the user, a few at a time,
multiple choice. This decides how big the data plane is.

### 5. Propose candidates

Apply [references/decision-rules.md](references/decision-rules.md) to the answers and the
worksheet. Always include the smallest candidate that could meet the requirement, and one larger
alternative. Each option's details and wrong-option signals are in
[references/what-to-run-remotely.md](references/what-to-run-remotely.md).

A candidate is finished only when it has all of these:

1. **What runs where**: a diagram with your cloud on the LEFT and the remote environment on the
   RIGHT, arrows showing who opens each connection.
2. **What crosses the boundary, per call**: every call between your cloud and the deployment, its
   direction, its mechanism (outbound HTTPS, command, remote binding, browser direct), and the
   exact fields it carries. Content should not cross.
3. **Alien resources**: what the deployment declares (`Worker`, `Container`, `Daemon`, `Storage`,
   `Kv`, `Queue`, `Postgres`, `Vault`, `Key`, `AI`, ...) or the hosted service it uses.
4. **Initial setup and permissions**: which resources are frozen and which are live, push or pull,
   and which changes would need the customer's admin to rerun initial setup.
5. **Failure behavior**: what happens when the deployment, your backend, or Alien is unreachable.
   Fail closed: no fallback to processing customer data in your cloud.
6. **Operational cost**: what now runs in every customer environment, what you support there, and
   the cloud cost the customer pays.
7. **Cost to build**: what changes in the product. A smaller data plane can mean rewriting most of
   the backend; say how much.
8. **Why not without Alien?**: the plain alternative (ship a Helm chart, a per-customer Terraform
   run, a VPN) and why it's worse or better here. If the plain alternative wins, say so.

### 6. Boundary checks

Apply every check in [references/boundary-checks.md](references/boundary-checks.md) to every
candidate. Fix the candidate or reject it, record why, and run the checks again on the fixed
version. These catch most mistakes:

- Customer content transits your cloud or a hosted Alien gateway. For a gateway, the record must
  say plaintext passes through it.
- The deployment declares something that belongs in your cloud (sign-in, billing, tenancy, UI,
  analytics, release logic).
- You assumed what counts as metadata instead of the buyer's security review. File names, email
  addresses, and counterparty IDs are often content.
- A fallback path quietly processes customer data in your cloud.

### 7. Recommend

Prefer the smallest candidate that meets the requirement as the customer stated it. Designs usually
shrink during this step. Say what would make you choose a larger option later.

### 8. Decision record

Write `docs/alien-architecture.md` in the user's repository from
[references/decision-record-template.md](references/decision-record-template.md). Include the
answers to the questions, the data worksheet, and the rejected candidates with the reason for each.

### 9. Approval

Summarize the recommendation in five lines, list open questions for the buyer, and ask the user to
approve, change, or reject it. Do not start implementation in the same turn. After approval, use
the `alien-integration` skill, which reads the decision record.

## Standalone paths

Some requirements need none of your code in the customer's environment, or only one piece. Propose
these directly when they fit. Each works on its own.

| Path | When | How |
|---|---|---|
| Customer-managed keys only | Product stays hosted; buyer wants a key they can revoke | Hosted Encrypt/Decrypt API for fields, or an AWS Virtual Key for whole databases and buckets. In a deployment, a `Key` passed to `Storage`, `Postgres`, or container volumes. |
| Local models only | Product stays hosted; prompts must use the customer's model account | Hosted AI Gateway (OpenAI and Anthropic SDK compatible). In a deployment, an `AI` resource linked to the workload; no API keys. |
| Customer buckets only | Product stays hosted; files must rest in the customer's account | A `Storage` your backend reaches with remote bindings. No compute in their cloud. |
| Remote Operator only | You already ship Helm, Terraform, or ECS and need to operate it | Add the Operator container to the existing installation. Versionless releases record which version each environment runs. |
| Single-tenant | Isolation and region choice; the customer installs nothing | A deployment in a dedicated account in your cloud. Can use a customer key on AWS. |

The gateway paths still need the customer's admin to connect their key or model account through a
setup link. Docs: `guide/customer-managed-keys`, `guide/local-ai-models`,
`infrastructure/storage/customer-buckets`, `production/remote-operator`,
`infrastructure/platforms/single-tenant`.

## Rules

1. Start from the requirement and the smallest piece that meets it. Every component you deploy
   runs in every customer environment, and you support it there.
2. Do not describe the outcome as "running the product in the customer's cloud" unless the chosen
   option is the whole product. Say which piece runs there.
3. Do not default to the control plane / data plane split. Use it when the requirement is about
   where customer data is stored and processed. An agent answers private-network requirements; a
   cache answers latency.
4. Customer content never passes through your cloud unless the record says so (a hosted gateway,
   a customer bucket your backend reads). Browsers fetch content from the deployment directly with
   a short-lived token from your backend; uploads go straight to the deployment's storage with a
   signed URL.
5. Fail closed across a trust boundary. A latency cache with a documented fallback is a different
   policy; state it as one.
6. Security teams usually refuse cross-account access, not outbound HTTPS. If the customer won't
   grant a cross-account role, use pull.
7. Choose frozen or live per resource, not per resource type. Lead with the permission trade-off,
   not with "data persists".
8. Customer-provided secrets go into the customer's own secret store. Alien never reads them. Do
   not design a flow where you collect a customer secret.
9. Only propose capabilities the docs describe. If the design needs something the docs don't
   cover, list it under open questions instead of assuming it exists.
10. Write in plain language. No customer or prospect names in the record unless the user asks; use
    `customer-1`.

## References

- [references/questions.md](references/questions.md): the question batch. Load at step 2.
- [references/inventory.md](references/inventory.md): where to look, the component worksheet, and
  default placements. Load at step 3.
- [references/classify-data.md](references/classify-data.md): data classes, judgment calls, leak
  paths, and the field worksheet. Load at step 4, only for sensitive data.
- [references/decision-rules.md](references/decision-rules.md): rules from answers to candidates,
  with worked examples. Load at step 5.
- [references/what-to-run-remotely.md](references/what-to-run-remotely.md): each option, what Alien
  provides, failure behavior, and wrong-option signals. Load at step 5 for the options you propose.
- [references/boundary-checks.md](references/boundary-checks.md): every check, and claims you must
  not make. Load at step 6.
- [references/decision-record-template.md](references/decision-record-template.md): the record to
  fill. Load at step 8.

## Output

- `docs/alien-architecture.md` in the user's repository.
- A short message: requirement, reason, recommended option, what crosses the boundary, open
  questions, and the approval request.
