# Bring an existing install to Alien

Use this when the product already installs somewhere as container images: a Helm chart, a
Compose file, ECS task definitions, or Terraform. Read the file for your starting point first. It
says how to read the source and how each object maps. Then follow the steps here, which are the
same for every format. Docs: `guide/existing-app`, `infrastructure/container`,
`guide/inputs-and-secrets`.

| Starting point | Read first |
|---|---|
| Helm chart, Kustomize, Kubernetes manifests | `from-helm.md` |
| `docker-compose.yml` or `compose.yaml` | `from-compose.md` |
| ECS task definitions and services | `from-ecs.md` |
| Terraform, CDK, or Pulumi that creates databases, buckets, and queues | `from-terraform.md`, then the file for the workloads it runs |

## Contents

- Before you start
- Checklist
- Steps
- Known gaps

## Before you start

Every source format has mechanisms with no one-to-one Alien resource: Jobs, init containers,
sidecars, mounted config files, log routers. Most exist only because the old platform needed
them. Keep the product's behavior and move each mechanism's work to the place the steps below
name. A product that looks unsupported at first reading almost never is.

Before you rule out an Alien resource, try it in `alien dev`. A limit found by reading docs is a
guess. If the limit is real, report it as a gap and keep the integration on Alien. Don't build a
separate installer around it.

## Checklist

Copy this into the PR description or the mapping document and check items off:

```text
- [ ] 1. Rendered the source with production values
- [ ] 2. Wrote the plan with a script
- [ ] 3. Audit table: every object ported, replaced, or dropped with a reason
- [ ] 4. Inspected every image (or listed what is unverified)
- [ ] 5. One named Container per service
- [ ] 6. Stateful services and setup steps placed
- [ ] 7. Config files, sidecars, inputs, and credential formats handled
- [ ] 8. Launcher for images that don't use the SDK
- [ ] 9. Hostnames, writable paths, permissions, compute, health checks
- [ ] 10. Rendered and linted the setup template
- [ ] 11. Ran the main action against the built images
- [ ] 12. Validation ladder passed
- [ ] 13. Release published from CI
```

## Steps

1. **Render, don't read.** Use the render command in your starting-point file, with the values
   real customers use. Turn on bundled dependencies you will replace (a bundled Postgres), so the
   output still contains the settings that point at them.
2. **Write the plan with a script.** A small script (`scripts/prepare.py` or similar) reads the
   rendered output and writes one entry per service: image, command and args, env, ports, mounts,
   and which secret each container references. It never writes a secret's value. It fails on any
   object kind or field it doesn't understand. Write `alien.ts` by hand from the plan; don't
   import the plan, so reviewers see every image and command. When the source changes, rerun the
   script and review the plan's diff.
3. **Audit every object.** A table with one row per rendered object, and per hook, scheduled
   job, sidecar, and init container: ported, replaced by what, or dropped and why. Nothing is
   dropped silently.
4. **Inspect every image.** `docker pull` each one with the vendor's registry login, then
   `docker inspect` it. Record OS, libc (glibc or musl), architecture, `Entrypoint` and `Cmd`,
   user ID, and the paths it writes. A public image that fails to pull usually has a wrong tag.
   If you can't pull an image, mark each fact unverified and list it as an open question. Show
   the plan, the audit, and the image facts to the user before writing `alien.ts`. With no user
   to ask, write them to the mapping document first.
5. **One named, commented `alien.Container` per service.** `.code({ type: "image", image })`,
   `.port()`, `.cpu()`, `.memory()`, `.replicas()`. Never generate containers from a list. Name
   each container after the hostname other services use today (the Kubernetes Service, the
   Compose service, the Service Connect name), so `http://api:8000` keeps resolving.
6. **Stateful services and setup steps.** Bundled databases, caches, analytics stores, durable
   execution engines, and every one-shot job: follow `stateful-services.md`. Scheduled jobs
   become a periodic task inside an existing service, or a Worker with a schedule trigger. On
   AWS, Workers build for arm64 only; in an x86-only app, don't add a Worker. Don't build a job
   framework.
7. **Config files.** Bake non-secret files into a thin image (`FROM vendor-image`, then `COPY`),
   built with `{ type: "source", src: "./deploy/<service>", toolchain: { type: "docker" } }`.
   `src` is the build context and `dockerfile` is relative to it, so the context must contain
   every file the Dockerfile copies.
   Render files that hold secrets from env at start, into a private tmpfs directory, with a real
   serializer. Never bake a secret into an image layer.
8. **Sidecars.** Find out why each exists. Fold a health sidecar into the main process's
   readiness endpoint. Drop log and metrics shippers. Record every dropped sidecar in the audit.
9. **Inputs.** Customer choices and credentials are `providedBy: "deployer"`, as few as
   possible. Passwords and keys the old install generated become `providedBy: "developer"`
   secrets with `generate: { length }` and `targetResources` naming every container that uses
   them. Never copy a value from the source into `alien.ts`, and never turn the source's secret
   list into a customer form.
10. **Credential formats.** A generated input is a plain random string. Find out what each
    consumer expects: a prefix (`sk-...`), a JSON list (`["key"]`), an exact length, a character
    set. Adapt in the launcher. Two forms of one value come from one input.
11. **Launcher for images that don't use the SDK.** Add a launcher to the thin image. It resolves
    bindings with `@alienplatform/sdk` (for example `postgres("db").connection()`), sets the env
    names the app already reads, rewrites public URLs from resolved endpoints, then execs the
    original `Entrypoint` and `Cmd` from step 4. This one module is the only code that knows
    about Alien. The SDK's native module has no musl build: on Alpine images, install a glibc
    Node beside the app, or copy the app's static binaries onto a Debian base.
12. **Hostnames.** Rewrite in-cluster names (`api.ns.svc.cluster.local`, `api.ns`,
    `api.internal`) to the resource ID. Rewrite only hosts that are services in the source,
    never external hosts. Public URLs come from the resolved endpoints at start, not from the
    source's domain values.
13. **Writable paths.** Check that every path the image writes (`/tmp`, data directories,
    volumes) is writable by the image's user. A launcher can fix ownership, then drop to that
    user.
14. **Permissions.** One profile per service. Grant resource-scoped permissions only to services
    that link the resource. Services that share a profile but receive different secrets fail
    validation. Prove each grant with a real SDK call from the deployed container.
15. **Compute.** One ComputeCluster pool with an explicit architecture, CPU, and memory that
    cover the sum of container requests. Check the machine type and disk size Alien picked before
    the first cloud deploy.
16. **Health checks.** Use the app's real readiness path. Measure cold start, including
    migrations, and set `failureThreshold` to match. Services with no HTTP endpoint: see
    `stateful-services.md`.
17. **Render and lint.** `alien render --format cloudformation --stack . > template.yaml`, then
    `cfn-lint template.yaml`. Fix every error, then render again. See `alien-ts.md`.
18. **Run the built images.** Start each image's launcher against real bindings (`alien dev` or
    a test deployment) and call the product's main action. A test that only starts the process
    hides a missing native module or a wrong env name.
19. **Validate in order.** `alien dev`; a real login and the product's main action (not only
    "Running"); initial setup in a cloud account; a fresh install; a restart with data kept; an
    upgrade. See `validation.md`. When a step fails, fix it and rerun from that step.
20. **Publish.** `docker login` to the vendor registry on the build machine. `alien release`
    pulls each image with that login and re-hosts it. Deployments pull from Alien's registry with
    the deployment token and never need the vendor's login. AWS defaults to `linux-arm64`: for
    x86-only images, use `alien release --targets linux-x64` and set the pool's architecture to
    match. See `releases-and-ci.md`.

## Known gaps

Report these instead of hiding them:

- No general file mounts, sidecars, or scheduled container runs.
- No shared file system across replicas. A volume belongs to one replica.
- No musl build of the SDK's native module.
- On AWS, a stack that mixes a Worker with x86-only containers can't build for one architecture.
