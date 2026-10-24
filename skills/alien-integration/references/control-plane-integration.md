# Vendor control-plane integration

Your product's backend talks to Alien. Alien does not host your control plane. Docs:
`https://alien.dev/docs/integrate.md`, `integrate/setup-links.md`,
`integrate/deployment-status.md`, `integrate/sizes-and-networks.md`,
`integrate/remove-a-deployment.md`, `integrate/white-label.md`,
`reference/sdk/platform-api.md`, and the REST reference under `reference/api`.

## Choose how customers install

1. **Hosted setup portal (default).** Your backend creates a setup link and your settings page
   shows or opens it. The portal is white-labeled with your project's name.
2. **Your own settings page on the API.** Same setup link, plus your own status UI, sizes, and
   launch button.

The workspace API key stays on your backend. The setup link's token is the only credential the
customer's browser sees. Do not promise an embeddable portal.

## Backend code

Type-checked against `@alienplatform/platform-api` 3.3.41.

```ts title="server/alien.ts"
import { Alien } from "@alienplatform/platform-api"

const alien = new Alien({ apiKey: process.env.ALIEN_API_KEY!, workspace: "acme" })

// Call on click (not on render). Same externalId reuses the customer's group.
export async function createSetupLink(customer: { id: string; slug: string }) {
  const link = await alien.setupLinks.create({
    project: "docproc",
    externalId: customer.id,
    name: customer.slug,
    maxDeployments: 1,
    expiresAt: new Date(Date.now() + 7 * 24 * 3600 * 1000),
    setupItems: [{ item: "deployment", required: true }],
    deploymentSetupConfig: {
      policy: {
        allowedPlatforms: ["aws"],
        allowedSetupMethods: ["cloudformation", "terraform"],
      },
    },
  })
  return { deploymentGroupId: link.deploymentGroup.id, url: link.deploymentLink }
}

// Poll from your backend every 10-15 s while waiting; back off on errors.
export async function setupState(deploymentGroupId: string) {
  const { items } = await alien.deployments.list({ project: "docproc", deploymentGroup: deploymentGroupId })
  const live = items.find((d) => !["delete-pending", "deleting", "deleted"].includes(d.status))
  if (!live) return { state: "awaiting-setup" as const }

  const d = await alien.deployments.get({ id: live.id })
  if (d.status === "running") {
    const info = await alien.deployments.getInfo({ id: d.id }) // endpoints
    return { state: "running" as const, deploymentId: d.id, info }
  }
  if (["teardown-required", "teardown-failed"].includes(d.status)) return { state: "customer-must-delete-stack" as const }
  if (d.status.endsWith("-failed") || d.status === "error") return { state: "failed" as const, error: d.error }
  return { state: "provisioning" as const }
}

export async function removeDeployment(id: string, status: string) {
  // cleanup -> teardown-required -> customer deletes the stack -> deleted.
  // Keep the setup link alive until then: the stack's delete uses its token.
  await alien.deployments.delete(id, { action: status === "pending" ? "forget" : "cleanup" })
}
```

## Rules

- **`externalId` is your customer or org ID.** It joins setup links, deployment groups, gateways,
  and remote bindings without a mapping table.
- **Create links on click**, store the returned link, and expire them (`expiresAt`).
- **Restrict methods and platforms** with `deploymentSetupConfig.policy.allowedPlatforms` and
  `allowedSetupMethods` (`cloudformation`, `terraform`, `helm`, `google-oauth`, `cli`, `manual`).
  There is no "recommended method" API.
- **Default sizes and network** go in `policy.stackSettings.defaults` (`compute`, `network`). Show
  cost as your own estimate ("Approx. $X/month in cloud costs"); Alien has no cost API.
- **A deployment appears when setup registers**, not when the link is created. A stack that fails
  in the customer's cloud before registering is invisible to Alien. After a long wait with no
  deployment, tell the user the setup may have failed on their side.
- **Two similar names.** `alien.deployments.getInfo({ id })` is `GET /v1/deployments/{id}/info`
  (endpoints for a deployment). `alien.deployment.getInfo()` (singular) is the setup-token install
  context.
- **Do not parse `stackState`.** Use deployment `status`, `error`, `lastHeartbeatAt`, and
  `/info`. Per-resource internal state is not a contract.
- **Running is not usable.** After `running`, call the endpoint or a command from your control
  plane with a product-specific check. Activation ("Finish setup") is your product's own state.
- **Day two:** retry with `alien.deployments.retry({ id })`; resize with
  `alien.deployments.updateCompute(id, { compute })` and follow the returned operation.
- **Deletion:** `cleanup` moves the deployment to `teardown-required`; the customer deletes the
  setup stack, then it becomes `deleted`. Use `forget` for a deployment that never installed. Do
  not revoke the setup link until deletion finishes.
- **Notifications:** poll, read events, or use the Slack integration. There are no deployment
  webhooks.

## Map statuses to product states

| Alien status | Product state |
|---|---|
| no deployment yet | Waiting for the customer's setup |
| `pending`, `initial-setup`, provisioning statuses | Provisioning |
| `running` | Ready to verify (then your own activation) |
| `*-failed`, `error` | Failed: show `error.message`, offer retry |
| `delete-pending`, `deleting`, `delete-failed` | Removing |
| `teardown-required`, `teardown-failed` | Waiting for the customer to delete the setup stack |

Write status copy for the person who runs setup. It may be the customer's admin or your own team.
