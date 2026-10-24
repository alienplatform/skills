# Playbooks

Command sequences that worked on real deployments. Replace `<dep>` with `dep_…` or `<group>/<name>`, and pass `--project` when the directory isn't linked.

## First look at any deployment (always)
```bash
alien deployments get <dep>            # status, current vs desired release, failed resources, Deployment updates table
alien deployments events <dep> --limit 50
alien logs --deployment <dep> --level error --since 1h
```
Read in this order: status → "Failed resources" lines → Deployment updates table (`Reasons`, `Action required`) → events → logs. If `get` fails to parse, `alien upgrade` then retry; as a stopgap `alien deployments ls --json | jq '.[] | select(.id=="<dep>")'`.

## Failed resource → cause → retry
```bash
alien deployments get <dep> --json | jq '.stackState.resources | to_entries[] | select(.value.status|test("failed")) | {name:.key, status:.value.status, error:.value.error}'
alien logs --deployment <dep> --level error --since 2h
alien logs --deployment <dep> --system --level error --since 2h     # platform-side: image pulls, mounts, credentials
# fix code/config → alien release, or fix environment → then
alien deployments retry <dep>
alien deployments wait <dep> --for ready --timeout 20m
```
"Interrupted" resources failed because another one failed; fix the first failure only. "Replicas did not become healthy" and "Polling timed out" are wrappers; the cause is in logs.

## Update didn't apply (Running but desired ≠ current)
1. `alien deployments get <dep>` → Deployment updates table.
2. `Action required` mentions setup / frozen resource / permission profile → owner reruns setup (from the deployment portal, the white-labeled CLI's `deploy --setup-update`, or a stack update). Do not retry.
3. `Needs inputs` → provide inputs.
4. Pinned → `alien deployments pin <dep>` with no release unpins.
5. Otherwise `alien releases get <rel>` for the rollout row, `deployments wait --for ready`.

## Customer reports an error at specific times
```bash
alien logs --deployment <dep> --from 2026-01-15T09:00:00Z --to 2026-01-15T09:05:00Z -q '429' --limit 200
alien logs --deployment <dep> --from <start> -q '"Rate limit exceeded"' --json | jq -r '.logs[].timestamp' | cut -c1-16 | uniq -c
alien logs --deployment <dep> --system --from <start> -q 'error OR capacity'
```
Narrow windows beat big limits (1000 max per query; split time ranges when `numHits` exceeds returned count).

## Not reporting / heartbeat stale
```bash
alien deployments get <dep>          # last heartbeat age
alien deployments machines <dep>     # Machines: per-machine heartbeat, network, peers, agent version
alien deployments resources <dep>
alien logs --deployment <dep> --system --since 30m
```
Fresh machine heartbeats + stale deployment = reporting path, not an outage. No heartbeats anywhere = outbound network or the environment is down; workloads keep running.

## Verify a rollout / recovery
```bash
alien releases get <rel>
alien deployments wait <dep> --for ready --timeout 15m --json
alien deployments resources <dep>
alien logs --deployment <dep> --since 10m -q '<a line your app logs on start>'
```
A healthy replica of the old release is not a rollout. For stateful containers, check `deployments volumes` and that the app's own data marker survived.

## Hold a deployment during an incident
```bash
alien deployments pin <dep> <rel_current>     # stop it following the channel
# … investigate / fix …
alien deployments pin <dep>                   # unpin
alien releases promote <rel_previous> --channel production   # roll the whole channel back
```

## Run something inside the environment
- Read app data: `alien commands invoke --deployment <dep> --command <name> --params '{…}'`.
- Cloud API as the management identity: `alien debug <dep> --request-access -- aws sts get-caller-identity` (needs approval).
- Machines host: `alien debug exec <dep> --machine <m> -- journalctl -u <unit> --since "10 min ago"`; container: `--resource <name>`.
- Remote Operator Kubernetes: `alien debug <dep> --request-access -- kubectl get pods -n <ns>`.

## Remove a deployment cleanly
1. `alien deployments delete <dep>`; wait (`deployments wait <dep> --for deleted`).
2. `teardown-required` → the owner deletes the setup (CloudFormation stack, Terraform, Helm release). For a stack mid-update, delete the deployment first, then the stack.
3. Resources already gone and record stuck → `alien deployments delete <dep> --force <deployment-name>` (the name is the confirmation; `--forget` is a hidden alias; cannot combine with `--yes`).
4. Audit the account by name prefix / tags. Retained by design: final volume snapshots; soft-deleted vaults (Azure).
`alien destroy` is for deployments this machine created with `alien deploy`; for setup-link/CFN installs use `deployments delete`.

## Private manager not becoming healthy
`alien managers status <mgr> --wait`, `alien managers events <mgr>`, `alien managers retry <mgr>`; then the cloud console for the manager's VMs/stack. If the CLI shows no reason, check the manager's VMs and setup output in the cloud console.
