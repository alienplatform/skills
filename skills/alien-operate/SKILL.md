---
name: alien-operate
description: Investigate and fix Alien deployments that are already running in remote environments. Use when a deployment failed, is stuck installing or updating, runs an older release than its channel, stopped reporting, shows errors to users, needs logs from a time window, needs a command or debug session inside the environment, or must be removed. Reads first with the alien CLI (deployments get, events, logs), finds the first failing resource and who must act, and proposes the exact next command. Never changes a deployment without the user's go-ahead. Not for writing alien.ts (alien-integration) or building the customer setup flow (alien-deploy).
license: Apache-2.0
metadata:
  author: alienplatform
  version: "0.1.0"
---

# Alien operate

A deployment runs in an environment you don't own. You can't log into it, and the customer's admin
owns its setup. This skill works from the `alien` CLI: it reads what the deployment reported, finds
the first thing that failed, and names who fixes it: you (code or release), the customer's admin
(setup, network, quota), or Alien support.

## Read the docs first

Fetch these as Markdown when you need detail:

- https://alien.dev/docs/operate/deployments.md
- https://alien.dev/docs/operate/logs.md
- https://alien.dev/docs/operate/rollouts.md
- https://alien.dev/docs/operate/troubleshooting.md
- https://alien.dev/docs/operate/remote-operator.md
- CLI reference: https://alien.dev/docs/reference/cli/alien.md

Run `alien <command> --help` before using a flag you haven't seen in this session.

## Rules

1. **Identify the deployment.** Use `dep_…` or `<group>/<name>`. Pass `--project` unless the
   directory is linked, and `--workspace` when the CLI is logged into several.
2. **Read first.** Always run `deployments get`, then `deployments events`, then `logs`, before
   anything else.
3. **Ask before you change anything.** Retry, release, promote, pin, delete, and debug sessions change
   a customer's environment or wake their admin. Say what the command does and who it affects, then
   wait for the user's go-ahead.
4. **Never work around an access approval.** If a command needs an access request, create it and
   wait. Don't look for credentials another way.
5. **Status is the last report.** Running means the last update finished. It doesn't mean the app is
   healthy or on the newest release. Confirm with heartbeat age, events, and logs.
6. **Fix the first failure.** Resources marked interrupted failed because another one did.
7. **Wrappers hide causes.** "Replicas did not become healthy", "Polling timed out", and
   `CrashLoopBackOff` mean: read the logs.
8. **Don't retry what retry can't fix.** A release that changes setup-owned resources or permissions
   waits for the admin to rerun setup. Retrying won't move it.
9. **Fix forward.** Fix the code and release again. Use `pin` to hold one deployment, or promote the
   previous release to roll back a channel.
10. **Parse errors mean an old CLI.** Run `alien upgrade`, then repeat the command.
11. **No customer names** in anything you write down. Use `customer-1`.

## Start

```bash
alien deployments get <dep>
alien deployments events <dep> --limit 50
alien logs --deployment <dep> --level error --since 1h
```

Read `get` in this order: status, the **Failed resources** lines, then the **Deployment updates**
table (**Reasons**, **Action required**). Then pick a branch below.

## Decision tree

```text
alien deployments get <dep>
│
├─ Failed (initial-setup-failed, provisioning-failed, update-failed, …)
│   ├─ Failed resources names X, others interrupted → read X's error
│   │   ├─ wrapper (replicas, polling, crash loop) → logs, then logs --system
│   │   │     → fix code → alien release → retry → wait
│   │   ├─ cloud permission, quota, or principal error → the admin fixes it → retry
│   │   └─ setup-owned resource → the admin reruns setup (it resumes)
│   └─ no failed resource shown → get --json and walk stackState errors
│
├─ Running, but current release ≠ desired release
│   ├─ Action required mentions setup, a frozen resource, or permissions
│   │     → the admin reruns setup. Don't retry.
│   ├─ Needs inputs → provide the inputs
│   ├─ Pinned → unpin, if that's intended
│   └─ Queued or updating → deployments wait --for ready; read events
│
├─ Stuck (pending, updating, initial-setup, provisioning for too long)
│   ├─ events and logs --system for a repeating error
│   ├─ get --json: a resource can be retrying while the top status looks fine
│   └─ retry refuses → say why, and who acts next
│
├─ Running, users see errors
│   └─ logs by time window, count matches, logs --system to rule out the platform,
│       commands invoke to read app state → fix → release → verify the rollout
│
├─ Not reporting
│   └─ deployments machines → resources → logs --system
│       fresh machine heartbeats → reporting problem, not an outage
│       no heartbeats → the environment or its outbound network is down: the admin
│
├─ No logs → telemetry off? Kubernetes log collection not enabled? deployment deleted?
│
├─ Need to look inside → commands invoke → debug with an access request → debug exec
│
├─ Delete stuck or teardown-required → the admin removes setup;
│   resources already gone → delete --force <name>; check for leftovers
│
└─ CLI error → references/errors.md
```

Each branch has a command sequence in `references/playbooks.md`.

## Report

End every investigation with:

- **Deployment**: ID, name, platform, status, current and desired release.
- **First failure**: the resource and its error, in one line.
- **Evidence**: the commands you ran and the lines that matter.
- **Who acts**: you, the customer's admin, or Alien support.
- **Next command**: exact, ready to run, and whether it changes anything.

## References

- `references/playbooks.md`: command sequences for each branch.
- `references/errors.md`: failure messages and CLI errors, with their causes and fixes.
