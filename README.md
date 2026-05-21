# postech-orchestration

Orquestracao de ambiente para o projeto FIAP Cloud Games — Tech Challenge 2026.

Este repositorio concentra os recursos para executar o ecossistema em quatro modos:

| Modo | Diretorio | Quando usar |
|------|-----------|-------------|
| **Infra local (Docker)** | `docker/` | Desenvolvimento das APIs — sobe PostgreSQL, RabbitMQ, MongoDB, Redis |
| **Deploy Kubernetes** | `k8s/` | Validacao em cluster com manifests |
| **Stack completa local** | `temp/` | Ambiente k8s-like completo via Docker Compose (todas as APIs + infra) |
| **Deploy AWS (Terraform)** | `terraform/` | **Producao na AWS** — EC2, RDS, DynamoDB, ElastiCache, SNS/SQS, Cognito, API Gateway, Lambda, CloudWatch, Grafana/Prometheus |

> **Nota:** O ambiente de desenvolvimento e testes utilizou o **AWS Academy Learner Lab**.

## Dependencias gerais

- Docker Desktop (ou Docker Engine + Compose)
- [Terraform >= 1.6](https://developer.hashicorp.com/terraform/downloads) (para deploy AWS)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (para deploy AWS)
- kubectl (para Kubernetes)
- envsubst (para Kubernetes — pacote `gettext`)
- Bash

## Estrutura

```text
postech-orchestration/
  docker/       # Infra local: PostgreSQL + RabbitMQ + MongoDB + Redis
    init-scripts/      # Scripts de inicializacao de bancos
  k8s/          # Manifests e scripts de deploy Kubernetes
    infrastructure/    # postgresql, rabbitmq, redis
    users-api/ catalog-api/ payments-api/ notifications-api/
    scripts/           # start.sh, deploy.sh, rebuild-images.sh
  terraform/    # Infra como codigo (AWS)
    modules/           # compute_ec2_service, compute_monitoring, rds_postgres,
    envs/prod/         #   dynamodb, elasticache_redis, cognito, messaging, etc.
                       # Configuracao do ambiente de producao
  temp/         # Stack completa k8s-like em Docker Compose
```

## Fluxos recomendados

### 1) Desenvolvimento local de APIs

```bash
cd docker
docker compose up -d
```

Sobe PostgreSQL, RabbitMQ, MongoDB e Redis. As APIs rodam localmente via `dotnet run`.

Documentacao: `docker/README.md`.

### 2) Deploy no Kubernetes

```bash
cd k8s/scripts
bash start.sh
```

Documentacao: `k8s/README.md`.

### 3) Ambiente completo local (k8s-like)

```bash
cd temp
docker compose up -d
```

Documentacao: `temp/README.md`.

### 4) Deploy AWS (producao)

```bash
cd terraform/envs/prod
./setup-backend.sh          # Cria bucket S3 + tabela DynamoDB para estado remoto
terraform init
terraform apply -target=module.ecr -auto-approve   # Cria repositorios ECR
# Build e push das imagens Docker para ECR (veja o README de cada API)
terraform apply -auto-approve                      # Deploy completo
```

Documentacao: `terraform/README.md`.

## Monitoramento (AWS)

Apos deploy na AWS, o Grafana fica disponivel em:

```bash
terraform output grafana_url
# http://<eip>:3000  (login: admin / admin)
```

O Prometheus coleta metricas de todas as APIs automaticamente. Logs das aplicacoes ficam no CloudWatch.
