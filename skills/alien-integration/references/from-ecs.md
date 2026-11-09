# Starting from ECS

Use this when the product runs on Amazon ECS (Fargate or EC2) and its task definitions live in
Terraform, CloudFormation, CDK, Copilot, or JSON files. It covers how to read the task
definitions and how each field maps. Then follow the steps in `existing-app.md`. If Terraform
also creates the databases, buckets, and queues, read `from-terraform.md` for those. Docs:
`guide/existing-app/ecs`, `infrastructure/container`, `infrastructure/compute-cluster`.

## Render

Get the final task definitions, with every variable resolved:

| Source | Command |
|---|---|
| A running service you can read | `aws ecs describe-task-definition --task-definition <family> --query taskDefinition` |
| Terraform | `terraform plan -out tf.plan && terraform show -json tf.plan`, then read `container_definitions` |
| CDK | `cdk synth`, then read the `AWS::ECS::TaskDefinition` resources |
| Copilot | `copilot svc package --name <svc> --env <env>` |
| JSON files | Read them, after resolving any templating your deploy script applies |

Only read: never `apply`, `deploy`, or `update-service`. Without cloud credentials, read the
source and its variable files, and mark each value you couldn't resolve as unverified.

## Mapping

| ECS | `alien.ts` |
|---|---|
| Container definition | `Container` with `.code({ type: "image", image })` |
| `cpu` (1024 = 1 vCPU), `memory` (MiB) | `.cpu(1)`, `.memory("2Gi")` |
| `portMappings` | `.port(containerPort)` |
| ALB listener and target group | `.publicEndpoint(name, port, "http")` |
| NLB | `.publicEndpoint(name, port, "tcp")` |
| Target group health check | `.healthCheck({ path, port, failureThreshold })` |
| Container `healthCheck` that only fetches a local URL (`curl -f localhost:8080/healthz`) | `.healthCheck({ path: "/healthz", port: 8080 })` |
| Container `healthCheck` with any other command | A readiness endpoint in the launcher (`stateful-services.md`) |
| `entryPoint`, `command` | `.command([...])`: the entrypoint first, then the command |
| `environment`, `environmentFiles` | `.environment({...})` |
| `secrets` from SSM or Secrets Manager | Inputs: generated developer secrets, or deployer secrets for customer values |
| `dependsOn` with `START` or `HEALTHY` | `.link()` on that container |
| `dependsOn` with `COMPLETE` or `SUCCESS` | The dependency is a setup step (`stateful-services.md`), even when it is also `essential: false` |
| `essential: false` container that keeps running | A sidecar: fold into the main process, or drop |
| Service `desiredCount` | `.replicas(n)` |
| Application Auto Scaling policy | `.autoScale({ min, desired, max, targetCpuPercent })` |
| Task role | One permission profile per service, with named permission sets |
| Execution role | Drop: Alien pulls images and injects secrets |
| EBS volume on the task | `.persistentStorage(size, { mountPath })` |
| EFS volume | A gap when replicas share files; move the files to `Storage`, or report it |
| Bind mount, `ephemeralStorage` | `.ephemeralStorage(size)` |
| Service Connect or Cloud Map name | `<id>.svc` (`existing-app.md`, step 12) |
| EventBridge scheduled task | A periodic task in a service, or a Worker with a schedule trigger |
| Capacity provider, instance type | ComputeCluster pool `requirements` |
| Private ECR image | `alien release` re-hosts it; log in to ECR on the build machine |

Drop these and record each in the audit, after checking nothing in the product reads their
output (`existing-app.md`, step 8): FireLens and other log routers, X-Ray and metrics
agents (Alien collects container logs; `alien logs`), ECS Exec settings, deployment circuit
breaker settings.

## Details that break first

- **Values that live outside the task definition.** Load balancer rules, security groups,
  service discovery, and scaling policies sit in separate resources. Search the source for every
  resource that references the service or its target group.
- **`runtimePlatform`.** Read it per task definition; services in one repo often differ. Images
  you build from source can build for arm64. If any image is x86-only, release the whole stack
  for `linux-x64` and pin the pool's architecture (`existing-app.md`, step 20).
- **Migrations with several replicas.** A `migrate` container that every task ran becomes the
  service's command prefix, behind a Postgres advisory lock (`stateful-services.md`), because
  every replica now runs it at start.
- **Scheduled tasks with several replicas.** A periodic task inside a service fires once per
  replica. Take a lock, or put it in a Worker with a schedule trigger.
- **Health paths that query the database.** On AWS, `alien.Postgres` is Aurora Serverless v2,
  which pauses when idle unless something keeps connecting. Point the health check at a path
  that doesn't touch the database, and use a connect timeout of at least 30 seconds.
- **Queue consumers.** An SQS visibility timeout doesn't carry over. Read the lease rules in
  `infrastructure/queue/behavior`, and renew the lease (`renewLease`) for long jobs.
- **Secrets by ARN.** A `valueFrom` names a secret in your account. In a customer's account it
  doesn't exist. Every one becomes an input or a value derived from a linked resource. For keys
  to your own vendors (payments, email, analytics), first decide whether that call belongs in
  your customer's account at all, and record it in the decision record.
- **IAM policies with `*` resources.** Don't copy them. Grant permission sets on the linked
  resources the service uses, then prove each with a real SDK call.
- **Static frontends** on S3 and CloudFront, or Amplify. If the decision record moves the
  frontend, serve the built files from a Container behind a public endpoint. Otherwise it stays
  hosted and calls the deployment (`reach-a-deployment.md`).

Now follow `existing-app.md` from step 2.
