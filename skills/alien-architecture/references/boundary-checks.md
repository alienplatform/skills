# Boundary checks

Run every check against every candidate and record the result in the decision record. A failed
check means fix the candidate or reject it. After a fix, run the checks again.

## Content and metadata

1. **Does customer content transit your cloud?** Trace each call in the "what crosses" table.
   Request bodies, query strings, URL paths, command results, logs, error reports, analytics
   events, and browser navigation all count. Fixes: browser-to-deployment calls with a short-lived
   token, signed upload URLs, thin events, smaller command results.
2. **Does content transit an Alien hosted gateway?** The Encrypt/Decrypt API and the AI Gateway
   see plaintext. That can be acceptable, but the record must say it.
3. **Who defined "metadata"?** If the buyer's security review has not seen the list of fields that
   cross, mark it as an open question. Email addresses, file names, subject lines, counterparty
   IDs, and repository names are often treated as content.
4. **Do logs and telemetry from the deployment carry content?** Logs reach the manager unless
   telemetry is off for that deployment. Plan log redaction, or turn telemetry off.

## Placement

Checks 5 and 6 apply when the candidate is the control plane / data plane split. Checks 7 and 8
apply to every candidate.

5. **Is something in the data plane that belongs in the control plane?** Sign-in, user
   management, billing, plan enforcement, tenancy, admin UI, analytics, and release logic stay in
   the control plane. A data plane that runs its own auth provider is a warning sign.
6. **Is something in the control plane that touches content?** Background jobs, exports, search
   indexing, and AI features often do.
7. **Is the deployment the smallest piece?** For each component in it, write why it cannot stay in
   your cloud. Remove those without a reason. A private-network or latency requirement that ended
   up as a full data plane is a sign to step back to an agent or a cache.
8. **Does the design assume Alien hosts your backend?** It does not. Your backend calls the Alien
   API.

## Trust and failure

9. **Fail closed.** When the deployment is unreachable, content operations return an error. No
   hosted fallback, no silent switch back after revocation.
10. **No side doors.** No shell endpoint, no "send us the secret" step, no privileged debug path
    outside Remote Operator's named operations.
11. **Customer secrets.** Values the customer provides go into their secret store (AWS Systems
    Manager Parameter Store, Google Secret Manager, Azure Key Vault). Your backend knows only the
    names.
12. **Credentials for linked resources come from links, not inputs.** A design that asks the
    customer to paste a database password for a resource Alien creates is wrong.

## Initial setup and operations

13. **Frozen or live, per resource.** Frozen: created at initial setup by the customer's admin,
    fewer management permissions, changes need initial setup rerun. Live: created and updated by
    Alien on every release. Live does not mean recreated on each deploy; frozen does not mean "the
    data persists".
14. **What future change would hold a release?** Adding, removing, or changing a frozen resource,
    or changing permissions, waits until the customer's admin reruns initial setup. Name the likely
    ones.
15. **Push or pull?** If the customer won't grant a cross-account role, or the target is
    Kubernetes or Linux hosts, use pull. Command delivery is a separate question from push or pull.
16. **Who operates it at 3 a.m.?** Name the operations you need (logs, restart, scale, migrate)
    and check that Remote Operator covers them.

## Claims you must not make

Do not put these in a design or in customer-facing text. They do not exist, or not as described:

- An embeddable setup portal (iframe or component). Use the hosted, white-labeled deployment
  portal, or build your own setup screen on the API.
- A cost-estimation API. Cloud cost estimates are your own numbers, labeled as estimates.
- Immediate key revocation. Say "within minutes".
- GPUs on Machines (Linux hosts the customer joins).
- A product "verified" or "activated" state in Alien. Activation is your product's own state.
- That deleting a deployment in Alien removes the resources initial setup created. The customer's
  admin deletes the setup stack (status `teardown-required`).

For deployment state changes, Alien sends signed webhooks (`deployment.failed`,
`deployment.update_blocked`, `deployment.teardown_required`, and others). Docs:
`production/webhooks`.
