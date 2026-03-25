#!/bin/bash

# Script para rebuild dos serviços

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
    echo "Fazendo rebuild de todos os serviços..."
    "${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" build --no-cache
    echo ""
    echo "Build concluído!"
    echo "Iniciando serviços..."
    "${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" up -d
else
    echo "Fazendo rebuild do serviço: $SERVICE"
    "${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" build --no-cache "$SERVICE"
    echo ""
    echo "Build concluído!"
    echo "Reiniciando serviço..."
    "${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" up -d "$SERVICE"
fi

echo ""
echo "Status dos serviços:"
"${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" ps
