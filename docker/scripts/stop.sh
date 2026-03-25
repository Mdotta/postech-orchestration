#!/bin/bash

# Script para parar os serviços do Docker Compose

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

echo "Parando serviços Postech..."

"${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" down

echo ""
echo "Serviços parados com sucesso!"
echo ""
echo "Dica: Os dados foram preservados nos volumes."
echo "   Para remover os volumes também, use: scripts/clean.sh"
