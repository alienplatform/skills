# Existing apps: Helm charts, compose files, and container images

Use this when the repository already ships the product as container images with a Helm chart or
a `docker-compose.yml`, and the decision record says the whole product (or most of it) installs
in the customer's environment. Docs: `build/existing-app`, `container`, `build/inputs-and-secrets`,
`deploy/kubernetes`.

A chart uses Kubernetes mechanisms with no one-to-one Alien resource (Jobs, CronJobs, init
containers, sidecars, mounted ConfigMaps, generated Secrets). A first reading of the resource
list makes the product look unsupported. It almost never is: most of those mechanisms exist only
because Kubernetes needs them. Keep the product's behavior and move each mechanism's work to the
place below. Add a workaround only when no existing capability fits, and report it as a gap.

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
   `docker compose config`. Inventory every Deployment, StatefulSet, Service, Ingress, ConfigMap,
   Secret, PVC, Job, CronJob, init container, sidecar, ServiceAccount and RBAC rule, and every
   image.
2. **Check every image.** `docker pull` each one with the vendor's credentials. Record OS, libc
   (glibc or musl), architecture, entrypoint, and user ID. Show the inventory and the mapping to
   the user before writing `alien.ts`.
3. **One named, commented `alien.Container` per service.** `.code({ type: "image", image })`,
   `.port()`, `.cpu()`, `.memory()`, `.replicas()`. Never generate workloads from a list.
4. **Map the rest** with the table below.
5. **Replace bundled databases** with `alien.Postgres` (frozen), or an external binding on
   Kubernetes and machines. Keep protocol-specific services (Redis, RabbitMQ, Kafka) as stateful
   Containers with the stock image unless the app can change.
6. **Move Jobs into app-owned initialization.**
   - Database, role, and extension setup: a Container with `.commandsEnabled(true)` that links the
     database and runs idempotent SQL under a lock when your backend or the runbook invokes it.
   - Schema migrations: the app's own migration command, run before the process starts.
   - CronJobs: a periodic task inside an existing service, or a Worker with a schedule trigger if
     the app can take one. On AWS, Workers build for Arm64 only; in an x86-only app, don't add a
     Worker.
   - Don't build a Job framework.
7. **Config files.** Bake non-secret files into a thin image (`FROM vendor-image`, `COPY`), built
   with `{ type: "source", toolchain: { type: "docker" } }`. Render secret-bearing files from env at
   start with a real serializer. Never bake a secret into an image layer.
8. **Sidecars.** Find out why each exists. Fold health sidecars into the main process's readiness
   endpoint; drop optional ones and say so in the report.
9. **Inputs.** Customer choices and credentials are `providedBy: "deployer"`, as few as possible.
   Passwords and keys the chart generates become `providedBy: "developer"` secrets with
   `generate: { length }`. Never turn the chart's secret list into a customer form.
10. **Images that don't use the SDK.** Add a launcher to the thin image: resolve bindings with
    `@alienplatform/sdk` (for example `postgres("db").connection()`), set the env var names the app
    expects, rewrite public URLs from resolved endpoints, then exec the original entrypoint. The
    SDK's native module has no musl build: on Alpine images, run the launcher with a glibc Node
    installed alongside.
11. **Permissions.** One profile per service. Grant resource-scoped permissions only to services
    that link that resource. Services sharing a profile but receiving different secrets fail
    validation.
12. **Compute.** One ComputeCluster pool with an explicit architecture and enough memory for the
    sum of container limits. Check machine type and disk size before the first cloud deploy.
13. **Health checks.** Use the app's real readiness path. Measure warm-up and set
    `failureThreshold` to match.
14. **Validate in order.** `alien dev`, then a real login and the product's main action (not just
    "Running"); then a real setup link and the generated setup in a cloud account; then a fresh
    install; then a restart with data persisted; then an upgrade.
15. **Publish.** `docker login` to the vendor registry on the build machine. `alien release`
    pulls each image with those credentials and re-hosts it; customer environments pull from
    Alien's registry with the deployment token and never need the vendor's login. AWS defaults to
    `linux-arm64`: for x86-only images, `alien release --targets linux-x64` and set the pool's
    architecture to match.

## Mapping

| Chart or compose | `alien.ts` |
|---|---|
| Deployment | `Container` with an image |
| StatefulSet + PVC | `Container` with `.persistentStorage(size, { mountPath })` |
| Service, container ports | `.port(n)`; other services use the resource id as hostname |
| Ingress | `.publicEndpoint(name, port, "http")`; names unique across the stack |
| Probes | `.healthCheck({ path, failureThreshold })` |
| `command`, `args` | `.command([...])` |
| ConfigMap env | `.environment({...})` |
| ConfigMap file | Thin derived image, or render from env at start |
| Generated Secret | developer secret with `generate` |
| Customer-supplied Secret | deployer secret; written straight to the customer's secret store |
| Bundled Postgres | `alien.Postgres`, or an external binding on Kubernetes and machines |
| Bundled Redis, RabbitMQ | Stateful `Container`, stock image |
| Init Job | Command-enabled setup `Container` |
| Migration Job | The app's migration command before start |
| CronJob | Periodic task in a service, or Worker schedule trigger |
| Init container | Retry on startup; `.link()` for the dependency |
| Sidecar | Fold in or drop, per sidecar |
| ServiceAccount, RBAC | One permission profile per service |
| nodeSelector, sizes | ComputeCluster pool `requirements` |
| `imagePullSecret` | `docker login` before `alien release`; images are re-hosted |

## Known gaps to report, not hide

- No general file mounts, sidecars, or scheduled container runs.
- No musl build of the SDK's native module.
- On AWS, a stack that mixes a Worker with x86-only containers can't build for one architecture.
