# Boundary checks

Run every check against every candidate. Record the result in the decision record. A failed check
means fix the candidate or reject it.

## Content and metadata

1. **Does customer content transit the control plane?** Trace each call in the "what crosses"
   table. Request bodies, query strings, URL paths, logs, error reports, analytics events, and
   browser navigation all count. Fix: browser-to-data-plane calls with a short-lived token, signed
   upload URLs, thin events.
2. **Does content transit an Alien hosted gateway?** The Encryption Gateway and AI Gateway see
   plaintext. That can be acceptable, but the record must say it.
3. **Who defined "metadata"?** If the buyer's security review has not seen the list of fields that
   cross, mark it as an open question. Email addresses, file names, subject lines, counterparty
   IDs, and repository names are often treated as content.
4. **Do logs and telemetry from the data plane carry content?** Logs reach the manager unless
   telemetry is turned off for that deployment. Plan log redaction or turning telemetry off.

## Placement

5. **Is something in the data plane that belongs in the control plane?** Sign-in, user management,
   billing, plan enforcement, tenancy, admin UI, analytics, and release logic stay in the control
   plane. A data plane that runs its own auth provider is a smell.
6. **Is something in the control plane that touches content?** Background jobs, exports, search
   indexing, and AI features often do.
7. **Is the data plane the smallest piece?** For each component in it, write why it cannot stay
   in the control plane. Remove those without a reason.
8. **Does the design assume Alien hosts the control plane?** It does not. The vendor's control plane
   calls the Alien API.

## Trust and failure

9. **Fail closed.** When the data plane is unreachable, content operations return an error. No
   hosted fallback, no silent switch back after revocation.
10. **No side doors.** No shell endpoint, no "send us the secret" step, no privileged debug path
    outside Remote Operator's named operations.
11. **Customer secrets.** Values the customer provides go into their secret store (AWS SSM
    Parameter Store, Google Secret Manager, Azure Key Vault). The control plane knows only names.
12. **Credentials for linked resources come from links, not inputs.** A design that asks the
    customer to paste a database password for a resource Alien creates is wrong.

## Setup and operations

13. **Frozen or live, per resource.** Frozen: created at setup by the customer's admin, fewer
    management permissions, changes need setup rerun. Live: created and updated by Alien every
    release. Live does not mean recreated on each deploy; frozen does not mean "the data persists".
14. **What future change would hold a release?** Adding, removing, or changing a frozen resource,
    or changing permissions, waits until the admin reruns setup. Name the likely ones.
15. **Push or pull?** If the customer will not grant a cross-account role, or the target is
    Kubernetes or Linux hosts, use pull. Command delivery is a separate question from push or pull.
16. **Who operates it at 3 a.m.?** Name the operations the vendor needs (logs, restart, scale,
    migrate) and check Remote Operator covers them.

## Claims you must not make

Do not put these in a design or customer-facing text. They do not exist, or not as described:

- Webhooks from Alien for deployment state. Use polling, events, or Slack notifications.
- An embeddable setup portal (iframe or component). Use the hosted, white-labeled portal or build
  your own page on the API.
- A cost-estimation API. Cloud cost estimates are the vendor's own numbers, labeled as estimates.
- Per-resource progress text or friendly resource names from Alien.
- Immediate key revocation through the gateway. Say "within minutes".
- GPUs on Machines.
- A product "verified" or "activated" state in Alien. Activation is the vendor's own state.
- That deleting a deployment in Alien removes setup-owned resources. The customer deletes the
  setup stack (status `teardown-required`).
