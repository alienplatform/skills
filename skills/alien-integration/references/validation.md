# Validation ladder

Validation is behavioral: the product's real flow must work through the deployment, verified from
outside. "The process is up" proves nothing. Record every command you run; they become the PR's
verify section. Steps 2 onward are approval gates.

## 0. Quotas (day one)

If the product needs special compute (GPUs, nested virtualization, large instances), check quotas
in every account class you will touch before building anything. For AI models, check the
requests-per-minute quota and send one full-size request; a short probe proves access, not
capacity.

## 1. Local

- `alien render` plus a linter for each setup format you ship (see `alien-ts.md`).
- `alien dev`, then the product's primary flow through commands or the endpoint.
- Two local deployments (`alien dev deploy --name customer-2 --platform local`) to check isolation.
- `@alienplatform/testing` suite green.
- Fail-closed check: stop the data plane and confirm the control plane's call errors.

## 2. Real cloud, with your customer's tools

- Release to a non-production channel or a test project.
- Onboard a test customer (`alien onboard customer-1 --allow you@example.com`, or a setup link from your backend) and run
  setup **as the customer would**: through the portal and the white-labeled customer CLI or the
  generated CloudFormation, Terraform, or Helm package. Not with a generic developer CLI.
- Use a cloud account you control. Prefer the account's default network when quotas are tight.
- Verify from outside: endpoint responses, command results, data visible in your customer's bucket
  and absent from your control plane.
- Readiness is a chain: cloud resource healthy → workload registered → replicas healthy →
  product `/health` reports the expected version → real flow works. Check each link.
- Platforms: say which were defined, built, and qualified in a real deployment. Do not merge
  these into one "supported".
- A cloud cycle (release, update, check) takes 10 minutes or more, and large images add more.
  Reproduce each container's startup locally first, including the cloud's rules (for example a
  database that only accepts TLS), and bundle fixes into one release.

### Prove the promises

Each claim in the decision record gets a test that would fail if the claim were false.

- **Customer-managed key.** Disable the key in your customer's key service. A real write fails
  (a storage upload, a database write) with the provider's disabled-key error. Re-enable it. The
  next write succeeds and data written before is still readable. Note which stores the key does
  not cover (machine root disks, for example) in the runbook. A volume already attached keeps
  serving reads after the key is disabled: restart a stateful container and confirm it can't
  come back, and say so in the runbook instead of promising instant revocation.
- **Customer's models.** Call every model the product uses through the deployment, including
  helper models, in your customer's account. Unset any provider key the client could fall back to.
  For an agent, run one conversation that calls a tool and continues for a second turn, and check
  the final answer. Tests pass the provider's model ID as it appears on the wire.
- **Defaults and the browser.** Run the main flow with default settings and no saved preferences.
  Load every login and landing page in a fresh browser profile and list its network requests:
  only the deployment's own origin should appear (no third-party CDN, fonts, or analytics).
- **Data stays.** Put unique marker strings into test content. Search for them in your customer's
  stores (they are there) and in your control plane's database, logs, queues, and analytics (they
  are not).
- **Isolation.** Two test customers; one can't read the other's data through any endpoint.
- **Stateful data.** Write data, update to a new release, restart each stateful container, and
  read the data back.

## 3. A second release while the first is live

- Start real work (jobs, sessions, data) on the deployed release.
- Release again with a code change, and separately with a configuration-only change. They take
  different paths.
- Confirm the new version is served (a version endpoint or a command returning the build ID) and
  nothing that must survive was lost.
- Some changes (container ports, for example) are refused only when the update runs, not at
  release time. A deployment in `update-failed` recovers with a newer release, so test risky
  changes on a test deployment first.
- If the design changes a frozen resource or permissions later, confirm the release is held and
  the portal asks the admin to rerun setup.
- Re-test the setup link you already sent, not only a fresh one.

## 4. Teardown audit

- Remove the deployment the way the customer would (delete the stack or run the CLI's `destroy`).
- Audit separately: runtime resources, setup-owned resources, intentionally retained data
  (buckets, databases), and the deployment record in Alien.
- An empty Terraform state or a deleted stack is one layer, not proof.
- Clean up leftover resources in test accounts; leaked networks and addresses exhaust quotas.

## Debugging discipline

- One bug per cloud cycle. Write down what each cycle proved.
- Rule out stale local builds, stale keys, laptop sleep, and provider outages before blaming the
  product or Alien.
- Keep per-run artifacts (deploy output, status snapshots, command results).
- Read the deployment's logs with Alien's system components included
  (`alien logs --deployment <id> --system`) before logging in to a host. Container start failures
  and probe results show there.
- Keep a gap register: one entry per suspected Alien gap with evidence, the workaround, and its
  status. Recheck each entry against the current release before reporting it; many close.
- Record walkthrough videos from a normal network. A proxy that intercepts TLS breaks WebSockets
  and browser certificate trust.
- Classify each blocker (integration config, environment, Alien defect, app defect) as described
  in `SKILL.md`.
