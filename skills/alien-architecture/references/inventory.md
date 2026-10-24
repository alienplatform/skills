# Component inventory

Build the inventory from the code. Every row needs a file path. If you cannot cite a file, you do
not know the answer yet; say so in the row.

## Where to look

- Entry points: `main` files, `Dockerfile`s, `Procfile`, `docker-compose.yml`, `package.json`
  scripts, `Cargo.toml` binaries.
- Deploy path: Helm charts, Terraform, Pulumi, CloudFormation, Ansible, CI workflows under
  `.github/workflows`, shell scripts, runbooks. Record what each one creates.
- Configuration and secrets: env var loaders, config files, secret managers, `.env.example`.
- Data stores: ORM models, migrations, bucket names, queue names, cache clients.
- Outbound calls: third-party SDKs (auth, billing, analytics, email, LLM providers).
- Architecture or design docs in the repo. Read them before concluding anything.

## Worksheet

Copy this table into your notes and fill one row per component.

| Component | Path | Runtime | Data it reads or writes | Metadata or customer data | Private systems it reaches | Special hardware | Latency budget | Deployed today by | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| api | `services/api` | Node container | users, orgs, documents | both | none | none | 200 ms p95 | Helm | split: routes |
| ... | | | | | | | | | stays / moves / depends on the buyer |

Then list, separately:

- **Calls between components** that would cross the boundary if the two ended up on different
  sides. Note the fields each carries.
- **Third-party services** each component calls (auth provider, Stripe, analytics, email,
  LLM). These stay in the control plane unless the requirement names them.
- **State that must survive an upgrade** (running jobs, sessions, VMs). It constrains the
  workload model later.

## Default placement

Defaults, not answers. The buyer's requirement and security review override them.

| Component | Usually | Why |
|---|---|---|
| Sign-in, SSO, users, orgs, roles | Control plane | Shared; metadata |
| Billing, plans, usage metering | Control plane | Metadata. The data plane sends counts, not content. |
| Web UI, admin dashboards, analytics | Control plane | The browser fetches content from the data plane directly |
| Release and rollout logic | Control plane (Alien) | Alien runs this |
| Database of customer records | Data plane | Customer data |
| Files, documents, email bodies, uploads | Data plane | Customer data |
| Search indexes, caches, embeddings over customer data | Data plane | Derived from customer data |
| Workers that read or transform customer data | Data plane | They hold the data in memory |
| Connectors to the customer's internal systems | Data plane | Reachable only from inside their network |
| LLM calls with customer content in the prompt | Data plane, or the customer's model account | See local models |
| Webhooks and event delivery | Control plane with thin events (IDs only), unless payloads are content | Delivery infrastructure is costly to move |

## Signals to note

- A component described as a proxy that logs request bodies: it touches content.
- A search or analytics feature that copies content into a shared index: that index is customer
  data.
- A background job in the control plane that reads customer rows: it has to move, or it has to
  call the data plane for a count.
- An existing Helm chart or Terraform module customers already run: Remote Operator beside it may
  be all the requirement needs.
- Hardware needs (KVM, nested virtualization, GPUs, local NVMe): the data plane will be a daemon
  or container on specific compute. Check cloud quotas on day one.
