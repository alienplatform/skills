# Questions to ask before proposing anything

Ask once, in one batch of three to five questions. Every question is multiple choice and ends with
**Other**. Use the host's structured question tool when there is one (for example
`AskUserQuestion`); otherwise send a numbered list the user can answer with letters.

## Before asking

- Read the conversation and the repository first (README, deploy files, data models, Helm charts,
  Terraform). Never ask what they already answer.
- Pre-select the likely answer when the evidence points to one, and say why in one short clause.
- Ask Q1 and Q2 always. Ask Q3 and Q4 only when Q1 includes sensitive data. Ask Q5 instead of Q3
  and Q4 when Q1 is only "updates and operations", or includes "everything".
- Ask Q6 only when the answers point to a data plane with sensitive data or the whole product,
  and the repository doesn't already show how much the team can change. Never ask more than five.
- After the answers, restate them in two lines ("You need X and Y; Z doesn't apply.") before the
  inventory.

## Q1. Why does part of your product need to run outside your cloud?

Multi-select. Always ask.

- A. **Sensitive data**: the customer won't let some of their data reach your cloud.
- B. **Private networks**: you need to reach something only reachable inside their network, such
  as a database, a cluster API, or internal services.
- C. **Local resources**: you need what exists only on specific machines, such as files and
  processes on a laptop, devices, local disks, or special hardware.
- D. **Latency**: their app calls you on its hot path and needs fast answers, or answers while your
  service is down.
- E. **None of these.** You already ship it (Helm chart, Terraform, installer) and need updates,
  monitoring, and debugging across installs.
- F. **The customer requires everything in their environment** (on-prem, air-gapped, or "no vendor
  connection").
- Other

Pre-select E when the repo has a Helm chart or installer and the request is about upgrades or
support. Pre-select B when the code has connectors to customer systems or allowlisted IPs.

## Q2. Where will it run?

Multi-select. Always ask.

- A. A dedicated deployment per customer in **your** cloud (single-tenant)
- B. The customer's **AWS, Google Cloud, or Azure account**
- C. The customer's existing **Kubernetes cluster**
- D. The customer's **Linux servers, devices, or employee laptops**
- E. Not decided. Plan for the most likely and keep the others possible.
- Other

This decides push or pull, which resources are frozen, and which compute fits.

## Q3. What may leave the customer's environment?

Single-select. Only when Q1 includes A.

- A. **Metadata may leave, content may not.** IDs, counts, status, timing, billing, and logs without
  content can reach your cloud. (Most common.)
- B. **Content and logs stay.** Like A, but logs, errors, and telemetry stay too, or are filtered
  before they leave.
- C. **Stored in their account, processed by you.** Files rest in their account; your hosted
  backend may read them.
- D. **Their key, your cloud.** Data can stay in your cloud if they hold a key they can revoke.
- E. **Only model calls.** Prompts must go through their own model account or agreement.
- F. **Nothing leaves, and no outbound connection** (air-gapped).
- Other, or not known yet. Then propose candidates for A and B, and list the questions for the
  buyer's security review.

## Q4. Which kinds of data are sensitive?

Multi-select. Only when Q1 includes A. This is the first pass of the worksheet in
`classify-data.md`.

- A. **Content** users create, upload, or receive: messages, documents, files, code, records,
  prompts
- B. **Outputs and derived data**: model answers, summaries, reports, search indexes, embeddings,
  caches
- C. **Text that describes content**: subjects, titles, previews, filenames, URLs, query text,
  custom instructions
- D. **Identifiers of people outside the customer**: email addresses, names, phone numbers, IPs
- E. **Credentials** for the customer's systems: OAuth tokens, database passwords, API keys
- F. **Activity**: when things happened, how many, how long, status (usually not sensitive)
- Other

When unsure, treat A, B, C, and E as sensitive, F as metadata, and D as a judgment call for the
buyer.

## Q5. What do you need across installs?

Multi-select. Only when Q1 is just E, or includes F.

- A. Automatic updates on every release
- B. Health, versions, and logs from every install in one place
- C. Approved commands and debugging without SSH, VPN, or inbound ports
- D. A one-command install for the customer (setup link, Helm, CloudFormation, Terraform)
- E. The whole product in their environment, with no hosted part
- Other

## Q6. How much can you change the product now?

Single-select. Only when the plan moves sensitive data or the whole product, and the repository
doesn't answer it.

- A. **Not yet.** Container images or a Helm chart only.
- B. **Configuration and small adapters.**
- C. **Split services and routes.**
- D. **New code.** The remote part is greenfield.
- Other

A and B lead to deploying the existing backend as the data plane (R8d). C allows a route-level
split (R8a, R8b). Smaller to run is not always smaller to build.
