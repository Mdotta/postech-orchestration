# Infraestrutura Local de Desenvolvimento

Este diretorio sobe a infraestrutura compartilhada para desenvolvimento local das APIs:

- PostgreSQL 16
- RabbitMQ 3.13 (management)
- Redis 7
- MongoDB 7

> **Este e o ambiente de desenvolvimento local.** Para deploy em producao na AWS, veja [`terraform/README.md`](../terraform/README.md).

## Dependencias

- Docker Desktop (ou Docker Engine + Compose)

## Subir a infra local

```bash
cd docker
docker compose up -d
```

## Verificar status

```bash
docker compose ps
```

## Ver logs

```bash
docker compose logs -f postgresql
docker compose logs -f mongodb
```

## Parar

```bash
docker compose down
```

## Remover tudo (inclui volumes)

```bash
docker compose down -v
```

## Endpoints locais

| Servico | Host | Porta | Notas |
|---------|------|-------|-------|
| PostgreSQL | `localhost` | `5432` | DB: `postech_main`, user: `postech_admin`, pass: `postech_dev_password` |
| RabbitMQ AMQP | `localhost` | `5672` | user: `postech_user`, pass: `postech_rabbit_password` |
| RabbitMQ UI | `http://localhost:15672` | — | Management console |
| Redis | `localhost` | `6379` | Sem autenticacao |
| MongoDB | `localhost` | `27017` | user: `postech_admin`, pass: `postech_dev_password` |

Os aliases de rede internos simulam DNS de Kubernetes (`*.infrastructure.svc.cluster.local`), permitindo reaproveitar as mesmas variaveis de host entre ambientes.

## Como usar com as APIs

Apos subir a infra, cada API pode ser executada localmente com `dotnet run`. As connection strings em `appsettings.json` de cada servico ja apontam para `localhost` com as credenciais acima.

Exemplo com o Catalog API:

```bash
# Terminal 1: infra
cd postech-orchestration/docker
docker compose up -d

# Terminal 2: API
cd postech-catalog-api/src/Postech.Catalog.Api
dotnet run
```
