# Existing apps: Helm charts, compose files, and container images

Use this when the repository already ships the product as container images with a Helm chart or
a `docker-compose.yml`, and the decision record says the whole product (or most of it) installs
in the customer's environment. Docs: `guide/existing-app`, `infrastructure/container`,
`guide/inputs-and-secrets`, `infrastructure/platforms/kubernetes`.

A chart uses Kubernetes mechanisms with no one-to-one Alien resource (Jobs, CronJobs, init
containers, sidecars, mounted ConfigMaps, generated Secrets). A first reading of the resource
list makes the product look unsupported. It almost never is: most of those mechanisms exist only
because Kubernetes needs them. Keep the product's behavior and move each mechanism's work to the
place below. Add a workaround only when no existing capability fits, and report it as a gap.

Before you rule out an Alien resource, try it in `alien dev`. A limit found by reading docs is a
guess. If it holds, report it as a gap and keep the integration on Alien; don't build a separate
installer around it.

## Choose the path first

- **Full install from your images** (this file): the customer wants a managed install in their
  cloud account, cluster, or servers, updated by you.
- **Smaller data plane**: only part of the product has to run remotely. Go back to
  `alien-architecture`.
- **Remote Operator beside the chart**: the customer must keep running your chart in their own
  cluster. Don't convert the chart; see `standalone-paths.md`.

Record which one and why in the decision record.

## Steps

1. **Render, don't read.** Run `helm template` with the values customers actually use, or
   `docker compose config`. Turn on bundled dependencies you will replace (a bundled Postgres) so
   the chart still renders the env and secrets that point at them.
2. **Write a plan file with a script.** A small script (`scripts/prepare.py` or similar) parses
   the rendered objects and writes one entry per service: image, command and args, env, ports,
   mounts, and the secrets each container references. `alien.ts` reads the plan for those values
   and stays hand-written for everything a reviewer judges: sizing, ports, health checks,
   permissions, links. The plan records which secret each container references, never a secret's
   value. The script fails on an object kind or field it doesn't understand. When the chart
   changes, you rerun the script instead of re-reading YAML.
3. **Audit every object.** A table in the PR or decision record with one row per rendered object
   (and per Job, hook, CronJob, sidecar, and init container): ported, replaced by what, or dropped
   and why. Nothing is dropped silently.
4. **Check every image.** `docker pull` each one with the vendor's credentials, and
   `docker inspect` it. Record OS, libc (glibc or musl), architecture, `Entrypoint` and `Cmd`,
   user ID, and which paths it writes to. A public image that fails to pull usually has a wrong
   tag. If you can't pull an image, mark each of those facts unverified and list them as open
   questions. Show the inventory and the mapping to the user before writing `alien.ts`; in a run
   with no user to ask, write them to the mapping document first.
5. **One named, commented `alien.Container` per service.** `.code({ type: "image", image })`,
   `.port()`, `.cpu()`, `.memory()`, `.replicas()`. Never generate workloads from a list. Name each
   container after the chart's Service, so `http://api:8000` keeps resolving.
6. **Map the rest** with the table below.
7. **Bundled databases and other stateful services**: follow `stateful-services.md`.
8. **Jobs, hooks, and compose one-shots**: move each into the setup steps in
   `stateful-services.md`. CronJobs become a periodic task inside an existing service, or a Worker
   with a schedule trigger if the app can take one. On AWS, Workers build for Arm64 only; in an
   x86-only app, don't add a Worker. Don't build a Job framework.
9. **Config files.** Bake non-secret files into a thin image (`FROM vendor-image`, `COPY`), built
   with `{ type: "source", toolchain: { type: "docker" } }`. Render secret-bearing files from env
   at start into a private tmpfs directory, with a real serializer. Never bake a secret into an
   image layer.
10. **Sidecars.** Find out why each exists. Fold health sidecars into the main process's readiness
    endpoint; drop optional ones and record them in the audit.
11. **Inputs.** Customer choices and credentials are `providedBy: "deployer"`, as few as possible.
    Passwords and keys the chart generates become `providedBy: "developer"` secrets with
    `generate: { length }` and `targetResources` naming every container that references them.
    Drop the chart's rendered Secret values once every reference is an input. Never turn the
    chart's secret list into a customer form.
12. **Credential formats.** A generated input is a plain random string. Find out what each
    consumer expects: a prefix (`sk-...`), a JSON list (`["key"]`), an exact length, a character
    set, a password policy. Adapt in the launcher, and coalesce two forms of one value into one
    input.
13. **Images that don't use the SDK.** Add a launcher to the thin image: resolve bindings with
    `@alienplatform/sdk` (for example `postgres("db").connection()`), set the env var names the app
    expects, rewrite public URLs from resolved endpoints, then exec the original entrypoint. Keep
    this one module the only code that knows about Alien. The SDK's native module has no musl
    build: on Alpine images, run the launcher with a glibc Node installed alongside.
14. **Hostnames.** Rewrite in-cluster names (`api.ns.svc.cluster.local`, `api.ns`) to the resource
    id. Rewrite only hosts that are Services in the chart, never external hosts. Public URLs come
    from the resolved endpoints at start, not from the chart's domain values.
15. **Non-root images.** Check every path the image writes (`/tmp`, data directories, mounted
    volumes) is writable by its user in the container. A launcher can fix ownership and then drop
    to the image's user.
16. **Permissions.** One profile per service. Grant resource-scoped permissions only to services
    that link that resource. Services sharing a profile but receiving different secrets fail
    validation. Test each grant with a real SDK call from the deployed container, not by the
    resource being created.
17. **Compute.** One ComputeCluster pool with an explicit architecture, CPU, and memory that cover
    the sum of container requests. Check the machine type and disk size Alien picked before the
    first cloud deploy.
18. **Health checks.** Use the app's real readiness path. Measure cold start (some services take
    15 seconds or more) and set `failureThreshold` to match. See `stateful-services.md`.
19. **Verify the built images.** Run each image's launcher against real bindings (`alien dev` or
    a test deployment) and call the product's main action. A smoke test that only starts the
    process hides a missing native module or a wrong env name.
20. **Validate in order.** `alien dev`, then a real login and the product's main action (not only
    "Running"); then a real setup link and the generated setup in a cloud account; then a fresh
    install; then a restart with data persisted; then an upgrade.
21. **Publish.** `docker login` to the vendor registry on the build machine. `alien release`
    pulls each image with those credentials and re-hosts it; customer environments pull from
    Alien's registry with the deployment token and never need the vendor's login. AWS defaults to
    `linux-arm64`: for x86-only images, `alien release --targets linux-x64` and set the pool's
    architecture to match. If the chart is licensed, keep it out of the repository: CI renders
    from a stored copy (a CI secret) and deletes the output when the job ends.

## Mapping

| Chart or compose | `alien.ts` |
|---|---|
| Deployment | `Container` with an image |
| StatefulSet + PVC | `Container` with `.persistentStorage(size, { mountPath })` |
| Service, container ports | `.port(n)`; other services use the resource id as hostname |
| Ingress | `.publicEndpoint(name, port, "http")`; names unique across the stack |
| Probes | `.healthCheck({ path, failureThreshold })` |
| `command`, `args` | `.command([...])`, which replaces the image's entrypoint |
| ConfigMap env | `.environment({...})` |
| ConfigMap file | Thin derived image, or render from env at start |
| Generated Secret | developer secret with `generate` |
| Customer-supplied Secret | deployer secret; written straight to the customer's secret store |
| Bundled Postgres | `alien.Postgres`, or an external binding on Kubernetes and machines |
| Bundled Redis, RabbitMQ, ClickHouse | Stateful `Container`, stock image (`stateful-services.md`) |
| Init Job, compose one-shot | A setup step (`stateful-services.md`) |
| Migration Job | The app's migration command before start |
| CronJob | Periodic task in a service, or Worker schedule trigger |
| Init container, `depends_on` | `.link()` orders the start; retry on startup |
| Sidecar | Fold in or drop, per sidecar |
| ServiceAccount, RBAC | One permission profile per service |
| nodeSelector, sizes | ComputeCluster pool `requirements` |
| `imagePullSecret` | `docker login` before `alien release`; images are re-hosted |

## Known gaps to report, not hide

- No general file mounts, sidecars, or scheduled container runs.
- No musl build of the SDK's native module.
- On AWS, a stack that mixes a Worker with x86-only containers can't build for one architecture.
