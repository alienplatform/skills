# Starting from a Helm chart or Kubernetes manifests

Use this when the product installs with a Helm chart, Kustomize overlays, or plain Kubernetes
YAML. It covers how to read the chart and how each object maps. Then follow the steps in
`existing-app.md`. Docs: `guide/existing-app/helm`, `infrastructure/platforms/kubernetes`.

## Choose the path

| The customer wants | Path |
|---|---|
| A managed install in their cloud account or on their machines, updated by you | Convert the chart (this file) |
| To keep running your chart in their own cluster, with you operating it | Remote Operator beside the chart: don't convert, see `standalone-paths.md` |
| Only part of the product near their data | A smaller data plane: go back to `alien-architecture` |

Record the path and the reason in the decision record.

## Render

```bash
helm dependency build ./chart
helm template acme ./chart -f values-customer.yaml --namespace acme > rendered.yaml
kubectl kustomize overlays/production > rendered.yaml    # Kustomize
```

- Use the values file real customers use, not the chart defaults.
- Set the flags that turn on bundled subcharts you will replace (`postgresql.enabled=true`), so
  the rendered env still points at them.
- If the chart is licensed, keep it out of the repository. CI renders from a stored copy (a CI
  secret) and deletes the output when the job ends.
- `helm template` runs no hooks and talks to no cluster. Hook Jobs appear in the output with a
  `helm.sh/hook` annotation; list them in the audit.

## Mapping

| Kubernetes | `alien.ts` |
|---|---|
| Deployment | `Container` with an image |
| StatefulSet with a PVC | `Container` with `.persistentStorage(size, { mountPath })` and `.pool()` (`existing-app.md`, step 15) |
| Service and container ports | `.port(n)`. Other containers reach it at `<id>.svc` |
| Ingress, Gateway route | `.publicEndpoint(name, port, "http")`. Names are unique across the stack. Several Ingress hosts or paths for one product: consider one proxy container with one endpoint, since each endpoint has its own load balancer cost |
| Liveness or readiness probe (HTTP) | `.healthCheck({ path, port, failureThreshold })` |
| Exec or TCP probe | A readiness endpoint in the launcher (`stateful-services.md`) |
| `command` and `args` | `.command([...])`, which replaces the image's entrypoint |
| ConfigMap as env | `.environment({...})` |
| ConfigMap or Secret as a file | Thin image, or rendered from env at start. On Kubernetes targets, an existing Secret can mount with `.kubernetesSecretMount({ secretName, mountPath })` |
| `securityContext` | `.security({ profile: "restricted", runAsUser, runAsGroup, readOnlyRootFilesystem })`; refused under `alien dev` |
| Probes, on Kubernetes targets | `.kubernetesLivenessProbe()` and `.kubernetesReadinessProbe()` as well as `.healthCheck()` |
| Secret the chart generates | Developer secret with `generate` |
| Secret the customer supplies | Deployer secret, written to your customer's own secret store |
| Bundled Postgres subchart or operator | `alien.Postgres`, or an external binding on Kubernetes and machines |
| Bundled Redis, RabbitMQ, ClickHouse | Stateful `Container` with the stock image (`stateful-services.md`) |
| Hook Job, init Job | A setup step (`stateful-services.md`) |
| Migration Job | The service's migration command before it starts |
| CronJob | A periodic task in a service, or a Worker with a schedule trigger |
| Init container that waits | `.link()` on the container it waits for |
| Init container that does work | The launcher, or a setup step |
| Sidecar | Fold into the main process, or drop |
| HorizontalPodAutoscaler | `.autoScale({ min, desired, max, targetCpuPercent })` |
| `resources.requests` | `.cpu()` and `.memory()` |
| nodeSelector, tolerations, instance sizes | ComputeCluster pool `requirements` |
| ServiceAccount, IRSA or Workload Identity | One permission profile per service |
| Role or ClusterRole rules for the Kubernetes API | Not in `alien.ts`: set them in the Helm setup package settings (`infrastructure/platforms/setup-packages`), and diff them against the old chart's |
| `imagePullSecrets` | `docker login` before `alien release`; images are re-hosted |
| `emptyDir` | `.ephemeralStorage(size)` |

Drop these and record each in the audit: NetworkPolicy (the stack's network is private by
default), PodDisruptionBudget, ServiceMonitor and PodMonitor, PriorityClass, namespace objects.

## Details that break first

- **Ingress annotations.** Body size limits, timeouts, and sticky sessions live in annotations.
  Check each against the public endpoint limits in `guide/networking` and record any the
  endpoint can't match.
- **Downward API values** (`POD_NAME`, `POD_IP`). Use the variables in
  `reference/environment-variables`. Record any the product needs that Alien doesn't set.
- **`fsGroup` and `runAsUser`.** The pod set file ownership for the image's user. Without it, a
  volume can be owned by root. Fix ownership in the launcher (`existing-app.md`, step 13).
- **Operators and CRDs.** A custom resource that asks an operator for a database or a queue maps
  to the resource the operator would create, not to the operator.
- **Several releases of one chart** (one per tenant). One Alien deployment per customer replaces
  them; don't model tenants inside one stack.

Now follow `existing-app.md` from step 2.
