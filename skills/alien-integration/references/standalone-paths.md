# Standalone paths and other targets

Use the section that matches the decision record. Each path works on its own. Fetch the linked
docs before writing code; this file keeps only the rules.

## Customer-managed keys

Docs: `use-cases/customer-managed-keys`, `integrate/customer-keys-settings`,
`deploy/customer-managed-keys`.

**Product stays SaaS.** Encrypt sensitive fields through the Encryption Gateway:
`POST https://encryption.alien.dev/v1/encrypt` and `/v1/decrypt`, with
`Authorization: Bearer <key>` and `X-Alien-External-ID: <customer id>`. For whole databases or
buckets on AWS, use an AWS Virtual Key: an ordinary KMS key in your account backed by the
customer's key.

- The customer connects their key from a setup link with the keys setup item, or from your
  settings page. The portal card is **Bring your own key**. Your team never handles the key.
- Plaintext passes through the gateway. The root key is cached up to 5 minutes, so revocation
  takes effect within minutes. Write customer-facing text that says exactly this.
- Handle `KEY_UNAVAILABLE` (HTTP 503): fail the request and show that the customer's key is
  unavailable. Do not fall back to an unencrypted path or your own key.
- Test revocation for real: disable the key, wait, confirm errors, re-enable, confirm recovery
  without data loss.

**Inside a data plane.** Declare `new alien.Key("customer-key")` and pass it to
`Storage().encryptionKey(key)`, `Postgres().encryptionKey(key)`, or
`Container().persistentStorage(size, { encryptionKey: key })`. The key choice is fixed when the
resource is created; plan it before the first customer installs. Storage supports it on every
cloud; Postgres and container volumes on AWS. Check `reference/resources/key` for the current
matrix.

## Local models

Docs: `use-cases/local-models`, `integrate/ai-models-settings`, `deploy/local-models`.

**Product stays SaaS.** Point the existing OpenAI or Anthropic client at
`https://ai.alien.dev/v1` with the AI Gateway key and `X-Alien-External-ID`. Customers without
their own provider keep using yours only if your product decides so; make that an explicit
per-customer setting, not a silent fallback.

**Inside a data plane.** `new alien.AI("llm")`, linked to the workload, with an `ai/invoke` grant
in its permission profile. The workload calls Amazon Bedrock, Vertex AI, or Azure AI Foundry in
the same account with its own identity. No API keys. See `patterns.md` for the gateway launcher
and install-time choice between in-account AI and customer-provided keys.

- The customer must enable model access in their account. The portal card **Bring your own AI
  models** checks each required model and says what to fix.
- Open-weight models: managed families on those providers, or your own model server (for example
  vLLM) in a `Container` with `.gpu({ type, count })`.

## Remote Operator on an existing install

Docs: `use-cases/remote-operator`, `operate/remote-operator/add-to-existing-install`,
`operate/remote-operator/operations`, `operate/remote-operator/access-requests`.

- Keep the product's Helm chart, Terraform, or ECS service as the source of truth. Install the
  Operator as a **dedicated release** next to the application release; do not edit the
  application chart.
- Setup in the dashboard (**Set up Remote operator**) generates the chart or CloudFormation and
  one-time per-installation values. Keep those files out of version control. Never copy a Secret,
  token, or key to another environment.
- Review the Role or IAM it grants and the log scope (a Pod label) before installing.
- Declare operations in Helm values (`remoteOperator.operations`) with approval rules per
  operation. Secrets come from Kubernetes Secrets through `operationsEnv`.
- Verify with a read-only operation, not a ready Pod:
  `alien operations invoke --deployment <group>/<name> --operation kubernetes/get-pods`.
- Record the version you shipped from your existing pipeline: `alien release --no-stack --version <v>`.
- Access requests are time-boxed (default and maximum 6 hours). Operations are not a shell.
- If a GitOps controller (Argo CD, Flux) owns the application release, the Operator must not
  fight it: request changes, do not apply them behind the controller.

## Single-tenant in your cloud

Docs: `use-cases/single-tenant`, `deploy/single-tenant`.

The same `alien.ts`, deployed into a dedicated account or region in your cloud per customer. In
the dashboard: **Deployments**, **New Deployment**, **Deploy to your environment**, then account,
region, and (on AWS) the encryption key. Moving a customer to BYOC later is a placement change,
not a rewrite, so keep the stack free of assumptions about whose account it runs in.

## Kubernetes

Docs: `deploy/kubernetes`. The customer installs your chart once with Helm. It runs the Operator,
which pulls each release over outbound HTTPS (pull model). Check the chart's ServiceAccounts,
Pod Security requirements, PVCs, and StorageClass against the customer's cluster. Install into an
isolated test cluster with an explicit kubeconfig and context for every command.

## Linux machines (on-prem, bare metal)

Docs: `deploy/machines`, `build/compute`. Hosts join a deployment with a join command and run a
machine agent that pulls releases, updates itself one machine at a time, and keeps workloads
running offline on the last plan. No GPUs on Machines today. Use `Daemon` for per-host software;
see `patterns.md` for host daemons.

## Air-gapped

Docs: `deploy/deployment-models` (air-gapped section). Each release is packaged into a folder the
customer carries in and applies with your CLI. Confirm with the user before promising it.
