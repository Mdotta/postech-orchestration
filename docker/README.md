# Ambiente Local com Docker - FIAP Cloud Games

Este diretório sobe apenas a infraestrutura compartilhada para desenvolvimento local:

- PostgreSQL
- RabbitMQ (com UI de management)

As APIs podem rodar localmente na sua máquina (fora do Compose) ou ser executadas pelo ambiente da pasta `temp/`.

## Dependências

- Docker Desktop (ou Docker Engine)
- Docker Compose (`docker compose` ou `docker-compose`)
- Bash (para executar os scripts da pasta `scripts/`)

## Serviços e portas

### PostgreSQL
- Host local: `localhost`
- Porta: `5432` (mapeada por `${POSTGRES_PORT}` no `.env`)
- Databases criados automaticamente no primeiro start:
  - `postech_users`
  - `postech_catalog`
  - `postech_payments`
  - `postech_notifications`

### RabbitMQ
- AMQP: `localhost:5672`
- Management UI: `http://localhost:15672`

## Configuração

Na primeira execução, `scripts/start.sh` cria `.env` a partir de `.env.example` se necessário.

Fluxo recomendado:

```bash
cd docker
cp .env.example .env   # se ainda nao existir
```

Depois ajuste usuário/senha/portas no `.env` conforme sua necessidade.

## Scripts e funcionalidades

Todos os scripts devem ser executados a partir da pasta `docker/`.

### `scripts/start.sh`
Sobe a infraestrutura em background (`docker-compose up -d`) e mostra status.

```bash
cd docker
bash scripts/start.sh
```

### `scripts/stop.sh`
Para e remove os containers (mantendo volumes e dados).

```bash
cd docker
bash scripts/stop.sh
```

### `scripts/restart.sh`
Reinicia os serviços já em execução.

```bash
cd docker
bash scripts/restart.sh
```

### `scripts/logs.sh [servico]`
Mostra logs em tempo real de todos os serviços ou de um serviço específico.

```bash
cd docker
bash scripts/logs.sh
bash scripts/logs.sh postgres
bash scripts/logs.sh rabbitmq
```

### `scripts/build.sh [servico]`
Executa `docker-compose build --no-cache`. Neste compose atual (infra com imagens oficiais), é útil principalmente para padronizar fluxo de rebuild.

```bash
cd docker
bash scripts/build.sh
bash scripts/build.sh rabbitmq
```

### `scripts/status.sh`
Exibe `docker-compose ps` e tenta consultar health dos containers.

```bash
cd docker
bash scripts/status.sh
```

### `scripts/clean.sh`
Limpa completamente o ambiente (containers, volumes e imagens locais do compose).

```bash
cd docker
bash scripts/clean.sh
```

## Exemplos com comandos Docker Compose

### Subir infraestrutura

```bash
cd docker
docker compose up -d
```

### Ver status

```bash
cd docker
docker compose ps
```

### Acompanhar logs do RabbitMQ

```bash
cd docker
docker compose logs -f rabbitmq
```

### Derrubar mantendo dados

```bash
cd docker
docker compose down
```

### Derrubar removendo volumes

```bash
cd docker
docker compose down -v
```

## Strings de conexão de referência

### PostgreSQL

```text
Host=localhost;Port=5432;Database=postech_users;Username=<POSTGRES_USER>;Password=<POSTGRES_PASSWORD>
```

### RabbitMQ

```text
amqp://<RABBITMQ_USER>:<RABBITMQ_PASSWORD>@localhost:5672
```

## Observações

- O script SQL `init-scripts/01-init-databases.sql` roda apenas na primeira inicialização do volume do PostgreSQL.
- Para recriar bancos do zero, use `docker compose down -v` e suba novamente.