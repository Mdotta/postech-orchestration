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

## Manual Deployment (from zero)

### Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [aws CLI](https://aws.amazon.com/cli/)
- python3
- docker
- AWS Academy credentials (access key, secret key, session token)

---

### Step 1 — Terraform backend

```bash
cd postech-orchestration
./aws/setup-terraform-backend.sh
```

---

### Step 2 — Key pair

```bash
aws ec2 create-key-pair --key-name postech-key --region us-east-1 \
  --query 'KeyMaterial' --output text > postech-key.pem
chmod 400 postech-key.pem
```

---

### Step 3 — Discover EKS IAM roles

AWS Academy provides pre-built EKS roles. Their names vary per session.

```bash
EKS_CLUSTER_ROLE=$(aws iam list-roles --query 'Roles[*].RoleName' \
  --output text | tr '\t' '\n' | grep LabEksClusterRole)
EKS_NODE_ROLE=$(aws iam list-roles --query 'Roles[*].RoleName' \
  --output text | tr '\t' '\n' | grep LabEksNodeRole)

echo "Cluster: $EKS_CLUSTER_ROLE"
echo "Node:    $EKS_NODE_ROLE"
```

---

### Step 4 — Terraform (ECR repos only)

ECR repos must exist before images can be pushed.

```bash
cd postech-orchestration/terraform/envs/prod
terraform init

terraform apply -target=module.ecr -auto-approve \
  -var="db_password=<your-password>" \
  -var="existing_cluster_role_name=$EKS_CLUSTER_ROLE" \
  -var="existing_node_role_name=$EKS_NODE_ROLE"
```

---

### Step 5 — Build and push Docker images

From each service repo:

```bash
cd postech-catalog-api && AWS_ACCOUNT_ID=565655678867 ./infra/deploy-ecr.sh
cd postech-users-api && AWS_ACCOUNT_ID=565655678867 ./infra/deploy-ecr.sh
cd postech-payments-api && AWS_ACCOUNT_ID=565655678867 ./infra/deploy-ecr.sh
cd postech-notifications-api && AWS_ACCOUNT_ID=565655678867 ./infra/deploy-ecr.sh
```

---

### Step 6 — Terraform (full apply)

```bash
cd postech-orchestration/terraform/envs/prod

terraform apply -auto-approve \
  -var="db_password=<your-password>" \
  -var="existing_cluster_role_name=$EKS_CLUSTER_ROLE" \
  -var="existing_node_role_name=$EKS_NODE_ROLE"
```

Takes ~20 minutes. Provisions VPC, EKS, RDS, Redis, DynamoDB, Cognito, SNS/SQS, Lambda, kube-prometheus-stack, K8s secrets, Ingress.

---

### Step 7 — EKS kubeconfig

```bash
aws eks update-kubeconfig --region us-east-1 --name tf-postech-eks
kubectl get nodes   # expect 3 Ready nodes
```

---

### Step 8 — Nginx ingress controller

```bash
kubectl apply --validate=false -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/aws/deploy.yaml
```

Wait for it to be ready:

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

---

### Step 9 — AWS credentials for pods

Pods need AWS credentials to use SNS, SQS, DynamoDB, Cognito.

```bash
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="<key>" \
  --from-literal=AWS_SECRET_ACCESS_KEY="<secret>" \
  --from-literal=AWS_SESSION_TOKEN="<token>" \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

### Step 10 — Shared K8s resources

```bash
cd postech-orchestration

kubectl apply -f k8s/elasticsearch/

kubectl apply -f k8s/catalog-api/servicemonitor.yaml
kubectl apply -f k8s/users-api/servicemonitor.yaml
kubectl apply -f k8s/payments-api/servicemonitor.yaml

# Wait for Elasticsearch
kubectl wait --for=condition=ready pod \
  --selector=app=elasticsearch --timeout=180s
```

---

### Step 11 — Deploy service workloads

From each service repo, apply its K8s manifests:

```bash
cd postech-catalog-api && kubectl apply -f k8s/
cd postech-users-api && kubectl apply -f k8s/
cd postech-payments-api && kubectl apply -f k8s/
```

Or trigger CI deploy workflows from GitHub Actions.

---

### Step 12 — Finalize API Gateway

The first apply used `http://0.0.0.0` as a placeholder. This re-apply reads the real NLB DNS from the Ingress and updates the API Gateway integrations.

```bash
cd postech-orchestration/terraform/envs/prod
terraform apply -auto-approve \
  -var="db_password=<your-password>" \
  -var="existing_cluster_role_name=$EKS_CLUSTER_ROLE" \
  -var="existing_node_role_name=$EKS_NODE_ROLE"
```

---

### Step 13 — Verify

```bash
API_URL=$(terraform output -raw api_gateway_invoke_url)
curl "$API_URL/health"
curl "$API_URL/game/search?q=zelda&fuzziness=2"
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

### GitHub Secrets per repo (Settings → Secrets and variables → Actions)

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

---

## Cleanup

```bash
cd postech-orchestration/terraform/envs/prod

terraform destroy -auto-approve \
  -var="db_password=..." \
  -var="existing_cluster_role_name=$(aws iam list-roles --query 'Roles[*].RoleName' --output text | tr '\t' '\n' | grep LabEksClusterRole)" \
  -var="existing_node_role_name=$(aws iam list-roles --query 'Roles[*].RoleName' --output text | tr '\t' '\n' | grep LabEksNodeRole)"
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `iam:CreateRole` denied | LabRole lacks IAM permissions | Uses pre-built EKS roles (Step 3) |
| Pods CrashLoopBackOff | Missing AWS credentials | Re-run Step 9 or trigger CI deploy |
| 404 from API Gateway | Ingress routing missing | Check `ingress.tf` routes |
| `Unable to locate credentials` | AWS creds expired | Re-run Step 9 with fresh values |
| Elasticsearch not found | StatefulSet not deployed | Run Step 10 |
| `ResourceInUseException` for EKS | Cluster already exists | `aws eks delete-nodegroup ...` then `aws eks delete-cluster ...` |
| `RepositoryAlreadyExistsException` | ECR name conflict | Delete old repos: `aws ecr delete-repository --force` |
| Lambda `InvalidParameterValueException` | Image not in ECR | Push image first (Step 5) |
