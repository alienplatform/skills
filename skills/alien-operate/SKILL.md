---
name: alien-operate
description: Investigates and fixes Alien deployments that already run in remote environments. Use when a deployment failed, is stuck in initial setup or an update, runs an older release than its channel, stopped reporting, waits for secrets, shows errors to users, needs logs from a time window, needs a command or debug session inside the environment, or must be removed. Reads first with the alien CLI (deployments get, events, logs), finds the first failing resource and who must act, and proposes the exact next command. Never changes a deployment without the user's go-ahead. Not for writing alien.ts (alien-integration) or building the customer setup flow (alien-deploy).
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien operate

A deployment runs in an environment you don't own. You can't log into it, and the customer's admin
owns its **initial setup**, the one-time step that created the management identity and the frozen
resources. This skill works from the `alien` CLI: it reads what the deployment reported, finds the
first thing that failed, and names who fixes it: you (code or release), the customer's admin
(initial setup, network, quota), or Alien support.

## Docs

Fetch these as Markdown when you need detail:

- https://alien.dev/docs/production/troubleshooting.md
- https://alien.dev/docs/production/debugging.md
- https://alien.dev/docs/production/deployments.md
- https://alien.dev/docs/production/logs.md
- https://alien.dev/docs/production/rollouts.md
- https://alien.dev/docs/production/remote-operator.md
- CLI reference: https://alien.dev/docs/reference/cli/alien.md

Run `alien <command> --help` before using a flag you haven't seen in this session.

## Rules

1. **Identify the deployment.** Use `dep_…` or `<group>/<name>`. Pass `--project` unless the
   directory is linked, and `--workspace` when the CLI is logged into several.
2. **Read first.** Always run `deployments get`, then `deployments events`, then `logs`, before
   anything else.
3. **Ask before you change anything.** Retry, release, promote, pin, delete, and debug sessions
   change a customer's environment or wake their admin. Say what the command does and who it
   affects, then wait for the user's go-ahead.
4. **Never work around an access approval.** If a command needs an access request, create it and
   wait. Don't look for credentials another way.
5. **Status is the last report.** `running` means the last update finished. It doesn't mean the
   app is healthy or on the newest release. Confirm with heartbeat age, events, and logs.
6. **Fix the first failure.** Resources marked interrupted failed because another one did.
7. **Wrappers hide causes.** "Replicas did not become healthy", "Polling timed out", and
   `CrashLoopBackOff` mean: read the logs.
8. **Don't retry what retry can't fix.** A release that changes frozen resources or permissions
   waits for the customer's admin to rerun initial setup. Retrying won't move it. A new release
   fixes code, not the environment.
9. **Fix forward.** Fix the code and release again. Use `pin` to hold one deployment, or promote
   the previous release to roll back a channel.
10. **Parse errors mean an old CLI.** Run `alien upgrade`, then repeat the command.
11. **No customer names** in anything you write down. Use `customer-1`.

## Investigation

Copy this checklist and tick it off:

```text
- [ ] 1. Read: deployments get, deployments events, logs
- [ ] 2. Pick the branch in the decision tree
- [ ] 3. Run the branch's playbook (read-only commands first)
- [ ] 4. Name the first failure and who acts
- [ ] 5. Propose the next command; wait for the go-ahead before any change
- [ ] 6. After a change, verify the rollout; if it still fails, go back to step 1
```

Start with:

```bash
alien deployments get <dep>
alien deployments events <dep> --limit 50
alien logs --deployment <dep> --level error --since 1h
```

Read `get` in this order: status, the **Failed resources** lines, then the **Deployment updates**
table (**Reasons**, **Action required**).

## Decision tree

```text
alien deployments get <dep>
│
├─ Failed (initial-setup-failed, provisioning-failed, update-failed, …)
│   ├─ Failed resources names X, others interrupted → read X's error
│   │   ├─ wrapper (replicas, polling, crash loop) → logs, then logs --system
│   │   │     → fix code → alien release → retry → wait
│   │   ├─ cloud permission, quota, or principal error → the customer's admin fixes it → retry
│   │   └─ initial-setup-failed → the customer's admin reruns initial setup (it resumes)
│   └─ no failed resource shown → get --json and walk each resource's error
│
├─ Running, but current release ≠ desired release
│   ├─ Action required mentions setup, a frozen resource, or permissions
│   │     → the customer's admin reruns initial setup. Don't retry.
│   ├─ Needs inputs → provide the inputs
│   ├─ Pinned → unpin, if that's intended
│   ├─ Update not confirmed → retry, or Check again on the deployment page
│   └─ Queued or updating → deployments wait --for ready; read events
│
├─ Stuck (pending, updating, initial-setup, provisioning for too long)
│   ├─ events and logs --system for a repeating error
│   ├─ get --json: a resource can be retrying while the top status looks fine
│   └─ retry refuses → say why, and who acts next
│
├─ Waiting for secrets → the customer writes the secret into their own secret store
│
├─ Customer key unavailable → the customer restores access to their key; it recovers on its own
│
├─ Running, users see errors
│   └─ logs by time window, count matches, logs --system to rule out the platform,
│       commands invoke to read app state → fix → release → verify the rollout
│
├─ Not reporting (last heartbeat older than 5 minutes)
│   └─ deployments machines → resources → logs --system
│       fresh machine heartbeats → reporting problem, not an outage
│       no heartbeats → the environment or its outbound network is down: the customer's admin
│
├─ No logs → telemetry off? not connected to a manager? Kubernetes log scope? deleted?
│
├─ Need to look inside → commands invoke → debug with an access request → debug exec
│
├─ Delete stuck or teardown-required → the customer's admin removes the setup stack;
│   resources already gone → delete --force <name>; check for leftovers
│
└─ CLI error → references/errors.md
```

## Report

End every investigation with:

- **Deployment**: ID, name, platform, status, current and desired release.
- **First failure**: the resource and its error, in one line.
- **Evidence**: the commands you ran and the lines that matter.
- **Who acts**: you, the customer's admin, or Alien support.
- **Next command**: exact, ready to run, and whether it changes anything.

## References

- [references/playbooks.md](references/playbooks.md): the command sequence for each branch of the
  decision tree. Load once you have picked a branch.
- [references/errors.md](references/errors.md): failure messages and CLI errors, with causes and
  fixes. Load when a command or a status shows an error message you need to interpret.
