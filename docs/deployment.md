# Deployment Strategy

## Where This Sits in the Overall Plan

The deployment strategy evolves in stages rather than arriving all at once:

1. **Local** — Docker Compose (not yet built)
2. **First staging environment** — Terraform-provisioned AWS infra, manual deploy — **current stage**
3. **Automated CI/CD** — partially done: infra validation is automated, app build/deploy is not (no app repo yet)
4. **Reverse proxy + replicas** — deferred, `desired_count = 1` everywhere today
5. **Production-minded AWS infrastructure** — deferred (see `diagrams/aws.md` for the deliberate portfolio-stage trade-offs already accepted: no NAT Gateway, no Multi-AZ RDS, self-hosted Redis)
6. **Blue-green deployment** — the ALB already has two target groups (`api_blue`/`api_green`) ready for this, but nothing automates the swap yet
7. **Rollback test** — depends on Stage 6
8. **Local Kubernetes proof of concept** — not started

## CI/CD Split Across Two Repos

This repository (`workforce-os-architecture`) is not the application repo, so its CI/CD responsibility is narrower than the full pipeline described in the architecture guidelines:

| Concern | Lives in | Status |
|---|---|---|
| Terraform fmt/validate/security-scan | This repo — [`.github/workflows/terraform-ci.yml`](../.github/workflows/terraform-ci.yml) | ✅ Implemented |
| App lint/typecheck/unit tests | `workforce-os` (app repo) | Not started — app repo doesn't exist yet |
| Build image, push to ECR, deploy to ECS | `workforce-os` (app repo) | Not started |
| Automated `terraform apply` on infra changes | This repo (potential future workflow) | Deliberately not built yet — see below |

**Why app deploy doesn't trigger `terraform apply`:** provisioning infrastructure (VPC, RDS, ECS services existing at all) and deploying a new application version are different concerns with different blast radii. A new image gets rolled out via `aws ecs update-service` / a new task definition revision — Terraform is not re-run for that. Terraform only needs to run again when the *infrastructure itself* changes (a new module, a resized instance, a new environment variable wired through).

**Why there's no automated `apply` workflow yet:** doing so would require AWS credentials to exist in GitHub Actions. That's a real trust boundary this project hasn't decided how to cross yet (OIDC federation vs. long-lived keys, who can trigger a production-affecting apply, whether it needs manual approval) — worth its own decision, not something to bolt on incidentally. Until then, `apply`/`destroy` are run locally, which is also what the weekly on/off cadence below assumes.

## Operating Cadence: Active 2 Days a Week

The chosen cost model for this portfolio project is: **infrastructure exists only on the days it's being used**, not 24/7. See [`docs/runbooks/deployment.md`](runbooks/deployment.md) for the exact commands.

**The constraint this runs into:** the ALB bills hourly for existing at all — there's no "paused" state for it, only "exists" or "destroyed." Stopping ECS tasks (`desired_count = 0`) or stopping RDS (`aws rds stop-db-instance`, up to 7 days at a time) reduces compute cost but the ALB keeps billing regardless. So a genuine near-zero-cost off-period requires a full `terraform destroy`, not a partial scale-down.

**The consequence:** `terraform destroy` deletes RDS along with everything else — there is no data continuity between active periods under this model. This is accepted deliberately here, not an oversight: the AI/demo data strategy in this project already leans on synthetic/seed data (see the AI Architecture section of `system-architecture.md`), so each active period re-seeding fresh demo data is consistent with how the rest of the system is designed to be demoed, not a workaround bolted on for cost reasons alone.

If data continuity across sessions ever becomes genuinely necessary (e.g. demoing a specific scenario that took manual setup to reach), the alternative is an RDS snapshot taken before `destroy` and restored on the next `apply` — deliberately not built now, since it adds real complexity for a need that hasn't materialized yet.

## What Changes Once `workforce-os` Exists

1. The app repo gets its own CI (lint/typecheck/test) and CD (build → push to the ECR repo this Terraform already provisions → deploy) workflow.
2. `api_image`/`worker_image` in `terraform.tfvars` point at real pushed images instead of the `nginx` placeholder.
3. The manual deploy runbook becomes the thing that CD automates — the commands don't change, only who/what runs them.
