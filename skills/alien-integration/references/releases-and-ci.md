# Releases and CI

Docs: `https://alien.dev/docs/build/releases.md`, `operate/rollouts.md`,
`reference/cli/alien.md`.

## The model

- **Release first, then deploy to a customer.** A release is built once; every deployment follows.
- `alien release` builds for each platform the stack declares, pushes images, creates a release,
  and moves the `production` channel to it.
- **Published is not deployed.** Each deployment follows a channel or is pinned to a release and
  converges to it. There is no "deploy release X to customer Y" command: promote, pin, or change
  channels.
- Push deployments update right away. Pull deployments pick up the release on their next poll
  (about 30 seconds).
- A release that changes frozen resources or permissions is held for deployments until the
  customer's admin reruns setup.

## Commands

```bash
alien release                                  # build, push, move "production"
alien release --channel beta                   # move another channel
alien release --no-promote                     # create the release, move no channel
alien releases ls
alien releases get <rel_id>                    # rollout progress across deployments
alien releases promote <rel_id> --channel production
alien releases create-channel <name>
alien deployments pin <deployment-id> <rel_id> # omit the release to unpin
alien deployments set-channel <deployment-id> beta
alien deployments wait <group>/<name> --for ready
```

For Remote Operator on software Alien did not build, record the version an environment runs:

```bash
alien release --no-stack --version 1.4.0
```

## Staged rollout

1. `alien release --channel beta` from CI on every merge.
2. A few deployments follow `beta` (`alien deployments set-channel`).
3. After checks pass, `alien releases promote <rel_id> --channel production`.
4. `alien deployments wait <group>/<name> --for ready` on a canary, then watch the rest with
   `alien releases get <rel_id>`.

Verify the served artifact after a rollout (a version endpoint or a command that returns the
build ID). A healthy old replica is not a successful rollout.

## CI

Authenticate with a workspace API key in `ALIEN_API_KEY` and the workspace in `ALIEN_WORKSPACE`.
Pass `--project` so CI does not depend on `alien link` state. Changing CI is an approval gate:
show the user the workflow and its triggers before committing it.

```yaml title=".github/workflows/alien-release.yml"
name: Release data plane
on:
  push:
    branches: [main]
    paths: ["alien/**"]

jobs:
  release:
    runs-on: ubuntu-latest
    concurrency: alien-release
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install alien
        run: |
          curl -fsSL https://alien.dev/install | INSTALL_DIR="$HOME/.local/bin" sh
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - run: npm ci
        working-directory: alien
      - name: Release to beta
        working-directory: alien
        env:
          ALIEN_API_KEY: ${{ secrets.ALIEN_API_KEY }}
          ALIEN_WORKSPACE: acme
        run: alien release --project docproc --channel beta
```

Before pushing:

- Check every existing workflow's triggers. A push to a customer-facing branch can be a release.
- Keep the release job independent of the product's existing release jobs, so a failure in one
  does not change the other's result.
- If you changed a port, entrypoint, or path, grep kept workflows for the old value.
