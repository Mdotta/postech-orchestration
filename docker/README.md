# Ambiente de Desenvolvimento - FIAP Cloud Games (Tech Challenge)

Este repositório contém a infraestrutura de desenvolvimento para o projeto Tech Challenge.

## Estrutura do Repositório

```
postech-infrastructure/
├── docker/
│   ├── docker-compose.yml          # Orquestração local com Docker Compose
│   ├── init-scripts/
│   │   └── 01-init-databases.sql   # Script de inicialização do PostgreSQL
│   └── README.md                    # Este arquivo
└── k8s/                             # Manifestos Kubernetes (a ser criado)
```

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

## Como usar

### Subir todos os serviços
```bash
cd docker
docker-compose up -d
```

### Ver logs de todos os serviços
```bash
docker-compose logs -f
```

### Ver logs de um serviço específico
```bash
docker-compose logs -f postgres
docker-compose logs -f rabbitmq
```

### Parar todos os serviços
```bash
docker-compose down
```

### Parar e remover volumes (apaga todos os dados)
```bash
docker-compose down -v
```

### Verificar status dos serviços
```bash
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
- **Healthchecks:** Todos os serviços têm healthchecks configurados para garantir que estão prontos antes de serem usados.

## Próximos Passos

1. Subir o ambiente: `docker-compose up -d`
2. Verificar se todos os serviços estão rodando: `docker-compose ps`
3. Acessar o PgAdmin e configurar a conexão com o PostgreSQL
4. Acessar o RabbitMQ Management para verificar as filas
5. Começar a desenvolver os microsserviços!

## Repositórios dos Microsserviços

- **postech-users-api** - Cadastro, autenticação (JWT) e autorização
- **postech-catalog-api** - CRUD de jogos e início do fluxo de compra
- **postech-payments-api** - Processamento de pagamentos
- **postech-notifications-api** - Envio de e-mails (boas-vindas e confirmação de compra)