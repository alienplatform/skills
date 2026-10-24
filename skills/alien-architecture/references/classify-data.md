# Classify the data

Run this when the user cares about sensitive data (Q1 = A). Moving everything is expensive, so the
line between what stays in the control plane and what moves to the data plane is drawn per field,
not per service. You fill the worksheet from the code; the user decides the judgment calls; the
buyer's security review has the final say.

## Steps

1. **Find every place data lives or travels.** From the code: database tables and columns, object
   storage keys, caches and search indexes, API request and response bodies, events, webhooks and
   WebSockets, queue and workflow payloads (including retries and history), logs, error reports
   and traces, analytics events, URLs and query strings, emails and notifications, and model
   training or evaluation data.
2. **Group the fields into the classes below.** Most fields need no discussion.
3. **Settle the judgment calls with the user.** Ask only about fields the product actually has, a
   few at a time, multiple choice: keep in your cloud / keep in theirs / don't send it at all /
   Other.
4. **Test every field that stays in your cloud:**
   - *Breach:* if this table leaked, would the customer's security team call it a breach of their
     data?
   - *Reconstruction:* could someone recover or guess the content from it?
   - *Need:* do sign-in, billing, authorization, scheduling, or operating the deployment need it?
     If not, don't send it, even when it's allowed.
5. **Trace every path that crosses** and pick a fix for each one that would carry content.
6. **Write it down** in the decision record: field, class, plane, reason. Open questions go to the
   buyer. "For this phase" is a valid answer when it's written down.

Say "customer data" or "content", not "PII". In a database product, the rows are the content.

## Classes

| Class | What it is | Typical fields | Plane |
|---|---|---|---|
| Content | What the product exists to store or process | Message bodies, documents, files, code, records, prompts, attachments | Data plane |
| Derived | Anything computed from content | Model outputs, summaries, reports, search indexes, embeddings, caches, extracted text | Data plane |
| Describing text | Short text that reveals content | Subjects, titles, previews, filenames, headers, URLs, query text, custom instructions, error messages with excerpts | Data plane by default |
| Credentials | Grants access to the customer's systems | OAuth tokens, database passwords, API keys, signed URLs | Data plane, or the customer's own secret store |
| Account metadata | Sign-in, billing, authorization | Organizations, users, roles, plans, API key scopes, settings without content | Control plane |
| Operational metadata | Running and billing the product | Random IDs, opaque references, timestamps, status, counts, sizes, durations, token counts, region, version, health, error categories | Control plane |

## Judgment calls

Always decide these with the user. Don't pick silently.

| Field type | Why it's hard | Default |
|---|---|---|
| Email addresses, participant names | Needed for routing and limits, but often personal data | Ask. Either answer is valid if it's written down. |
| Filenames, document titles, repository names | They look like labels but describe content | Data plane |
| Query text | Can reveal what the customer is working on | Data plane when it touches customer data |
| Hashes of sensitive values | Useful for lookups; a hash of a low-entropy value can be reversed by guessing | Equality lookups only, and only if the buyer agrees. Never where users need the raw value. |
| Aggregates | Small groups can identify people | Usually control plane; ask when groups are small |
| Schedules and activity timing | Information about the customer | Usually control plane |
| Logs and error reports | Free text can carry content | Send categories and IDs; keep messages in the data plane, or redact |
| Training and evaluation data | Needed to improve the product | Compute metrics in the data plane and send numbers, or consented samples deleted after use |

## Paths that leak, and the fix

| Path | Fix |
|---|---|
| The UI shows content | The browser calls the data plane directly with a short-lived token from your backend |
| Uploads | A signed URL to the data plane's storage |
| Events, webhooks, realtime | Thin events with IDs. The consumer fetches from the data plane, or the data plane delivers the payload itself. |
| A background job needs content | Run it in the data plane; the control plane schedules it by ID |
| A workflow engine in the control plane | Only if arguments, results, retries, and history carry IDs |
| Search or analytics over content | Index and query in the data plane; send counts |
| Support and debugging | Time-boxed, approved access through Remote Operator |
| The data plane is down | Fail closed. Never fall back to processing in your cloud. |

## Worksheet

Copy this into the decision record and fill it.

| Field or path | Where in the code | Class | Plane | Crosses as | Reason or open question |
|---|---|---|---|---|---|
| `messages.body` | `src/models/message.ts` | Content | Data plane | never | |
| `messages.subject` | same | Describing text | Data plane | never | |
| `messages.sender` | same | Judgment call | Control plane for now | metadata callback | Buyer to confirm |
| `messages.id`, `created_at`, `size` | same | Operational | Control plane | metadata callback | |
| `message.received` webhook | `src/webhooks.ts` | Path | | IDs only | Consumer fetches from the data plane |
| Send worker error logs | `src/send.ts` | Path | | category only | Provider errors can echo content |
