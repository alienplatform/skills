# Writing `alien.ts`

`alien.ts` declares what each customer environment gets. Read these first:
`https://alien.dev/docs/build/stacks.md`, `build/compute.md`, `build/resources.md`,
`build/frozen-and-live.md`, `build/inputs-and-secrets.md`, `build/permissions.md`, and
`reference/resources/<type>.md` for each resource.

## Example

A document-processing data plane: customer documents and job state stay in the customer's
account, and the control plane calls the processor with commands. Type-checked against
`@alienplatform/core` 3.3.41.

```ts title="alien.ts"
import * as alien from "@alienplatform/core"

// Inputs. Developer inputs are set by you when you create a deployment.
// Deployer inputs are asked of the customer's admin at setup.
const config = alien.inputs({
  // Where the deployment reports usage and status (metadata only).
  acmeApiUrl: alien.string({
    providedBy: "developer",
    required: true,
    label: "Acme API URL",
    description: "Where this deployment reports usage and status.",
    env: "ACME_API_URL",
  }),
  // Public key that verifies short-lived tokens your control plane issues
  // to browsers. The private key never leaves your cloud.
  tokenPublicKey: alien.string({
    providedBy: "developer",
    required: true,
    label: "Token public key",
    description: "Verifies browser tokens signed by your control plane.",
    env: "TOKEN_PUBLIC_KEY",
  }),
  // An internal secret nobody needs to type. Alien generates it once
  // per deployment and keeps it across updates.
  internalSigningKey: alien.secret({
    providedBy: "developer",
    required: true,
    label: "Internal signing key",
    description: "Signs upload URLs between data plane components.",
    generate: { length: 48 },
    env: "INTERNAL_SIGNING_KEY",
  }),
  // A real choice the customer's admin makes at setup.
  retentionDays: alien.integer({
    providedBy: "deployer",
    required: false,
    default: 30,
    min: 1,
    max: 3650,
    label: "Retention (days)",
    description: "How long processed documents are kept.",
    env: "RETENTION_DAYS",
  }),
})

// Customer documents. Frozen: the customer's admin creates the bucket at
// setup, and the management identity can't change or delete it.
const documents = new alien.Storage("documents").build()

// Processing state, derived from customer data, so it lives here too.
const jobs = new alien.Kv("jobs").build()

// The code that touches the documents. Live: Alien updates it on every
// release, so it needs the permissions to do that.
const processor = new alien.Worker("processor")
  .code({ type: "source", src: "./", toolchain: { type: "typescript" } })
  .commandsEnabled(true)
  .link(documents)
  .link(jobs)
  .permissions("processor")
  .build()

export default new alien.Stack("docproc")
  .platforms(["aws", "gcp", "azure"])
  .inputs(config)
  .add(documents, "frozen")
  .add(jobs, "frozen")
  .add(processor, "live")
  .permissions({
    profiles: {
      // Name every linked resource; avoid "*" in production stacks.
      processor: {
        documents: ["storage/data-read", "storage/data-write"],
        jobs: ["kv/data-read", "kv/data-write"],
      },
    },
  })
  .build()
```

The workload code registers commands and uses the linked resources by name:

```ts title="src/index.ts"
import { command, kv, storage } from "@alienplatform/sdk"
import { z } from "zod"

// Called by your control plane. Returns counts and status, never content.
command("process-document", z.object({ path: z.string() }), async ({ path }) => {
  const object = await storage("documents").get(path)
  const words = new TextDecoder().decode(object.data).split(/\s+/).length
  await kv("jobs").setJson(path, { status: "done", words })
  return { status: "done", words }
})

command("job-status", z.object({ path: z.string() }), async ({ path }) => {
  const entry = await kv("jobs").getJson<{ status: string; words: number }>(path)
  return entry?.value ?? { status: "unknown" }
})
```

## Readability rules

Reviewers read `alien.ts` to understand what lands in a customer's account. Write it for them.

- One named `const` per resource. A comment on each says what it holds and why it is frozen or
  live.
- No generic loops or factories that build workloads from arrays. Repetition is fine; clarity
  wins.
- Blank lines between resources. Inputs at the top, resources in dependency order, stack last.
- Resource IDs are stable names (`documents`, `jobs`, `processor`). Changing an ID is a new
  resource.

## Frozen or live

Chosen per resource by you, not by resource type. Lead with permissions:

| | Frozen | Live |
|---|---|---|
| Created by | The customer's admin, at setup, with their credentials | Alien, with the management identity |
| Changed by | Only a setup rerun by the admin | Every release, automatically |
| Management permissions | Fewer: Alien cannot modify or delete it | More: Alien creates, updates, deletes it |
| Typical | Buckets, databases, keys, KV stores the customer wants to own | Workers, containers, daemons |

Live resources are updated in place, not recreated on every release. Frozen does not mean "the
data persists"; it means who may change the resource and when. A release that adds, removes, or
changes a frozen resource, or changes permissions, is held until the admin reruns setup. Plan
frozen resources up front.

## Inputs

- `providedBy: "developer"`: you set it per deployment (your API URL, public keys, plan
  limits). Pass with `alien onboard <name> --input id=value` or through the API.
- `providedBy: "deployer"`: the customer's admin sets it at setup. Keep these few and real.
- `alien.secret({ providedBy: "deployer" })`: the admin writes it into their own secret store;
  Alien never sees it. Workloads wait (`WaitingForSecrets`) until it is present.
- `generate: { length: 16..256 }` on a developer secret: generated once per deployment and kept
  across updates. Use for internal passwords and signing keys.
- `platforms: [...]` scopes an input to some platforms.
- Never use inputs for credentials of resources the stack creates. `.link()` provides them.

## Compute choice

| Need | Use |
|---|---|
| Commands, request/response, event triggers | `Worker` (Lambda, Cloud Run, Container Apps) |
| Long-running service, fixed ports, streaming, GPUs, vendor images | `Container` |
| One process per host, host access, nested virtualization | `Daemon` on a `ComputeCluster` or Machines |

On GCP and Azure a `Worker` listens on port 8080. AWS Workers build for arm64 by default; ship a
`Container` for amd64-only images. Declared ports are effectively immutable: choose them once.

## Permissions

- One profile per workload, granting named resources only.
- Common permission sets: `storage/data-read`, `storage/data-write`, `kv/data-read`,
  `kv/data-write`, `queue/data-read`, `queue/data-write`. Check `reference/permissions` for the
  full list and what each grants.
- `"*"` grants to every linked resource. Acceptable in a quickstart, not in a customer stack.

## Before moving on

Run `npx tsc --noEmit` on `alien.ts` and the workload code. Then run `alien dev`.
