# Stateful services and durable execution

Use this when the product depends on a stateful service that isn't its own code: a cache or
broker (Redis, RabbitMQ), an analytics store (ClickHouse), or a durable-execution engine
(Temporal, Restate, Inngest). Docs: `infrastructure`, `infrastructure/container`,
`infrastructure/container/behavior`, `infrastructure/postgres/api`, `reference/environment-variables`.

## Contents

- Choose the home first
- A service as a container
- Setup steps
- Health checks prove readiness
- TLS to managed databases
- Durable execution
- Ports

These services cause most of the failures in a whole-product integration. The service itself
rarely fails. What fails is the glue you write around it: setup steps, TLS settings, passwords,
and a launch script that hides a dead process.

## Choose the home first

1. **A managed resource, if one exists.** Read the resource list at
   `https://alien.dev/docs/infrastructure.md`. A managed database in your customer's cloud beats a
   container you operate. Bundled Postgres becomes `alien.Postgres`.
2. **A hosted service, for a durable-execution engine that supports outbound-only workers.** See
   [Durable execution](#durable-execution).
3. **A container with a volume**, for everything else. The stock image, or a thin image built on
   it that adds only a readiness endpoint (see [Health checks prove readiness](#health-checks-prove-readiness)).

Record the choice and the reason in the decision record. Don't rewrite the product to fit a
different store (for example, Redis lists onto `Kv`) unless the decision record says to.

## A service as a container

```ts title="alien.ts"
import * as alien from "@alienplatform/core"

const config = alien.inputs({
  // Generated once per deployment, given only to the containers that use it.
  clickhousePassword: alien.secret({
    providedBy: "developer",
    required: true,
    label: "ClickHouse password",
    description: "Authenticates the API to the deployment's ClickHouse.",
    generate: { length: 48 },
    env: { name: "CLICKHOUSE_PASSWORD", targetResources: ["clickhouse", "api"] },
  }),
})

// The customer's key encrypts every volume and database in the stack.
const dataKey = new alien.Key("data-key").build()

// Events and metrics. Can't be rebuilt from other stores, so it keeps a volume
// with backups.
const clickhouse = new alien.Container("clickhouse")
  .code({ type: "image", image: "clickhouse/clickhouse-server:26.3" })
  .cpu(1)
  .memory("4Gi")
  .port(8123)
  .replicas(1)
  .persistentStorage("100Gi", {
    mountPath: "/var/lib/clickhouse",
    encryptionKey: dataKey,
    backups: { intervalHours: 6, retentionDays: 14 },
  })
  // Answers only when the server accepts queries.
  .healthCheck({ path: "/ping", failureThreshold: 10 })
  // Needs no cloud access, so its profile is empty.
  .permissions("none")
  .build()

export default new alien.Stack("analytics")
  .platforms(["aws", "gcp", "azure"])
  .inputs(config)
  .add(dataKey, "frozen")
  .add(clickhouse, "live")
  .permissions({ profiles: { none: {} } })
  .build()
```

Rules:

- **Pin the image by version or digest.** A version change is an upgrade of customer data. Ship it
  in a release you have tested with data on the old version.
- **One replica**, unless the service's own clustering is set up and tested. Two replicas of a
  single-node database are two databases.
- **Decide durability per store.** If the data can't be rebuilt, use a volume and the service's
  durable mode (Redis `--appendonly yes`). If it can (a pure cache), say so in a comment and skip
  the volume. Backups are on by default for every volume; set the interval to match how much
  data the product can lose. Restores are per replica (`alien deployments restore-volume`).
- **Passwords are generated inputs** with `targetResources` naming every container that needs
  them. Check the product's own rules for length and characters before choosing `length`.
- **An empty permission profile** for a service that doesn't call cloud APIs. A shared profile
  means a shared cloud identity, and a container that receives customer keys should not share
  one with a database.
- **Environment names can clash.** The image and the product may read the same variable
  (`CLICKHOUSE_PASSWORD`) for different principals. Rename in `.command()`:
  `["sh", "-c", 'CLICKHOUSE_PASSWORD="$SUPERUSER_PASSWORD" exec /entrypoint.sh']`.
- **`.command()` replaces the image's entrypoint.** Start the list with the original entrypoint,
  or setup the entrypoint did (secret files, permissions) silently stops.
- **Volumes have a minimum size on some clouds** (10 GiB on Google Cloud). Size every volume at
  least that.
- **After the first upgrade, read the data back.** A volume that came back empty looks healthy.
  Do the same after a restore and after scaling a stateful container up.
- **Prove a backup by restoring it.** Write a marker, wait until the backup completes, check its
  encryption with the provider's describe call, restore it to a scratch volume, and read the
  marker.

## Setup steps

Compose files and charts run one-shot jobs before the services: create databases and roles,
install extensions, migrate schemas, create principals in ClickHouse, create a Temporal namespace.
There is no Job resource. Pick one home per step:

| Step | Where it runs |
|---|---|
| Schema migrations of one service | That service's command, before the process starts: `["sh", "-c", "migrate && exec serve"]` |
| Several steps in a fixed order (compose's one-shots) | A prefix of one single-replica service's command, in compose order, each idempotent |
| Roles, databases, extensions on `alien.Postgres` | A setup step that links the database, or a command-enabled setup container |
| Steps that belong to one dependency (a Temporal namespace) | That dependency's own launch script |
| First-run steps of the app itself (first admin, provider import, initial sync) | The app's own reconciler, called from the setup step; safe to repeat, and tested on a fresh database |
| Steps other services must wait for, with no backend to call a command | A setup container that runs them, then passes its health check; the services that depend on it link it |

- Make every step idempotent. Use `IF NOT EXISTS`, and treat "already exists" as success only for
  the object you meant to create.
- Serialize steps that two replicas could run at once with a Postgres advisory lock. Poll
  `pg_try_advisory_lock` in a loop; a blocking `pg_advisory_lock` held across
  `CREATE INDEX CONCURRENTLY` deadlocks.
- On managed Postgres the admin user isn't a superuser. To create a database owned by another
  role, grant that role to the admin first (`GRANT app TO CURRENT_USER`), then
  `CREATE DATABASE ... OWNER app`.
- Order services with `.link()`. A container starts after the containers it links are running and
  pass their health checks. That replaces `depends_on` and wait-for init containers, but not
  connection retries: a slow cold start can outlast the wait, so the app still retries.

## Health checks prove readiness

A running process is not a ready service. Every stateful service, and every container whose
launch script starts another process, gets a health check that passes only when the service does
its job:

- Use an endpoint that needs the full stack: ClickHouse `/ping`, a Temporal namespace lookup on
  the HTTP API, the product's own readiness route. The health-check port doesn't need a
  `.port()` declaration.
- Health checks are HTTP. For a service with no HTTP endpoint (Redis, a queue worker), the
  launcher serves a small readiness endpoint that answers 200 only after a real check
  (`redis-cli ping`, the worker connected to its server). If you can't wrap the process, record
  the missing check as an open question.
- Set `failureThreshold` from a measured cold start, including migrations.
- A clustered store run as one node reports degraded health while it works (Elasticsearch
  `yellow`, no replicas). Accept that state in the health check, or it never passes.
- A launch script that starts a server in the background must exit when the server exits.
  Otherwise the container shows as running while nothing serves:

```sh
server-binary &
server=$!
trap 'kill -TERM "$server"' TERM INT
until nc -z -w 2 127.0.0.1 7233; do
  kill -0 "$server" 2>/dev/null || { wait "$server"; exit 1; }
  sleep 2
done
# one-time setup against 127.0.0.1 here
wait "$server"
```

## TLS to managed databases

Managed Postgres in a customer's cloud usually requires TLS. Local Postgres doesn't, so a TLS
mistake shows up only in the cloud.

- Use the binding's TLS material: `sslmode` and `ca_certificates` (Python also has
  `ssl_context()`). Don't vendor a provider CA bundle or fall back to `sslmode=require`.
- Every program that connects needs its own TLS settings, in the names that program reads. Look
  them up in the image's own config template, not in another tool's docs. A migration tool that
  connects with TLS does not prove the server will.
- Before the first cloud release, reproduce the cloud's rule locally: run Postgres with
  `hostssl`-only `pg_hba.conf` and a self-signed certificate, and start each service against it.

## Durable execution

The engine holds workflow state, timers, and retries. Decide where it runs before writing
`alien.ts`, because it decides what leaves your customer's account.

| Option | What it takes | What leaves your customer's account |
|---|---|---|
| Self-hosted in the deployment | The engine as a container (below) | Nothing |
| Hosted by the engine's vendor or by you | Workers connect out; the engine is elsewhere | Workflow metadata, and payloads unless you encrypt them |

Pull-based engines fit a deployment with no inbound access: workers dial out to the engine.
Temporal workers always do. Push-based engines call your service over HTTP, so a hosted one
needs its outbound tunnel or connect mode (Restate Cloud tunnels, Inngest Connect). Check that
mode's maturity for your SDK language before choosing it.

### Hosted engine

- The endpoint, namespace, and API key are inputs. The API key is a secret: `providedBy:
  "developer"` when you host the engine, `"deployer"` when the customer brings their own account.
- Encrypt payloads before they leave: a payload codec (Temporal) that calls `encrypt`/`decrypt`
  on the stack's `alien.Key`. Then the engine stores ciphertext the customer can revoke.
- Search attributes and workflow IDs stay readable. Keep them to opaque IDs.
- Write the outbound host and port into the customer runbook.

### Self-hosted Temporal on `alien.Postgres`

- Give Temporal its own role and two databases (`temporal`, `temporal_visibility`), created by
  the setup step. Its password is a generated input shared by the setup step and the Temporal
  container, so Temporal never needs the database admin's secret.
- Build a thin image from `temporalio/server` with `jq`, `nc`, the dynamic config file, and the
  schema directory copied from the `admin-tools` image. Don't use `auto-setup`: it creates
  databases with rights a managed Postgres admin lacks, and new versions aren't published. The
  Temporal images are Alpine; if you need the SDK launcher, copy the static binaries
  (`temporal-server`, `temporal-sql-tool`) onto a Debian base instead.
- The launch script reads the host and port from the database binding (`ALIEN_DB_BINDING`, JSON
  tagged by `service`; see `reference/environment-variables`). The fields differ by backend:
  Aurora has `clusterEndpoint` and needs TLS, local Postgres has `host` and no TLS. Branch on
  `service` and run the launcher under both. Then:
  1. `temporal-sql-tool --plugin postgres12 --endpoint <host> --port <port> --user temporal
     --database temporal update-schema -d .../postgresql/v12/temporal/versioned`. On a new
     database, run `setup-schema -v 0.0` first. Repeat for `temporal_visibility`.
     With TLS add `--tls`; the password goes in `SQL_PASSWORD`.
  2. Starts the server with `DB=postgres12`, `POSTGRES_SEEDS`, `DB_PORT`, `POSTGRES_USER`,
     `POSTGRES_PWD`, `DBNAME`, `VISIBILITY_DBNAME`, `BIND_ON_IP=0.0.0.0`,
     `DYNAMIC_CONFIG_FILE_PATH`, and for TLS `SQL_TLS_ENABLED=true` plus `SQL_CA`, or
     `SQL_HOST_VERIFICATION=false`. The server ignores `POSTGRES_TLS_*` names. The binding JSON
     has no CA; the CA comes from the SDK's `connection()`, which also reads the admin password
     and so needs the database grant. Choose between verifying the host (SDK plus grant) and
     encrypting without verification (no grant), and record the choice.
  3. Waits for port 7233 while checking the server is alive, creates the namespace against
     `127.0.0.1:7233`, then waits on the server.
- Health check: `GET /api/v1/namespaces/<namespace>` on the HTTP port (7243). It passes only once
  the server runs and the namespace exists. Workers link the Temporal container, so they start
  after it.

Restate runs as one binary with its own storage: a container with a volume, like ClickHouse.

## Ports

Changing a container's ports, public endpoints, cluster, stateful mode, or volume key replaces
it, and on a running deployment the update can be refused. Decide them in the first release. Add
a health-check port without declaring it.
