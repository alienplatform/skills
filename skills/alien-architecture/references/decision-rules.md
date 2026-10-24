# From answers to candidates

Apply the rules in order. Several can apply together: combine the pieces and keep each one as small
as it can be. Every component in a deployment runs in every customer environment, and you support
it there.

| # | If | Then | Not this |
|---|---|---|---|
| R1 | Q1 = latency only | Deploy only the piece on the hot path, kept current by your hosted backend. Writes, authority, and everything else stay hosted. State how stale reads can be and what happens when your backend is unreachable. | A data plane or a copy of the product |
| R2 | Q1 = private networks only | One small agent next to the private system, outbound only. Your backend sends commands; only the results cross. Name exactly which results. | Moving storage or the product |
| R3 | Q1 includes local resources | A daemon per host or device, updated on every release, working offline | Cloud compute that can't reach the host |
| R4 | Q1 = updates and operations only, with an existing Helm, Terraform, or ECS install | Remote Operator beside the install. For a small Kubernetes agent you build, let Alien build the chart: auto-updates, health, logs, and commands. | Re-architecting into a control plane ⇄ data plane split |
| R5 | Q3 = their key | A customer-managed key. The product stays hosted. | A deployment of your code |
| R6 | Q3 = only model calls | Their model account: the hosted AI gateway, or an `AI` resource in a deployment | Moving the product |
| R7 | Q3 = stored in their account | A bucket in their account that your backend reads with remote bindings. Say plainly that content reaches your backend. | Claiming it never leaves |
| R8 | Q3 = metadata may leave, or content and logs stay | Run `classify-data.md`. The data plane holds every content, derived, describing-text, and credential field, and the code that touches them. Everything else can stay in the control plane, if the product can be split that way (see R8d). If logs must stay, keep them in the data plane or filter them. | Moving sign-in, billing, users, UI, analytics, or the scheduler |
| R8a | …and only a few routes read or write content | A small data plane: those routes, storage, and a search index. Thin callbacks with metadata. | |
| R8b | …and the core loop reads content (an AI agent over documents) | A larger data plane: the agent loop, sandboxes, model calls, outputs. Orchestration stays hosted only if its payloads are IDs. | Moving only the sandbox |
| R8c | …and processing is stateless | Process in memory, store nothing, return results inside their environment | Adding a database |
| R8d | …and content and metadata share one service and database, and Q6 is A or B | Deploy the existing backend, with its own database, as the data plane. Keep sign-in, billing, placement, and routing hosted. Shrink the data plane later, one table at a time. | Designing a data plane with no database when that means rewriting most of the backend |
| R9 | Q1 includes "everything", or Q5 includes "the whole product" | Possible: deploy the whole product. Recommend against it first and explain the cost: every component runs in every environment, and sign-in, analytics, and billing are hard to run per customer. Ask whether the buyer accepts metadata leaving. If they truly need everything, keep what they allow hosted. Treat air-gapped as a separate project. | Accepting "everything" without asking what the buyer actually requires |
| R10 | Q2 = single-tenant | The same deployment in a dedicated account in your cloud. No customer setup. The same `alien.ts` can move to their account later. | A separate design |
| R11 | Q2 = Kubernetes, Linux hosts, or devices, or no cross-account role allowed | Pull mode with the Operator | Push with a cross-account role |
| R12 | Every candidate | Each component in the data plane needs a reason from the worksheet. Prefer managed resources (`Worker`, `Kv`, `Queue`, `Storage`) over running databases or clusters in every environment. | |

## Worked examples

These are composites. Use them to recognize a situation, not as templates.

1. **A messaging API; "our messages can't leave our account."** Sensitive data; their cloud account;
   metadata may leave. The worksheet puts bodies, subjects, previews, attachments, filenames, the
   search index, and signed URLs in the data plane. IDs, threads, labels, timestamps, delivery
   status, sizes, API keys, billing, and webhook settings stay hosted. Sender addresses are a
   judgment call recorded as an open question. Result (R8a): a few functions, storage, a key, and
   search in the data plane. Clients change only the API base URL. Webhooks carry IDs.
2. **An AI agent over a customer's documents; "nothing derived from our documents may leave."**
   The agent loop reads every document, so R8b applies: the loop, sandboxes, model calls, reports,
   and storage go in the data plane. Sign-in, billing, and orchestration with ID-only payloads stay
   hosted. Rejected: moving only the sandbox, and moving everything.
3. **An observability product; regulated customers.** The control plane keeps run IDs, names,
   status, and timing. The data plane keeps inputs, outputs, error messages, and the indexes over
   them. Queries over private fields run in the data plane.
4. **An event delivery service; "payloads stay with us, and you must reach our internal
   services."** Sensitive data plus private networks. Payloads, attempts with bodies, and the
   delivery worker go in the data plane, which reaches private endpoints. The endpoint registry,
   retry state by ID, and billing stay hosted. `Queue` and `Kv` instead of a database.
5. **An analytics product that reads a customer's private database.** Private networks only (R2).
   One connector next to the database. Your backend sends queries; results return. If the buyer
   also wants a kill switch, add a customer-managed key (R5).
6. **A security scanner shipped as a Helm chart.** Updates and operations only (R4). Alien builds
   the chart for a small read-only agent; the Operator brings auto-updates, health, logs, and
   commands. Nothing is re-architected.
7. **A proxy customers already run in their cluster.** Updates and operations (R4). Remote Operator
   beside their Helm release, plus typed commands. Rejected: moving the proxy onto new compute with
   a public load balancer, which changes the traffic path.
8. **"Everything must run in our data center."** R9. Ask which part of the requirement is about
   data. If it's the data, propose example 1's split with the data plane on their servers. If they
   truly need everything, deploy the whole product, keep what they allow hosted, and record the
   support cost.
