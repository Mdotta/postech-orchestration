#!/bin/bash

# Script para iniciar os serviços do Docker Compose

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${DOCKER_DIR}/docker-compose.yml"
ENV_FILE="${DOCKER_DIR}/.env"
ENV_EXAMPLE_FILE="${DOCKER_DIR}/.env.example"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
else
    echo "Docker Compose nao encontrado. Instale docker compose ou docker-compose."
    exit 1
fi

echo "Iniciando serviços Postech..."

# Verifica se o arquivo .env existe
if [ ! -f "${ENV_FILE}" ]; then
    echo "Arquivo .env não encontrado!"
    echo "Copiando .env.example para .env..."
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    echo "IMPORTANTE: Edite o arquivo .env e configure as senhas antes de usar em produção!"
    echo ""
fi

# Inicia os serviços
"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d

echo ""
echo "Serviços iniciados com sucesso!"
echo ""
echo "Status dos serviços:"
"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps
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
