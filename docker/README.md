# Ambiente de Desenvolvimento - FIAP Cloud Games (Tech Challenge)

Docker compose contendo configuração dos containeres de dependências dos serviços da fase 2 + containeres utilizando versão latest dos serviços locais

## Serviços Incluídos

### PostgreSQL (porta 5432)
- **Usuário:** postech_admin
- **Senha:** postech_dev_password
- **Databases criados automaticamente:**
  - `postech_users` - Microsserviço de Usuários
  - `postech_catalog` - Microsserviço de Catálogo
  - `postech_payments` - Microsserviço de Pagamentos
  - `postech_notifications` - Microsserviço de Notificações

### PgAdmin (porta 5050)
Interface web para gerenciar o PostgreSQL
- **URL:** http://localhost:5050
- **Email:** admin@postech.com
- **Senha:** admin123

### RabbitMQ (portas 5672 e 15672)
Message broker para comunicação entre microsserviços
- **AMQP URL:** amqp://postech_user:postech_rabbit_password@localhost:5672
- **Management UI:** http://localhost:15672
- **Usuário:** postech_user
- **Senha:** postech_rabbit_password

### Redis (porta 6379)
Cache para tokens JWT e sessões (opcional)
- **URL:** redis://localhost:6379

## Pré-requisitos

- Docker Desktop instalado
- Docker Compose instalado

## Scripts de Gerenciamento

Para facilitar o uso, foram criados scripts bash na pasta `scripts/` que automatizam as operações mais comuns:

### `scripts/start.sh`
Inicia todos os serviços. Se o arquivo `.env` não existir, cria automaticamente a partir do `.env.example`.
```bash
scripts/start.sh
```

### `scripts/stop.sh`
Para todos os serviços (preserva os volumes/dados).
```bash
scripts/stop.sh
```

### `scripts/restart.sh`
Reinicia todos os serviços.
```bash
scripts/restart.sh
```

### `scripts/logs.sh`
Exibe os logs dos serviços em tempo real.
```bash
# Ver logs de todos os serviços
scripts/logs.sh

# Ver logs de um serviço específico
scripts/logs.sh postgres
scripts/logs.sh postech-users-api
```

### `scripts/build.sh`
Faz rebuild dos serviços (útil após alterações no código).
```bash
# Rebuild de todos os serviços
scripts/build.sh

# Rebuild de um serviço específico
scripts/build.sh postech-users-api
```

### `scripts/status.sh`
Verifica o status e health dos serviços.
```bash
scripts/status.sh
```

### `scripts/clean.sh`
**CUIDADO:** Remove tudo (containers, volumes e dados). Use com cautela!
```bash
scripts/clean.sh
```

## Como usar

### Subir todos os serviços
```bash
cd docker
scripts/start.sh
# ou
docker-compose up -d
```

### Ver logs de todos os serviços
```bash
scripts/logs.sh
# ou
docker-compose logs -f
```

### Ver logs de um serviço específico
```bash
scripts/logs.sh postgres
scripts/logs.sh rabbitmq
# ou
docker-compose logs -f postgres
docker-compose logs -f rabbitmq
```

### Parar todos os serviços
```bash
scripts/stop.sh
# ou
docker-compose down
```

### Parar e remover volumes (apaga todos os dados)
```bash
scripts/clean.sh
# ou
docker-compose down -v
```

### Verificar status dos serviços
```bash
scripts/status.sh
# ou
docker-compose ps
```

## Connection Strings para os Microsserviços

### UsersAPI
```
Host=localhost;Port=5432;Database=postech_users;Username=postech_admin;Password=postech_dev_password
```

### CatalogAPI
```
Host=localhost;Port=5432;Database=postech_catalog;Username=postech_admin;Password=postech_dev_password
```

### PaymentsAPI
```
Host=localhost;Port=5432;Database=postech_payments;Username=postech_admin;Password=postech_dev_password
```

### NotificationsAPI
```
Host=localhost;Port=5432;Database=postech_notifications;Username=postech_admin;Password=postech_dev_password
```

### RabbitMQ Connection
```
amqp://postech_user:postech_rabbit_password@localhost:5672
```

## Notas Importantes

- **Senhas:** As senhas neste arquivo são apenas para desenvolvimento local.
- **Volumes:** Os dados são persistidos em volumes Docker. Use `docker-compose down -v` para apagar tudo.
- **Network:** Todos os serviços estão na mesma network `postech-network` para facilitar comunicação.
- **Healthchecks:** Todos os serviços tem healthchecks configurados para garantir que estão prontos antes de serem usados.

## Repositórios dos Microsserviços

- **postech-users-api** - Cadastro, autenticação (JWT) e autorização
- **postech-catalog-api** - CRUD de jogos e início do fluxo de compra
- **postech-payments-api** - Processamento de pagamentos
- **postech-notifications-api** - Envio de e-mails (boas-vindas e confirmação de compra)