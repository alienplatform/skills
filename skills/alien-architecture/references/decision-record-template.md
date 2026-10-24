# Decision record template

Write this to `docs/alien-architecture.md` in the user's repository. Keep it under ~300 lines.
Plain language, no marketing. Replace every `<...>`.

````markdown
# Alien architecture: <product>

Status: proposed | approved (<name>, <date>)
Requirement owner: <who asked, e.g. "Customer 1 security team">

## Requirement

> <the requirement in the customer's words>

Answers: <where it runs | who holds the key | whose model | how it is operated | latency/offline>
Platforms: <AWS, Google Cloud, Azure, Kubernetes, Linux hosts>
Out of scope: <what the customer did not ask for>

## Components

| Component | Path | Data it touches | Verdict | Reason |
|---|---|---|---|---|
| <api> | `<path>` | <users, documents> | <stays/moves/split> | <one line> |

## Candidates

### A. <rung name> (recommended)

```text
┌─ CONTROL PLANE (your cloud) ─┐            ┌─ DATA PLANE (<where>) ─┐
│ <items>                      │ ◀── <how>  │ <items>                │
└──────────────────────────────┘            └────────────────────────┘
```

What crosses the boundary:

| Call | Direction | Mechanism | Fields |
|---|---|---|---|
| <usage report> | DP → CP | outbound HTTPS | <customerId, count, period> |
| <process document> | CP → DP | command | in: <documentId>; out: <status, pageCount> |
| <view document> | browser → DP | endpoint + short-lived token | <content, never via CP> |

Alien resources: <Storage "documents" (frozen), Kv "jobs" (frozen), Worker "processor" (live)>
Setup: <push|pull>; customer admin runs <CloudFormation|Terraform|Helm|CLI> once.
Changes that need setup rerun: <new frozen resource, permission changes>
Failure behavior: <data plane down → content routes return 503; no hosted fallback>
Operational cost: <what runs per customer, what the vendor supports>
Why not without Alien: <the plain alternative and why it loses or wins>

### B. <rung name>

<same fields>

### C. <rung name> (optional)

<same fields>

## Boundary checks

| Check | A | B |
|---|---|---|
| Content transits the control plane | no | <...> |
| Content transits a hosted gateway | no | <...> |
| Metadata list reviewed by buyer | open question | |
| Control-plane concerns in the data plane | none | |
| Fails closed | yes | |
| Customer secrets stay in their store | yes | |

## Recommendation

<Two to four sentences. Why A, and what would make you move to a larger rung later.>

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
