# postech-orchestration - Kubernetes

Manifests Kubernetes para deploy do **FIAP Cloud Games** no cluster Kubernetes.

## Pré-requisitos

- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) instalado
- Acesso a um cluster Kubernetes configurado em `~/.kube/config`
- [`envsubst`](https://www.gnu.org/software/gettext/) instalado (`sudo apt install gettext-base`)

## Configuração do ambiente

Antes de fazer o deploy, edite o arquivo `k8s/env.sh` com os valores do seu ambiente:

```bash
# IP do LoadBalancer do seu cluster
export LOAD_BALANCER_IP="127.0.0.1"

# Docker Hub username dono das imagens
export DOCKER_USER="seuUsuario"

# Tag das imagens
export IMAGE_TAG="v1"
```

### Como descobrir o IP do LoadBalancer

```bash
kubectl get svc -n ingress-nginx
# Copie o EXTERNAL-IP do ingress-nginx-controller
```

## Como fazer o deploy

```bash
cd k8s/scripts
chmod +x deploy.sh
./deploy.sh
```

## Como fazer o deploy em outro cluster

1. Configure o `~/.kube/config` apontando para o novo cluster
2. Edite o `k8s/env.sh` com o novo IP do LoadBalancer
3. Execute `./scripts/deploy.sh`

## Estrutura de pastas

```
k8s/
├── env.sh                          # Configurações do ambiente (edite aqui)
├── namespace.yaml                  # Namespaces: gamestore + infrastructure
├── infrastructure/
│   ├── postgresql.yaml             # PostgreSQL + init dos 4 databases
│   ├── rabbitmq.yaml               # RabbitMQ
│   └── redis.yaml                  # Redis
├── users-api/
│   └── users-api.yaml              # ConfigMap + Secret + Deployment + Service + Ingress
├── catalog-api/
│   └── catalog-api.yaml
├── payments-api/
│   └── payments-api.yaml
├── notifications-api/
│   └── notifications-api.yaml
└── scripts/
    └── deploy.sh                   # Deploy completo
```

## Variáveis de Ambiente dos Microsserviços

### UsersAPI
| Variável | Tipo | Descrição |
|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | ConfigMap | Ambiente de execução |
| `RabbitMQ_Host` | ConfigMap | Host do RabbitMQ |
| `RabbitMQ_Port` | ConfigMap | Porta AMQP |
| `JwtSettings_Issuer` | ConfigMap | Issuer do token JWT |
| `JwtSettings_Audience` | ConfigMap | Audience do token JWT |
| `JwtSettings_ExpirationMinutes` | ConfigMap | Expiração em minutos |
| `Redis_Host` | ConfigMap | Host do Redis |
| `ConnectionStrings_DefaultConnection` | Secret | Connection string PostgreSQL |
| `JwtSettings_SecretKey` | Secret | Chave secreta JWT |
| `RabbitMQ_Username` | Secret | Usuário RabbitMQ |
| `RabbitMQ_Password` | Secret | Senha RabbitMQ |

### CatalogAPI
| Variável | Tipo | Descrição |
|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | ConfigMap | Ambiente de execução |
| `RabbitMQ_Host` | ConfigMap | Host do RabbitMQ |
| `RabbitMQ_Port` | ConfigMap | Porta AMQP |
| `ConnectionStrings_Default` | Secret | Connection string PostgreSQL |
| `RabbitMQ_Username` | Secret | Usuário RabbitMQ |
| `RabbitMQ_Password` | Secret | Senha RabbitMQ |

### PaymentsAPI
| Variável | Tipo | Descrição |
|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | ConfigMap | Ambiente de execução |
| `RabbitMQ_Host` | ConfigMap | Host do RabbitMQ |
| `RabbitMQ_Port` | ConfigMap | Porta AMQP |
| `ConnectionStrings_DefaultConnection` | Secret | Connection string PostgreSQL |
| `RabbitMQ_Username` | Secret | Usuário RabbitMQ |
| `RabbitMQ_Password` | Secret | Senha RabbitMQ |

### NotificationsAPI
| Variável | Tipo | Descrição |
|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | ConfigMap | Ambiente de execução |
| `RabbitMQ_Host` | ConfigMap | Host do RabbitMQ |
| `Brevo_SenderEmail` | ConfigMap | E-mail remetente |
| `Brevo_SenderName` | ConfigMap | Nome remetente |
| `RabbitMQ_Username` | Secret | Usuário RabbitMQ |
| `RabbitMQ_Password` | Secret | Senha RabbitMQ |
| `Brevo_ApiKey` | Secret | Chave da API Brevo |

## URLs dos Serviços

Após o deploy as URLs seguem o padrão:

| Serviço | URL |
|---|---|
| **Users API** | `http://users-api.<LOAD_BALANCER_IP>.nip.io` |
| **Catalog API** | `http://catalog-api.<LOAD_BALANCER_IP>.nip.io` |
| **Payments API** | `http://payments-api.<LOAD_BALANCER_IP>.nip.io` |
| **Notifications API** | `http://notifications-api.<LOAD_BALANCER_IP>.nip.io` |
| **PostgreSQL** | `postgresql.infrastructure.svc.cluster.local:5432` |
| **RabbitMQ** | `rabbitmq.infrastructure.svc.cluster.local:5672` |
| **Redis** | `redis.infrastructure.svc.cluster.local:6379` |

## Repositórios dos Microsserviços

- [postech-users-api](#) - Cadastro, autenticação (JWT) e autorização
- [postech-catalog-api](#) - CRUD de jogos e início do fluxo de compra
- [postech-payments-api](#) - Processamento de pagamentos
- [postech-notifications-api](#) - Envio de e-mails
