# Profiling before you integrate

Produce a written profile with a file path for every answer. Profile only the components the
decision record moves; the rest stays as it is.

## 1. The components that move

- Processes, entry points, and what each talks to.
- State each keeps: databases, buckets, local files, in-memory maps. Anything a later request must
  find again belongs in a shared store (`Kv`, `Postgres`, `Storage`) before you run more than one
  replica.
- Read architecture docs in the repo before concluding anything.

## 2. The current deploy path (effect inventory)

Find the real deploy path: Helm, Terraform, Ansible, CI jobs, shell scripts, runbooks. List
everything it does. That responsibility moves to you, and the item you miss becomes a production
mystery later. Commonly missed:

- packages, kernel modules, sysctls
- disk layout and filesystem features
- users, groups, directories, ownership
- certificates: who issues, renews, distributes them
- firewall rules, routing, bridges
- systemd semantics (`Type=`, `KillMode=`, reload signals)
- database migrations and setup jobs, and their ordering
- post-deploy smoke tests: they show what the team fears breaking

For an existing Kubernetes install, record the chart's ServiceAccounts, Roles, Secrets, PVC and
StorageClass expectations, Pod Security requirements, and namespace.

## 3. Configuration and secrets

- Locate the config loader and the render pipeline (env vars, files, flags). The narrower the
  surface, the cleaner the integration: re-render the same inputs from Alien inputs and links so
  the product needs no config changes.
- For every credential: is it a linked resource (comes from `.link()`), a value you set per
  deployment (developer input), a value the customer owns (deployer secret in their secret store),
  or an internal secret nobody needs to type (generated input)?
- Note which secrets must never touch disk or argv.

## 4. Lifecycle constraints

- What must survive an upgrade (running jobs, VMs, sessions)?
- Singletons with in-place takeover? An existing zero-downtime upgrade mechanism? Reuse it.
- Drain semantics: can placement stop without stopping service?

## 5. Compute and traffic

- Request type: short request/response, streaming (SSE, long agent turns), background jobs.
  Streaming and long requests need a surface that streams end to end; check what each cloud
  emits for a `Worker` before choosing it over a `Container`.
- Startup cost: a large model or index loaded at start makes every cold start slow. Measure.
- Special hardware: GPUs, nested virtualization, privileged containers, host networking, local
  NVMe. These decide the workload model and are often quota-gated. Check quotas in the account
  class you will deploy to, on day one.
- Where callers run relative to the data plane: same VPC, customer network, public internet.

## Output

End the profile with the 3 to 6 constraints any valid implementation must respect. Keep the
profile in the PR description or a doc next to the decision record.
