## Terraform (AWS) deployment

This folder ports the existing AWS bash-based deployment into Terraform.

### What this stack provisions

- **Shared infrastructure** (from `postech-orchestration/aws/*.sh`)
  - Security groups (`postech-api-sg` equivalent)
  - RDS PostgreSQL instance
  - Cognito User Pool + App Client + Groups
  - SNS topics + SQS queues + DLQs + subscriptions/policies
  - API Gateway HTTP API v2 + JWT authorizer + routes
- **Services** (from each repo `infra/*.sh`)
  - ECR repositories (image build/push remains outside Terraform)
  - EC2 instances for:
    - `users-api`
    - `catalog-api`
  - **Elastic IP per service**, used as a stable API Gateway integration target

### Layout

- `terraform/envs/prod`: production composition (calls modules)
- `terraform/modules/*`: reusable modules

### Quick start

1. Configure AWS credentials in your environment (e.g. `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, etc.).
2. Edit `terraform/envs/prod/backend.tf` with your S3 bucket / DynamoDB lock table.
3. Run:

```bash
cd terraform/envs/prod
terraform init
terraform plan
terraform apply
```

### Notes

- This initial port is intentionally **close to the scripts**:
  - Uses the **default VPC**.
  - EC2 serves HTTP on port **80** publicly.
  - SSH ingress is restricted by `admin_cidr`.
- If you already have resources with the same names, set `name_prefix` to avoid collisions.

