## Terraform — Deploy AWS (Producao)

Este diretorio provisiona toda a infraestrutura da FIAP Cloud Games na AWS usando Terraform.

> **Ambiente de desenvolvimento:** AWS Academy Learner Lab. Os recursos `LabRole` (IAM role) e `LabInstanceProfile` (instance profile) ja existem nesse ambiente e sao referenciados via data sources.

### Pre-requisitos

- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado (`aws configure` ou `AWS_PROFILE`)
- [Docker](https://www.docker.com/) (para build e push das imagens)
- AWS Academy Learner Lab com `LabRole` / `LabInstanceProfile` provisionados

### O que e provisionado

| Recurso | Modulo |
|---------|--------|
| **VPC + 2 subnets** | `network-default` |
| **Security groups** (EC2, RDS, monitoring) | `security_groups` |
| **RDS PostgreSQL 16** | `rds_postgres` |
| **DynamoDB** (catalog_games + notifications_event_logs) | `dynamodb` |
| **ElastiCache Redis 7** | `elasticache_redis` |
| **Cognito User Pool + App Client** | `cognito` |
| **SNS topicos + SQS filas + DLQs** | `messaging` |
| **ECR repositories** (4x) | `ecr` |
| **EC2 instances** (users, catalog, payments) | `compute_ec2_service` |
| **Lambda functions** (notifications x2) | `lambda_notification` |
| **API Gateway HTTP** (Cognito JWT auth) | `apigw_http` |
| **CloudWatch log groups** | `cloudwatch` |
| **Grafana + Prometheus** (monitoring EC2) | `compute_monitoring` |

### Arquitetura

```
                          ┌──────────────────┐
                          │   API Gateway    │
                          │  (Cognito JWT)   │
                          └──┬───────┬───────┘
                             │       │
              ┌──────────────┼───────┼──────────────┐
              ▼              ▼       ▼              ▼
     ┌────────────┐  ┌────────────┐  ┌────────────┐
     │ users-api  │  │catalog-api │  │payments-api│
     │  (EC2)     │  │  (EC2)     │  │  (EC2)     │
     └─────┬──────┘  └──┬───┬─────┘  └──────┬─────┘
           │            │   │               │
           │    ┌───────┘   │   ┌───────────┘
           │    │           │   │
           ▼    ▼           ▼   ▼
    ┌─────────────────────────────────────────┐
    │  SNS (topicos) ──▶ SQS (filas + DLQs)   │
    └─────────────────────────────────────────┘
           │                       │
           ▼                       ▼
    ┌─────────────┐    ┌──────────────────────┐
    │ notifications│    │ Grafana + Prometheus │
    │  (Lambda x2) │    │      (EC2)           │
    └─────────────┘    └──────────────────────┘
           │
           ▼
    ┌──────────────────────────┐
    │ RDS │ DynamoDB │ Redis   │
    │     │ (2 tables)│        │
    └──────────────────────────┘
```

### Pipeline de deploy completo

#### 1. Setup do backend remoto

```bash
cd terraform/envs/prod
./setup-backend.sh
```

Cria o bucket S3 (`postech-terraform-state-us-east-1`) e a tabela DynamoDB (`postech-terraform-locks`) para estado remoto com lock.

#### 2. Configurar tfvars

```bash
cat > terraform.tfvars <<EOF
aws_region  = "us-east-1"
name_prefix = "tf-postech"
db_password = "SuaSenhaSeguraAqui"
EOF
```

Variaveis disponiveis em `variables.tf`. Todas tem defaults para AWS Academy.

#### 3. Primeiro terraform apply (apenas ECR)

```bash
terraform init
terraform apply -target=module.ecr -auto-approve
```

Cria apenas os repositorios ECR. Necessario antes do build das imagens porque as instancias EC2 fazem `docker pull` via user_data no boot.

#### 4. Build e push das imagens Docker

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR="${ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com/tf-postech-"
REGION="us-east-1"

aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

# Catalog API
docker build -t "${ECR}-catalog-api:latest" \
  -f ../../../postech-catalog-api/Dockerfile ../../../postech-catalog-api
docker push "${ECR}-catalog-api:latest"

# Users API
docker build -t "${ECR}-users-api:latest" \
  -f ../../../postech-users-api/Dockerfile ../../../postech-users-api
docker push "${ECR}-users-api:latest"

# Payments API
docker build -t "${ECR}-payments-api:latest" \
  -f ../../../postech-payments-api/Dockerfile ../../../postech-payments-api
docker push "${ECR}-payments-api:latest"

# Notifications Lambda
NOTIF_DIR="../../../postech-notifications-api/src/Postech.Notifications.Lambda"
docker build -t "${ECR}-notifications-lambda:latest" \
  -f "${NOTIF_DIR}/Dockerfile" "${NOTIF_DIR}"
docker push "${ECR}-notifications-lambda:latest"
```

#### 5. Deploy completo

```bash
terraform apply -auto-approve
```

Provisiona todos os recursos restantes. As instancias EC2 iniciam e fazem `docker pull` das imagens automaticamente (leva ~2 minutos para os containers ficarem saudaveis).

### Pos-deploy

```bash
# URL do API Gateway
terraform output api_gateway_invoke_url

# Grafana (monitoring)
terraform output grafana_url
# Login: admin / admin (troque a senha no primeiro acesso)

# Prometheus
terraform output prometheus_url

# Testar API
curl "https://$(terraform output -raw api_gateway_invoke_url)/catalog/games"
```

### Verificacao

```bash
# Verificar se DynamoDB esta populado
aws dynamodb scan --table-name tf-postech-catalog-games --region us-east-1

# Verificar instancias EC2
aws ec2 describe-instances --filters "Name=tag:ManagedBy,Values=terraform" \
  --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],State.Name,PublicIpAddress]"

# Logs no CloudWatch
# Acesse: CloudWatch > Log groups > tf-postech-catalog-api, etc.

# SSH nas EC2 (se necessario)
ssh -i postech-key.pem ec2-user@<eip>
docker ps    # ver containers rodando
docker logs tf-postech-catalog-api  # logs do container
```

### Destroy

```bash
terraform destroy -auto-approve
```

**Atencao:** O bucket S3 de estado e a tabela DynamoDB de lock nao sao gerenciados pelo Terraform. Remova manualmente se necessario:

```bash
aws s3 rm s3://postech-terraform-state-us-east-1 --recursive
aws s3 rb s3://postech-terraform-state-us-east-1
aws dynamodb delete-table --table-name postech-terraform-locks
```
