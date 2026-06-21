# Postech — Cloud-Native Game Store

Microservices platform for a digital game sales platform, deployed on AWS EKS.

## Architecture

```
                       Internet
                          │
                   API Gateway (HTTPS)
                   Cognito JWT Auth
                          │
                   NLB (nginx-ingress)
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
        /users/*      /game/*       /* (catch-all)
      users-api     catalog-api    users-api
            │             │
            ├─────────────┤
            ▼             ▼
         PostgreSQL   DynamoDB/MongoDB
         Redis (ElastiCache)
         Elasticsearch (StatefulSet)

  SNS/SQS ──► payments-api (worker) ──► SNS ──► notifications (Lambda)
```

### Infrastructure (Terraform)

| Resource | Service |
|----------|---------|
| VPC (2 AZs, public+private subnets) | `modules/network` |
| EKS (3× t3.medium) | `modules/eks` |
| RDS PostgreSQL 16 | `modules/rds_postgres` |
| DynamoDB (catalog games, notification logs) | `modules/dynamodb` |
| ElastiCache Redis 7 | `modules/elasticache_redis` |
| Cognito User Pool + JWT | `modules/cognito` |
| SNS (3 topics) + SQS (4 queues + DLQs) | `modules/messaging` |
| ECR (4 repos) | `modules/ecr` |
| API Gateway HTTP (JWT authorizer) | `modules/apigw_http` |
| Lambda (notifications ×2) | `modules/lambda_notification` |
| kube-prometheus-stack (Helm) | `addons.tf` |
| Elasticsearch StatefulSet | `elasticsearch.tf` |
| ServiceMonitors (3) | `servicemonitors.tf` |
| K8s Secrets (3) | `secrets.tf` |
| Ingress (nginx) | `ingress.tf` |

### Services

| Service | Repo | Stack | Port |
|---------|------|-------|------|
| Catalog API | `postech-catalog-api` | .NET 10, PostgreSQL + DynamoDB + Redis + Elasticsearch | 80 |
| Users API | `postech-users-api` | .NET 10, PostgreSQL, Cognito JWT | 80 |
| Payments API | `postech-payments-api` | .NET 10, PostgreSQL, SNS/SQS worker | 80 |
| Notifications | `postech-notifications-api` | .NET 8 Lambda, Brevo email | — |
| Shared Contracts | `postech-shared` | .NET 10 class library | — |

---

## Quick Start (from zero)

### Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [aws CLI](https://aws.amazon.com/cli/)
- python3
- docker
- AWS Academy credentials (access key, secret key, session token)

### Steps

```bash
# 1. Clone this repo
cd postech-orchestration

# 2. Create .env from template
cp .env.example .env
# Edit .env with your values (password + AWS credentials)

# 3. Run the bootstrap script
./setup.sh
# → Creates ECR repos, then prompts you to push images.
# → After images are pushed (press Enter), continues with full apply.
```

### After setup.sh

```bash
# 4. Deploy services to EKS
#    For each service repo, go to Actions tab → Run workflow (deploy)
#    This patches AWS credentials + deploys/updates services on EKS

# 5. Verify
API_URL=$(terraform output -raw api_gateway_invoke_url)
curl "$API_URL/health"
```

---

## CI/CD Pipelines

Each service repo has a GitHub Actions workflow (`.github/workflows/ci.yml`).

```
git push main
    ├─ build-test  → dotnet restore → build → test
    └─ docker      → login ECR → buildx → push (latest + SHA)

workflow_dispatch (manual trigger)
    └─ deploy      → patch aws-credentials → kubectl apply → set image → rollout
```

| Job | Trigger | Purpose |
|-----|---------|---------|
| `build-test` | Push to main | Compile + test |
| `docker` | Push to main | Build image + push to ECR |
| `deploy` | Manual (`workflow_dispatch`) | Rolling update to EKS |

### GitHub Secrets per repo

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | ECR + EKS authentication |
| `AWS_SECRET_ACCESS_KEY` | |
| `AWS_SESSION_TOKEN` | (expires every 4-8h in AWS Academy) |

### Environment Variables per repo (Settings → Environments → master)

| Variable | Value |
|----------|-------|
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | `565655678867` |
| `ECR_REPO` | `tf-postech-catalog-api` (varies per service) |

---

## Access

### API Gateway

```bash
cd postech-orchestration/terraform/envs/prod
terraform output api_gateway_invoke_url
```

### Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000 — admin / admin
```

### Elasticsearch

```bash
kubectl exec deployment/catalog-api -- wget -qO- http://elasticsearch:9200/_cluster/health
```

### Services health

```bash
curl "$(terraform output -raw api_gateway_invoke_url)/health"
```

---

## Manual Deploy (without setup.sh)

```bash
# 1. Backend
cd aws && ./setup-terraform-backend.sh

# 2. Key pair
aws ec2 create-key-pair --region us-east-1 --key-name postech-key \
  --query 'KeyMaterial' --output text > ~/.ssh/postech-key.pem
chmod 400 ~/.ssh/postech-key.pem

# 3. Terraform
cd ../terraform/envs/prod
export TF_VAR_db_password="your-password"
terraform init && terraform apply

# 4. EKS kubeconfig
aws eks update-kubeconfig --region us-east-1 --name tf-postech-eks

# 5. Nginx ingress controller
kubectl apply --validate=false -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/aws/deploy.yaml

# 6. AWS credentials for pods
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="..." \
  --from-literal=AWS_SECRET_ACCESS_KEY="..." \
  --from-literal=AWS_SESSION_TOKEN="..." \
  --dry-run=client -o yaml | kubectl apply -f -

# 7. Final terraform apply (API Gateway wiring)
terraform apply

# 8. Build & push images (each service repo)
# 9. Deploy services (each service CI or kubectl apply)
```

---

## Adding a New Service

1. Create repo with Dockerfile + .github/workflows/ci.yml
2. Create `k8s/` directory: `deployment.yaml`, `service.yaml`, `configmap.yaml`
3. Add K8s secret in `envs/prod/secrets.tf`
4. Add ServiceMonitor in `envs/prod/servicemonitors.tf`
5. Update Ingress in `envs/prod/ingress.tf`
6. Push → CI builds image → manual deploy to EKS

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `iam:CreateRole` denied | LabRole lacks IAM permissions | Uses pre-built EKS roles (configured in `main.tf`) |
| Pods CrashLoopBackOff | Missing AWS credentials | Trigger any CI deploy → patches `aws-credentials` |
| 404 from API Gateway | Ingress routing missing | Check `ingress.tf` routes |
| `Unable to locate credentials` | AWS creds expired | Refresh in `.env` + re-run setup.sh or CI deploy |
| Elasticsearch not found | StatefulSet not deployed | `terraform apply` (added in `elasticsearch.tf`) |
