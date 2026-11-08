# Playbooks

Command sequences that worked on real deployments. Replace `<dep>` with `dep_…` or `<group>/<name>`, and pass `--project` when the directory isn't linked. Commands that change a deployment need the user's go-ahead first.

## First look at any deployment (always)
```bash
alien deployments get <dep>            # status, current vs desired release, failed resources, Deployment updates table
alien deployments events <dep> --limit 50
alien logs --deployment <dep> --level error --since 1h
```
Read in this order: status, then the **Failed resources** lines, then the **Deployment updates** table (**Reasons**, **Action required**), then events, then logs. If `get` fails to parse, run `alien upgrade` and repeat; as a stopgap, `alien deployments ls --json | jq '.[] | select(.id=="<dep>")'`.

## Failed resource
```bash
alien deployments get <dep> --json | jq '.stackState.resources | to_entries[] | select(.value.status|test("failed")) | {name:.key, status:.value.status, error:.value.error}'
alien logs --deployment <dep> --level error --since 2h
alien logs --deployment <dep> --system --level error --since 2h     # platform-side: image pulls, mounts, credentials
# fix code or config and run alien release, or have the environment fixed, then:
alien deployments retry <dep>
alien deployments wait <dep> --for ready --timeout 20m
```
Interrupted resources failed because another one failed; fix the first failure only. "Replicas did not become healthy" and "Polling timed out" are wrappers; the cause is in the logs. If the wait fails again, read the new error and repeat from the top.

## Update didn't apply (running, but current release ≠ desired release)
1. `alien deployments get <dep>`, then read the **Deployment updates** table.
2. **Action required** mentions setup, a frozen resource, or a permission profile: the customer's admin reruns initial setup (from the deployment portal, with the setup CLI's `deploy --setup-update`, or with a stack update). Do not retry.
3. **Needs inputs**: provide the inputs.
4. Pinned: `alien deployments pin <dep_id>` with no release unpins it. `pin` takes the deployment ID, not `<group>/<name>`.
5. **Update not confirmed**: treat it as in progress, then `alien deployments retry <dep>`.
6. Otherwise, `alien releases get <rel>` for the rollout row, then `alien deployments wait <dep> --for ready`.

## Customer reports an error at specific times
```bash
alien logs --deployment <dep> --from 2026-01-15T09:00:00Z --to 2026-01-15T09:05:00Z -q '429' --limit 200
alien logs --deployment <dep> --from <start> -q '"Rate limit exceeded"' --json | jq -r '.logs[].timestamp' | cut -c1-16 | uniq -c
alien logs --deployment <dep> --system --from <start> -q 'error OR capacity'
```
Narrow windows beat big limits: a query returns at most 1000 logs. Split the time range when `numHits` exceeds the returned count.

## Not reporting (heartbeat older than 5 minutes)
```bash
alien deployments get <dep>          # last heartbeat age
alien deployments machines <dep>     # Machines: per-machine heartbeat, network, peers, agent version
alien deployments resources <dep>
alien logs --deployment <dep> --system --since 30m
```
Fresh machine heartbeats with a stale deployment mean a reporting problem, not an outage. No heartbeats anywhere means the outbound network or the environment is down, and the customer's admin acts. Workloads keep running meanwhile.

## Verify a rollout or recovery
```bash
alien releases get <rel>
alien deployments wait <dep> --for ready --timeout 15m --json
alien deployments resources <dep>
alien logs --deployment <dep> --since 10m -q '<a line your app logs on start>'
```
A healthy replica of the old release is not a rollout. For stateful containers, check `deployments volumes` and that the app's own data marker survived.

## Hold a deployment during an incident
```bash
alien deployments pin <dep_id> <rel_current>  # stop it following the channel
# investigate and fix
alien deployments pin <dep_id>                # unpin
alien releases promote <rel_previous> --channel production   # roll the whole channel back
```

## Run something inside the environment
- Read app data: `alien commands invoke --deployment <dep> --command <name> --params '{…}'`.
- Cloud API as the management identity: `alien debug <dep> --request-access -- aws sts get-caller-identity` (needs approval).
- Machines host: `alien debug exec <dep> --machine <m> -- journalctl -u <unit> --since "10 min ago"`; container: `--resource <name>`.
- Remote Operator Kubernetes: `alien debug <dep> --request-access -- kubectl get pods -n <ns>`.

## Remove a deployment cleanly
1. `alien deployments delete <dep>`; wait (`deployments wait <dep> --for deleted`).
2. `teardown-required`: the customer's admin deletes the setup stack (CloudFormation stack, Terraform, Helm release). For a stack mid-update, delete the deployment first, then the stack.
3. Resources already gone and the record stuck: `alien deployments delete <dep> --force <deployment-name>`. The name is the confirmation, and `--force` can't be combined with `--yes`. Never force-delete while resources still exist.
4. Audit the account by name prefix or tags. Kept by design: frozen resources, final volume snapshots, anything initial setup didn't create, and soft-deleted key vaults on Azure.

`alien destroy` is only for deployments this machine created with `alien deploy`. For deployments created from a setup link, use `alien deployments delete`.

## Private manager not becoming healthy
```bash
alien managers status <mgr> --watch
alien managers events <mgr>
alien managers retry <mgr>
```
If the CLI shows no reason, check the manager's VMs and setup output in the cloud console.
