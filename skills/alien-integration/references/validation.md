# Validation ladder

Validation is behavioral: the product's real flow must work through the deployment, verified from
outside. "The process is up" proves nothing. Record every command you run; they become the PR's
verify section. Steps 2 onward are approval gates.

## 0. Quotas (day one)

If the product needs special compute (GPUs, nested virtualization, large instances), check quotas
in every account class you will touch before building anything.

## 1. Local

- `alien dev`, then the product's primary flow through commands or the endpoint.
- Two local deployments (`alien dev deploy --name customer-2 --platform local`) to check isolation.
- `@alienplatform/testing` suite green.
- Fail-closed check: stop the data plane and confirm the control plane's call errors.

## 2. Real cloud, with the customer's tools

- Release to a non-production channel or a test project.
- Onboard a test customer (`alien onboard customer-1`, or a setup link from your backend) and run
  setup **as the customer would**: through the portal and the white-labeled customer CLI or the
  generated CloudFormation, Terraform, or Helm package. Not with a generic developer CLI.
- Use a cloud account you control. Prefer the account's default network when quotas are tight.
- Verify from outside: endpoint responses, command results, data visible in the customer's bucket
  and absent from your control plane.
- Readiness is a chain: cloud resource healthy → workload registered → replicas healthy →
  product `/health` reports the expected version → real flow works. Check each link.
- Platforms: say which were defined, built, and qualified in a real deployment. Do not merge
  these into one "supported".

## 3. A second release while the first is live

- Start real work (jobs, sessions, data) on the deployed release.
- Release again with a code change, and separately with a configuration-only change. They take
  different paths.
- Confirm the new version is served (a version endpoint or a command returning the build ID) and
  nothing that must survive was lost.
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
- Classify each blocker (integration config, environment, Alien defect, app defect) as described
  in `SKILL.md`.
