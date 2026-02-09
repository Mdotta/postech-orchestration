#!/bin/bash

# Script para iniciar os serviços do Docker Compose

set -e

echo "Iniciando serviços Postech..."

# Verifica se o arquivo .env existe
if [ ! -f .env ]; then
    echo "Arquivo .env não encontrado!"
    echo "Copiando .env.example para .env..."
    cp .env.example .env
    echo "IMPORTANTE: Edite o arquivo .env e configure as senhas antes de usar em produção!"
    echo ""
fi

# Inicia os serviços
docker-compose up -d

echo ""
echo "Serviços iniciados com sucesso!"
echo ""
echo "Status dos serviços:"
docker-compose ps
echo ""
echo "Serviços disponíveis:"
echo "  - PostgreSQL: localhost:5432"
echo "  - PgAdmin: http://localhost:5050"
echo "  - RabbitMQ: localhost:5672"
echo "  - RabbitMQ Management: http://localhost:15672"
echo "  - Redis: localhost:6379"
echo "  - Users API: http://localhost:8080"
echo "  - Users API Metrics: http://localhost:8181"
echo ""
echo "Para ver os logs: scripts/logs.sh"
echo "Para parar os serviços: scripts/stop.sh"
