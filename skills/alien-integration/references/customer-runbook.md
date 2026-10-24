# Customer runbook and white-label check

## Runbooks in the repository

Put them next to the decision record (for example `docs/alien/`), ordered by what the reader does:

1. `1-release.md`: how your team releases (CI, channels, promote, pin). Release comes first.
2. `2-<platform>.md`: one per target (AWS, Google Cloud, Azure, Kubernetes, machines). What the
   customer's admin runs, with which credentials, and what it creates.
3. `3-operate.md`: status, logs, commands, Remote Operator access requests, retries, resizing.
4. `4-remove.md`: deletion and what the customer deletes themselves.

Write for a maintainer who has never seen Alien. Define the flow before the commands.

## What the customer's admin needs to know

Give the admin a page they can forward to their security team:

- **What setup creates**: the frozen resources, the management identity and its permissions
  (copy from the setup portal's review), and the live resources Alien manages afterwards.
- **What they run, once**: the method (CloudFormation, Terraform, Helm, Google login, or your
  branded CLI) and the credentials it needs. Their credentials are used once and not stored.
- **What crosses the boundary**: the table from the decision record, in their words.
- **What they provide**: deployer inputs and secrets, and where secrets go (their own secret
  store; you never see them).
- **When they are needed again**: only when a release changes frozen resources or permissions.
  The portal shows that setup must be rerun.
- **How to remove it**: delete the setup stack or run your CLI's `destroy`. Retained data
  (buckets, databases) stays until they delete it.
- **Remote access**: none inbound. Operations through Remote Operator are named, time-boxed, and
  audited; they approve access requests.

## White-label check

The customer sees your product, not Alien. Before a customer sees anything, check every
customer-visible surface:

- Setup portal: project name, logo, and copy.
- The generated customer CLI (named after your project) and its `--help` output.
- CloudFormation stack names and parameter descriptions, Terraform module names, Helm chart name
  and values.
- Cloud resource names and tags the customer will see in their console.
- Container image names, environment variable names, and log lines your code emits.
- Error messages your product shows during setup.

Grep the repository's customer-facing files and generated templates for internal names you do
not want customers to see. Docs: `integrate/white-label`.
