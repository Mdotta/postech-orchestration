#!/bin/bash

# Script para visualizar logs dos serviços

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${DOCKER_DIR}/docker-compose.yml"
ENV_FILE="${DOCKER_DIR}/.env"
COMPOSE_ARGS=( -f "${COMPOSE_FILE}" )

if [ -f "${ENV_FILE}" ]; then
    COMPOSE_ARGS+=( --env-file "${ENV_FILE}" )
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
else
    echo "Docker Compose nao encontrado. Instale docker compose ou docker-compose."
    exit 1
fi

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "Exibindo logs de todos os serviços..."
    echo "Dica: Use 'scripts/logs.sh <nome-do-servico>' para ver logs específicos"
    echo "   Serviços disponíveis: postgres, pgadmin, rabbitmq, redis, postech-users-api"
    echo ""
    "${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" logs -f
else
    echo "Exibindo logs do serviço: $SERVICE"
    echo ""
    "${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" logs -f "$SERVICE"
fi
