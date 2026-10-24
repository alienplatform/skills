# Decision record template

Write this to `docs/alien-architecture.md` in the user's repository. Keep it under ~300 lines.
Plain language, no marketing. Replace every `<...>`.

````markdown
# Alien architecture: <product>

Status: proposed | approved (<name>, <date>)
Requirement owner: <who asked, e.g. "Customer 1 security team">

## Requirement

> <the requirement in the customer's words>

Answers (from `questions.md`):
- Why it runs outside your cloud: <sensitive data | private networks | local resources | latency | updates and operations only | everything>
- Where it runs: <single-tenant | their cloud account | their Kubernetes | their servers or devices>
- What may leave: <metadata, not content | content and logs stay | ...> (sensitive data only)
- Sensitive kinds: <content, derived, describing text, ...> (sensitive data only)

Out of scope: <what the customer did not ask for>

## Components

| Component | Path | Data it touches | Verdict | Reason |
|---|---|---|---|---|
| <api> | `<path>` | <users, documents> | <stays/moves/split> | <one line> |

## What stays where

Only when sensitive data is in scope. The filled worksheet from `classify-data.md`.

| Field or path | Where in the code | Class | Plane | Crosses as | Reason or open question |
|---|---|---|---|---|---|

## Candidates

### A. <option name> (recommended)

Option: <only the customer's own services | an agent or connector | a local cache | the part that touches the data | the whole product>

```text
┌─ YOUR CLOUD ─────────────────┐            ┌─ <where: customer-1 AWS account> ─┐
│ <items>                      │ ◀── <how>  │ <items>                           │
└──────────────────────────────┘            └───────────────────────────────────┘
```

What crosses the boundary:

| Call | Direction | Mechanism | Fields |
|---|---|---|---|
| <usage report> | deployment → your backend | outbound HTTPS | <customerId, count, period> |
| <process document> | your backend → deployment | command | in: <documentId>; out: <status, pageCount> |
| <view document> | browser → deployment | endpoint + short-lived token | <content, never via your cloud> |

Alien resources: <Storage "documents" (frozen), Kv "jobs" (frozen), Worker "processor" (live)>
Setup: <push|pull>; customer admin runs <CloudFormation|Terraform|Helm|CLI> once.
Changes that need setup rerun: <new frozen resource, permission changes>
Failure behavior: <deployment down → content routes return 503; no hosted fallback>
Operational cost: <what runs per customer, what the vendor supports>
Why not without Alien: <the plain alternative and why it loses or wins>

### B. <option name>

<same fields>

### C. <option name> (optional)

<same fields>

## Boundary checks

| Check | A | B |
|---|---|---|
| Content transits your cloud | no | <...> |
| Content transits a hosted gateway | no | <...> |
| Metadata list reviewed by buyer | open question | |
| Hosted concerns (sign-in, billing, UI) in the deployment | none | |
| Fails closed | yes | |
| Customer secrets stay in their store | yes | |

## Recommendation

<Two to four sentences. Why A, and what would make you move to a larger option later.>

## Rejected options

| Option | Why rejected |
|---|---|
| <B> | <reason> |
| <Move the whole product> | <reason> |

## Open questions for the buyer

- <Is the document title metadata or content?>

## Next

After approval, implement with the `alien-integration` skill.
````
