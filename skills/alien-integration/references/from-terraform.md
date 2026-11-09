# Starting from Terraform, CDK, or Pulumi

Use this when infrastructure code creates the product's cloud resources: databases, buckets,
queues, keys, roles, and networks. It maps each cloud resource to what `alien.ts` declares. The
workloads the code runs have their own file: `from-ecs.md` for ECS, `from-helm.md` for EKS or a
`helm_release`, `alien-ts.md` for Lambda functions. Docs: `guide/existing-app/terraform`, `infrastructure`,
`guide/frozen-and-live`, `guide/networking`.

## Read it

```bash
terraform plan -out tf.plan && terraform show -json tf.plan > plan.json
cdk synth > template.yaml        # CDK
pulumi preview --json > plan.json  # Pulumi
```

Only read: never `apply`, `deploy`, or `up`. Without credentials, read the modules and the
variable files for the production environment, and mark unresolved values as unverified.

## Translate what the product needs, not what the code creates

Infrastructure code describes one cloud account in detail. `alien.ts` describes what the product
needs, and Alien creates it in each customer's account on AWS, Google Cloud, or Azure. Most of
the code has no counterpart: networks, endpoints, logging, and IAM plumbing come from Alien and
from initial setup. For each resource, ask which product feature uses it, and declare that.

## Mapping

| Resource (AWS names; other clouds map the same way) | `alien.ts` |
|---|---|
| RDS or Aurora Postgres | `alien.Postgres` (Aurora Serverless v2 on AWS) |
| RDS MySQL, DocumentDB, OpenSearch | No managed resource: a stateful Container (`stateful-services.md`) or a gap |
| ElastiCache, MemoryDB | A stateful Container with the stock image (`stateful-services.md`). TLS in transit and replica nodes don't carry over; record what the product relied on |
| S3 bucket | `alien.Storage` |
| SQS queue | `alien.Queue`. Its lease rules replace the visibility timeout (`infrastructure/queue/behavior`) |
| DynamoDB table read by key or key prefix | `alien.Kv` |
| DynamoDB table with secondary indexes or range queries | Postgres, or a gap; `Kv` has get, set, conditional writes, TTL, and prefix scans only |
| KMS key | `alien.Key`, which the customer can own and revoke |
| Secrets Manager secret, SSM parameter | `alien.Vault` for values the product writes; inputs for values set at install |
| Lambda function | `alien.Worker` |
| ECS service, EKS workload | See `from-ecs.md` or `from-helm.md` |
| Bedrock or other model access | AI access in your customer's account (`patterns.md`) |
| SES | `alien.Email` |
| IAM roles and policies for workloads | One permission profile per workload, with named permission sets |
| VPC, subnets, NAT, security groups | Drop: chosen at initial setup (`--network create` or `byo`) |
| Route 53 records, ACM certificates | Public endpoints; custom domains are set at initial setup |
| CloudWatch alarms, dashboards, log groups | Drop and record; deployment health and logs come from Alien |
| Terraform state buckets, CI roles | Drop: they belong to your account, not your customer's |

## Frozen or live

For each resource, decide who may change it after initial setup (`alien-ts.md`). Data stores the
customer wants to own (buckets, databases, keys) are usually frozen. Workloads are live. Write
the choice and the reason next to each declaration.

## Details that break first

- **Per-environment variables** (`prod.tfvars`) hold values that differ between your accounts.
  Each one becomes a developer input, a deployer input, or a constant. Most become constants.
- **Cross-account access.** A role that lets your account read your customer's resources is the
  wrong direction. Deployments call out to your backend (`reach-a-deployment.md`).
- **Database settings.** Engine version, extensions, and parameter groups. Render the setup
  template and lint it (`alien-ts.md`): some engine versions can't create new clusters. A major
  version change moves data by dump and restore.
- **Data that must move.** Existing customers' data in your account: see
  `move-existing-customers.md`.

Then follow `existing-app.md` from step 2 for the workloads.
