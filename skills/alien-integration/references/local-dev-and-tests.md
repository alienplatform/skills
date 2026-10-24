# Local development and tests

Docs: `https://alien.dev/docs/build/local-development.md`, `build/testing.md`,
`reference/sdk/testing.md`.

## `alien dev`

```bash
alien dev
```

- Requires Docker running.
- Starts a local manager, builds, creates a local release, and deploys once. It does **not**
  watch files. Stop it (`Ctrl+C`) and start it again to pick up code changes.
- The first deployment is `default` in the local group `local-dev`: address it as
  `local-dev/default`.
- Storage is a local directory; other resources run locally.

In a second terminal:

```bash
# Call a command
alien dev commands invoke --deployment local-dev/default \
  --command process-document --params '{"path": "a.txt"}'

# A second local customer, with developer inputs
alien dev deploy --name customer-2 --platform local --input controlPlaneUrl=http://localhost:3000

# A deployer secret, as the customer's admin would set it
alien dev vault set <vault> <SECRET_NAME> --stdin
```

Each local deployment gets its own resources, so `local-dev/customer-2` cannot read
`local-dev/default`'s files. Use that to check tenant isolation.

Inputs on an existing local deployment are fixed when it is created. To change them, destroy it
and create it again with new `--input` values.

## Tests with `@alienplatform/testing`

`deploy()` runs the app under `alien dev` by default (`platform: "local"`) and returns a
`Deployment` you can call. With `platform: "aws" | "gcp" | "azure"` it deploys through the
platform API and needs `ALIEN_API_KEY` (an approval gate).

```ts title="test/dataplane.test.ts"
import { deploy, type Deployment } from "@alienplatform/testing"
import { afterAll, beforeAll, expect, test } from "vitest"

let deployment: Deployment

beforeAll(async () => {
  deployment = await deploy({
    app: ".",
    environmentVariables: [{ name: "CONTROL_PLANE_URL", value: "http://localhost:9999" }],
  })
}, 300_000)

afterAll(async () => {
  await deployment?.destroy()
})

test("processes a document and returns counts, not content", async () => {
  await deployment.invokeCommand("ingest-text", { path: "a.txt", text: "three short words" })

  const result = await deployment.invokeCommand("process-document", { path: "a.txt" })
  expect(result).toEqual({ status: "done", words: 3 }) // nothing else crosses

  const status = await deployment.invokeCommand("job-status", { path: "a.txt" })
  expect(status).toEqual({ status: "done", words: 3 })
})
```

`Deployment` also has `url` (when a resource exposes one), `setExternalSecret(vault, key, value)`
for deployer secrets, and `upgrade()` for a new release on cloud deployments.

## What to test

Tests must prove behavior, not configuration. Good tests:

- The product's real flow through commands or the endpoint, asserting the result data.
- That results crossing to the control plane contain only the agreed fields (exact `toEqual`).
- Tenant isolation: two deployments, data written to one is not visible in the other.
- Fail closed: with the data plane stopped, the control plane's call returns an error and does
  not fall back.
- Missing deployer secret: the workload waits instead of starting with an empty value.

Do not write tests that only check `alien.ts` contains a string or that a generated template has a
key. They catch nothing.
