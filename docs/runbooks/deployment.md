# Deployment Runbook

Companion to [`docs/deployment.md`](../deployment.md), which explains *why* this project runs on a 2-day-a-week active cadence instead of 24/7. This doc is just the commands.

## Prerequisites (one-time)

- AWS CLI configured with credentials that can create VPCs/ECS/RDS/S3/IAM (`aws configure`, or an SSO profile).
- Docker installed, for building the app image.
- `infra/terraform/environments/dev/terraform.tfvars` created from `terraform.tfvars.example`, with real `db_username`/`db_password` filled in. This file is gitignored — it never gets committed.

## Spin-Up (start of an active day)

```bash
cd infra/terraform/environments/dev
terraform init      # only needed the first time, or after changing modules/backend
terraform apply
```

Review the plan output before confirming — this is creating real, billed resources (ALB, RDS, ECS services). Takes a few minutes, mostly waiting on RDS to become available.

```bash
# Get the values you'll need next
terraform output
```

## Deploying Your App (whenever `workforce-os` has code to ship)

```bash
# 1. Authenticate Docker against the ECR repo Terraform created
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com

# 2. Build and push (run from the workforce-os repo)
docker build -t $(terraform output -raw ecr_repository_url):latest .
docker push $(terraform output -raw ecr_repository_url):latest

# 3. Point the infra at the real image (first time only - after this, put these
#    in terraform.tfvars so you don't retype them every deploy)
terraform apply \
  -var="api_image=$(terraform output -raw ecr_repository_url):latest" \
  -var="worker_image=$(terraform output -raw ecr_repository_url):latest"

# 4. Run migrations + seed demo data as a one-off task (not part of the long-running service)
aws ecs run-task \
  --cluster dev-cluster \
  --task-definition dev-api \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<public-subnet-ids>],securityGroups=[<app-sg-id>],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides":[{"name":"api","command":["npm","run","migrate:and:seed"]}]}'
```

Subnet/security-group IDs for step 4 come from `terraform output` on the network module (not surfaced at the environment level yet — add an output if you find yourself running this often).

## Verify

```bash
curl http://$(terraform output -raw alb_dns_name)/health

# Watch logs if something looks wrong
aws logs tail /ecs/dev/api --follow
```

## Tear-Down (end of an active day/session)

```bash
cd infra/terraform/environments/dev
terraform destroy
```

**This deletes RDS along with everything else — there is no data continuity between sessions under this model.** See `docs/deployment.md` for why that's an accepted trade-off here rather than an oversight. Confirm the plan before typing `yes`; `destroy` is not reversible.

## Alternative: Keep Data, Pay a Little More

If you ever need a specific demo scenario to survive between sessions, the ALB is still the blocker (it has no "paused" state — it either exists and bills, or is destroyed). Two options, in order of how much they cost:

1. **Snapshot before destroy, restore on next apply** — `aws rds create-db-snapshot` before `terraform destroy`, then wire the snapshot into the `aws_db_instance` resource's `snapshot_identifier` argument on the next `apply`. Not built into the Terraform yet — add it if this need actually comes up, rather than in advance of needing it.
2. **Stop instead of destroy** — `aws ecs update-service --desired-count 0` for each service, and `aws rds stop-db-instance` (auto-resumes after 7 days if you don't manually restart it first). Keeps RDS storage (small ongoing cost) and skips Fargate compute cost, but **the ALB keeps billing the whole time** since it can't be stopped — this only makes sense if the ALB's ~$16-20/mo is worth it to you for session-to-session continuity.

For now, the default is full `destroy`/`apply` each cycle — it's the cheapest option and matches how the rest of this project already treats demo data as synthetic and disposable.
