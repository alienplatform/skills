# Move existing customers into a deployment

Use this when customers already use your hosted product and some of them will move to a
deployment: their own cloud account, or a dedicated deployment in yours. Load it after the
deployment runs end to end with a new test customer.

## One artifact, many placements

- The hosted product and every customer deployment run the same `alien.ts` and the same images.
  A dedicated deployment in your cloud and one in the customer's account differ by inputs and
  setup, not by code. Avoid `if customer-hosted` branches in the product.
- Keep a placement table in your control plane: customer → deployment, with a generation number
  that increases on every move. Routing, tokens, and the deployment itself read it.
- A deployment refuses requests for customers that aren't placed in it, on every request. A token
  issued before a move must stop working at the old deployment.
- Changing DNS is not a move. Moves happen through the placement table.

## Choose how existing data moves

| Situation | Approach |
|---|---|
| Your current production becomes the shared deployment | Cut over in place: no data moves, only control-plane records |
| A few customers move to their own deployment | Move one customer at a time with an export bundle |
| Everyone moves at once | A bulk move in a maintenance window, rehearsed on a copy |

## Moving one customer

1. **Fence.** Stop the customer's background work at the source and record exactly what was
   running, so the target can restart the same set.
2. **Export** a bundle next to the source: database rows, events, and objects. Use a data-only
   format with a schema version, never a serialized object format such as pickle.
3. **Transfer** through a private bucket with a short expiry and a signed URL. The target
   downloads it itself.
4. **Import** at the target. Imported work stays dormant: an import must not start jobs or
   re-run old prompts.
5. **Verify** at the target before switching: row counts, event totals, object counts, and one
   real resumed session (a conversation that continues with its tools and history, not only its
   visible messages).
6. **Switch** the placement to the target with a new generation.
7. **Restart** exactly the work recorded in step 1.

Make the move tool resumable at every step. Test rollback before the first real move: after
rolling back, the old deployment serves the customer again and the target refuses them.

## Rehearse

Rehearse with production-like data, locally and then in a cloud account. Rehearsals find what
unit tests miss: identity columns, ordering between objects and rows, records with no source data,
and signed URLs for the wrong region. Measure downtime per customer and tell the customer the
number.

## Schema changes during the rollout

- Wire and stored fields are additive with defaults. Send a new field only after every receiver
  accepts it. Remove a field in steps: stop reading, stop sending, confirm no deployment uses it,
  then delete.
- Before real customer data exists, recreate test deployments instead of adding compatibility
  code for them.
