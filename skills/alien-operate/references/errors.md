# Errors

What common messages mean and what to do. Check the exact text with `alien deployments get <dep>`
or `get --json`. Docs: `https://alien.dev/docs/production/troubleshooting.md`.

## Deployment failures

| Message | Meaning | Who acts | Next step |
|---|---|---|---|
| **Initial setup failed** | Initial setup couldn't create frozen resources or the management identity | Customer's admin | The admin fixes the cause and reruns initial setup with their credentials. With the setup CLI, `alien deployments retry` prints the command to rerun. |
| **Refresh failed** | Alien couldn't read the environment's state | Depends | Check the management identity and network, then retry |
| **Waiting for secrets** | A secret the customer provides is missing | Customer's admin | The admin writes it into their own secret store; workloads start once it's there |
| **Customer key unavailable**, `KEY_UNAVAILABLE` | The customer revoked or disabled their key | Customer's admin | The admin restores access; the deployment recovers on its own |
| `Resource was not deployed because resource '<x>' failed` (interrupted) | Another resource failed first | You | Read `<x>`'s error and fix that one |
| `MANAGED_WORKLOAD_FAILED (CrashLoopBackOff)` | Your container exits on start | You | `alien logs --deployment <dep> --level error`, fix, `alien release`, `deployments retry` |
| `Container replicas did not become healthy …` | Wrapper: the replica never passed its health check | Depends | `alien logs` and `alien logs --system` for the first startup error. `sts:AssumeRole failed` or credential errors point at initial setup. |
| `Polling timed out after N attempts …` | Wrapper: a resource stopped making progress | Depends | `deployments events`, `alien logs --system`, then `get --json` for the resource's error |
| `Failed to create IAM role …`, `AccessDenied`, `Invalid principal`, `PERMISSION_DENIED` | The management identity can't do this in the account | Customer's admin | The admin fixes the permission or policy, then retry |
| Quota or capacity errors (addresses, vCPUs, IPs) | The account is at a cloud limit | Customer's admin | The admin raises the quota or picks another network option, then retry |
| `VPC … needs private subnets` | The chosen network option doesn't fit the account | Customer's admin | The admin reruns initial setup with another network option |
| `Capacity group '<g>' requires N failure domains, but 0 valid domains were selected` | The network has no subnets usable for that group | Customer's admin | Check the imported network's subnets and zones, then retry |
| `Deployment health check failed` (repeating in events) | Health flaps between degraded and recovered | You | Logs around each event time |

## Updates that don't arrive

| What you see | Meaning | Next step |
|---|---|---|
| **Action required**: `Apply the updated setup to continue this update.` | The release changes frozen resources or permissions | The customer's admin reruns initial setup. Retry won't help. |
| `Cannot add frozen resources during update` | Same as above | Same as above |
| `Frozen resource '<id>' was modified` | Same as above | Same as above |
| `Permission profile '<p>' was modified` | Same as above | Same as above |
| Needs inputs | The release asks for a value the deployment doesn't have | Provide the input (**Edit inputs** on the deployment page) |
| **Update not confirmed** | The rollout wasn't confirmed in time; it may still finish | Treat it as in progress. `alien deployments retry <dep>` or **Check again**. |
| `is in status 'running' and cannot be retried` | Retry applies only to failed statuses | Read the **Deployment updates** table instead |
| Pinned | The deployment is held on a release | `alien deployments pin <dep_id>` with no release unpins it |

## Delete

| What you see | Next step |
|---|---|
| `teardown-required` | The customer's admin removes the setup stack (CloudFormation stack, Terraform, Helm release). Then wait for `deleted`. |
| `DELETE_FAILED` on the setup stack | The cloud console names the blocker (a non-empty bucket, an attached volume, a network in use). The admin removes it and deletes the stack again. |
| Delete fails while the stack is mid-update | Delete the deployment first, then the stack |
| Resources are already gone, the record stays | `alien deployments delete <dep> --force <deployment-name>`. The name is the confirmation; it can't be combined with `--yes`. Never force-delete while resources still exist. |
| `setupMethodMismatch` on `alien destroy` | `destroy` only removes deployments this machine created with `alien deploy`. Use `alien deployments delete`. |
| `Deployment '<n>' is not tracked` | Same as above |

After delete, check the account for leftovers by name prefix or tag. These stay on purpose: frozen
resources (such as a bucket with the customer's data), final volume snapshots, anything initial
setup didn't create (such as an existing VPC), and on Azure, key vaults in their soft-delete
retention period.

## CLI errors

| Message | Fix |
|---|---|
| `Use a deployment ID like dep_... or <group>/<name>` | Pass the ID or the group-qualified name, not the bare name |
| `No project is linked` | Pass `--project <project>`, or run `alien link` in the repository |
| `JSON_ERROR`, `unknown field …`, or another parse error | `alien upgrade`, then repeat. As a stopgap: `alien deployments ls --json \| jq '.[] \| select(.id=="<dep>")'` |
| `DEBUG_ACCESS_REQUEST_REQUIRED` | Rerun with `--request-access`, or create one with `alien access-requests create`, and wait for approval |
| `FEATURE_NOT_SUPPORTED` from `debug exec` or `debug shell` | They work on Your machines and local deployments. Elsewhere use `commands invoke` or `debug` with an access request. |
| `Limit must be between 1 and 1000` | Narrow `--from`/`--to` and run several queries |
| `--from` rejected | Use RFC 3339 with a zone: `2026-01-15T09:00:00Z` |
| `COMMAND_TARGET_AMBIGUOUS` (409) from `commands invoke` | More than one resource handles commands. Pass `--target <resource-id>`. |
| `belongs to a different project` on `destroy` | Run `alien upgrade` and retry with the deployment's own `--project`. If it persists, use `alien deployments delete` |
| `Deployment '<n>' is not tracked` right after `alien deploy` on the same machine | The OS keyring wasn't available, so tracking lived in memory for one run. Use `alien deployments delete <dep>` instead of `destroy` |
| `Failed to get deployment` from `alien logs` on a deleted deployment | `alien logs --manager <mgr> --project <p> -q 'resource_attributes.alien.deployment_id:<dep>'` |
| `--manager` errors without a project | Add `--project` |

## Waiting

- `deployments wait --for ready` means `running` with the desired release applied. It fails at once
  when the update is held for initial setup; read the **Deployment updates** table.
- `--for terminal` returns on any final state, including a failure. Check the status it prints.

## No logs

1. Is telemetry turned off for this deployment? `alien deployments get <dep>`.
2. Has the deployment connected to a manager, and reported recently? A disconnected deployment
   sends nothing new.
3. Kubernetes: log collection must be enabled in the chart values. Remote Operator collects logs
   only from Pods that match the label scope chosen in its setup.
4. Platform logs (image pulls, mounts, credentials) appear only with `--system`.
5. Widen the window. The default is the last hour.
