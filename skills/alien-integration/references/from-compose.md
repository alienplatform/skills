# Starting from a Compose file

Use this when the product installs with `docker-compose.yml` or `compose.yaml`, often for
self-hosted or on-prem customers. It covers how to read the file and how each key maps. Then
follow the steps in `existing-app.md`. Docs: `guide/existing-app/compose`, `infrastructure/container`.

## Render

```bash
docker compose --env-file .env.production --profile production config > rendered.yaml
```

- `config` resolves `extends`, anchors (`x-*`), variable interpolation, and profiles. Read the
  output, not the source file.
- Use the env file and profiles real installs use. Services outside every active profile are
  usually dev tools; list them in the audit as dropped.
- The `.env` file often holds plaintext passwords. They become generated inputs. Never copy a
  value into `alien.ts`, the plan, or the repository.

## Mapping

| Compose | `alien.ts` |
|---|---|
| Service with `image` | `Container` with `.code({ type: "image", image })` |
| Service with `build` | `.code({ type: "source", src, toolchain: { type: "docker", dockerfile } })` |
| `command`, `entrypoint` | `.command([...])`: the entrypoint first, then the command |
| `environment`, `env_file` | `.environment({...})` for plain values; inputs for secrets |
| `ports`, `expose` | `.port(containerPort)`. The host port has no meaning |
| A port that users open in a browser | `.publicEndpoint(name, port, "http")` |
| Named volume | `.persistentStorage(size, { mountPath })` |
| Bind mount of a config file | Thin image, or rendered from env at start |
| `healthcheck` | `.healthCheck({ path, port, failureThreshold })`; a `CMD` test needs a readiness endpoint (`stateful-services.md`) |
| `depends_on` with `service_started` or `service_healthy` | `.link()` on that container |
| `depends_on` with `service_completed_successfully` | The dependency is a setup step (`stateful-services.md`) |
| A one-shot service (`restart: "no"`, exits when done) | A setup step |
| `deploy.replicas` | `.replicas(n)` |
| `deploy.resources` | `.cpu()` and `.memory()`; Compose often sets none, so measure |
| `secrets` (files in `/run/secrets`, read through `*_FILE` variables) | An input; the launcher writes it to a private tmpfs file readable by the image's user, then sets `*_FILE` |
| `configs` | Thin image, or rendered from env at start |
| `user`, `read_only` | `.security({ profile: "restricted", runAsUser, runAsGroup, readOnlyRootFilesystem })`; refused under `alien dev`, so set it only for cloud targets |
| `security_opt` (seccomp), `cap_add`, `pids_limit`, sized `tmpfs` | No field: a gap, or move the untrusted part into a `Sandbox` (`existing-app.md`, known gaps) |
| `networks`, `restart`, `container_name`, `logging` | Drop: the stack network is private, and Alien restarts and logs containers. An `internal: true` network behind an egress proxy is a security control: `.egress("internet")` or a gap, never silently dropped |

## Details that break first

- **No resource limits.** Compose files rarely set CPU and memory, and `.cpu()` and `.memory()`
  are required. Measure each service under the product's main action (`docker stats`) and add
  headroom.
- **Service order is only a hint.** Compose starts one-shots and servers in an order the file
  doesn't fully state. Write the order down, then make each setup step idempotent.
- **Host access.** `network_mode: host`, `privileged`, `cap_add`, `devices`, and bind mounts of
  host paths (`/var/run/docker.sock`, `/dev`) need host access a Container doesn't have. Use a
  Daemon on a ComputeCluster or on Machines (`patterns.md`, host daemons), or report the gap.
- **Images that aren't published.** A `build` context that only the vendor can build needs a
  CI step that builds and pushes it, or the Docker toolchain in `alien.ts`.
- **Tags that don't exist.** A pinned tag that fails to `docker pull` usually means the pin is
  wrong. Check the registry before you assume a private image.
- **No vendor backend.** Compose installs often have no control plane of yours behind them. Skip
  the phases about reaching the deployment and the vendor control plane unless the decision
  record adds them, and create deployments with the CLI.

Now follow `existing-app.md` from step 2.
