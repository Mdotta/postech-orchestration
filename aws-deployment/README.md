# AWS Deployment — Course Project

This directory contains a fully automated AWS CLI deployment suite for the FIAP Cloud Games project. It deploys two .NET 10 APIs (**users-api** and **catalog-api**) onto AWS using Fargate-backed ECS services, replaces RabbitMQ with Amazon SQS, and exposes a single HTTPS entry-point through an API Gateway HTTP API with native JWT validation.

The scripts are intentionally designed for **AWS Academy** environments and favor simplicity over production-grade hardening — they are a proof of knowledge, not a blueprint for a production system.

## Architecture Overview

```
Client (HTTPS)
       │
       ▼
 API Gateway (HTTP API)
   ├─ POST /users/auth/login    ──[public]──► Users API (ECS Fargate)
   ├─ POST /users/auth/register ──[public]──►      │
   ├─ ANY  /users/{proxy+}  ──[JWT auth]──────────►│──► RDS (users-db, PostgreSQL)
   │                                                │
   └─ ANY  /catalog/{proxy+} ──[JWT auth]──► Catalog API (ECS Fargate)
                                                    │──► RDS (catalog-db, PostgreSQL)
                                                    └──► Amazon SQS (replaces RabbitMQ)
```

**AWS services used:**

| Service | Purpose |
|---|---|
| Amazon ECR | Container image registry |
| Amazon ECS Fargate | Serverless container hosting |
| Amazon RDS (PostgreSQL) | Managed relational databases |
| Amazon SQS | Message broker (replaces RabbitMQ / MassTransit) |
| API Gateway HTTP API | HTTPS routing + native JWT validation |
| VPC / Subnets / SGs | Network isolation |
| CloudWatch Logs | Container log aggregation |
| LabRole (IAM) | Pre-provisioned Academy execution role |

---

## Script Reference

| # | Script | Description |
|---|---|---|
| 1 | `01-networking.sh` | Creates the VPC, public/private subnets, internet gateway, route tables, and security groups. Writes all IDs to `infra-outputs.env`. |
| 2 | `02-ecr-push.sh` | Creates ECR repositories, authenticates Docker, then builds and pushes both API images. ECR images persist between Academy sessions — set `SKIP_ECR_PUSH=true` after the first run. |
| 3 | `03-sqs.sh` | Creates two SQS queues (`users-events`, `catalog-events`) used by MassTransit as a drop-in replacement for RabbitMQ. |
| 4 | `04-rds.sh` | Creates a DB subnet group and two `db.t3.micro` PostgreSQL instances in private subnets. Waits for them to become available and writes their endpoints to `infra-outputs.env`. |
| 5 | `05-iam.sh` | **AWS Academy version**: looks up the pre-existing `LabRole` ARN and writes it as both `TASK_ROLE_ARN` and `EXECUTION_ROLE_ARN`. Does **not** create any IAM resources. |
| 6 | `06-ecs.sh` | Creates the ECS cluster, registers Fargate task definitions for both APIs (injecting env vars for DB, SQS, and JWT), creates/updates the services, and captures the public IPs of the running tasks. |
| 7 | `07-apigateway.sh` | Creates the HTTP API Gateway, a JWT authorizer, HTTP proxy integrations to each ECS task IP, public and protected routes, and deploys the `$default` stage. |
| — | `redeploy.sh` | Orchestrator: runs all scripts in order. Use this at the start of every Academy session. |

---

## Prerequisites

```bash
# AWS CLI v2
aws --version        # must be 2.x

# Docker (for building/pushing images)
docker --version

# jq (used in test commands)
jq --version

# Verify your Academy session is active
aws sts get-caller-identity
```

---

## Usage — AWS Academy

### First run (full deployment)

```bash
# 1. Export required secrets as environment variables
export DB_PASSWORD="YourStrongPassword123!"
export JWT_KEY="your-super-secret-256-bit-key-replace-this"
export USERS_API_PATH="/absolute/path/to/users-api"
export CATALOG_API_PATH="/absolute/path/to/catalog-api"

# 2. Run the full pipeline from this directory
cd aws-deployment
bash redeploy.sh
```

### Subsequent sessions (images already in ECR)

```bash
export DB_PASSWORD="YourStrongPassword123!"
export JWT_KEY="your-super-secret-256-bit-key-replace-this"
export SKIP_ECR_PUSH=true   # skip docker build/push

cd aws-deployment
bash redeploy.sh
```

### After deployment — run EF Core migrations

RDS is recreated each session, so migrations must be re-applied each time.

```bash
source ./infra-outputs.env

# Temporarily allow your workstation's IP to reach RDS
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG --protocol tcp --port 5432 --cidr $MY_IP/32

# Run migrations from your API repositories
cd /path/to/users-api
dotnet ef database update \
  --connection "Host=$USERS_DB_HOST;Database=usersdb;Username=postgres;Password=$DB_PASSWORD"

cd /path/to/catalog-api
dotnet ef database update \
  --connection "Host=$CATALOG_DB_HOST;Database=catalogdb;Username=postgres;Password=$DB_PASSWORD"

# Remove the temporary inbound rule
aws ec2 revoke-security-group-ingress \
  --group-id $RDS_SG --protocol tcp --port 5432 --cidr $MY_IP/32
```

---

## Environment Variables & Secrets

| Variable | Where set | Description |
|---|---|---|
| `AWS_REGION` | shell env | AWS region (default: `us-east-1`) |
| `DB_PASSWORD` | shell env | PostgreSQL master password — **never commit** |
| `JWT_KEY` | shell env | 256-bit JWT signing key — **never commit** |
| `JWT_ISSUER` | shell env | JWT issuer claim (default: `users-api`) |
| `JWT_AUDIENCE` | shell env | JWT audience claim (default: `course-app`) |
| `USERS_API_PATH` | shell env | Absolute path to users-api local clone |
| `CATALOG_API_PATH` | shell env | Absolute path to catalog-api local clone |
| `SKIP_ECR_PUSH` | shell env | Set `true` to skip `docker build/push` after first run |

For a real project, store `DB_PASSWORD` and `JWT_KEY` in **AWS Secrets Manager** and reference them from the ECS task definition instead of passing them as plain environment variables.

---

## MassTransit → SQS Migration

In each API, swap the RabbitMQ transport for SQS:

```xml
<!-- .csproj -->
<PackageReference Include="MassTransit.AmazonSQS" Version="8.*" />
```

```csharp
// Program.cs
builder.Services.AddMassTransit(x =>
{
    x.AddConsumers(typeof(Program).Assembly);
    x.UsingAmazonSqs((context, cfg) =>
    {
        cfg.Host("us-east-1");
        cfg.ConfigureEndpoints(context);
    });
});
```

The ECS task role (LabRole in Academy) already has `sqs:*` permissions.

---

## Caveats for Students

> **Read these before every session.**

1. **Session length (4 hours).** AWS Academy sessions expire after approximately 4 hours. All resources except ECR images are **destroyed on session end**. Always run `redeploy.sh` at the start of a new session.

2. **ECS task IPs change.** Every time a Fargate task is replaced (new deployment, session restart, task crash), it gets a new public IP. The API Gateway integrations point to these IPs, so you must re-run `07-apigateway.sh` (or the full `redeploy.sh`) after any task replacement.

3. **RDS is ephemeral.** Both PostgreSQL instances are recreated each session. Remember to re-run EF Core migrations before testing the APIs.

4. **No IAM role creation.** AWS Academy does not allow creating IAM roles. `05-iam.sh` reads the pre-existing `LabRole` instead. Do **not** run the original `05-iam.sh` from a non-Academy guide.

5. **Region is fixed.** Academy environments are typically locked to `us-east-1`. Verify this in the Lab dashboard before running the scripts.

6. **VPC quota.** Each account has a default limit of 5 VPCs per region. If you hit the limit, delete leftover VPCs with `aws ec2 describe-vpcs` and `aws ec2 delete-vpc`.

7. **Migrations open a temporary inbound rule.** The migration step above temporarily adds your IP to the RDS security group. Always run the `revoke` command afterwards to close it.

8. **JWT key consistency.** The same `JWT_KEY`, `JWT_ISSUER`, and `JWT_AUDIENCE` values must be used in both the ECS task definitions (injected via env vars) and in the API Gateway JWT authorizer. If they drift, the gateway will reject all tokens.
