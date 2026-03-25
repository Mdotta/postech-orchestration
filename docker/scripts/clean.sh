#!/bin/bash

# Script para limpar completamente o ambiente Docker

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

echo "Limpando ambiente Postech..."
echo ""
echo "ATENÇÃO: Este script irá:"
echo "   - Parar todos os containers"
echo "   - Remover todos os containers"
echo "   - Remover todos os volumes (TODOS OS DADOS SERÃO PERDIDOS)"
echo "   - Remover as imagens buildadas"
echo ""
read -p "Tem certeza que deseja continuar? (s/N): " confirm

if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo "Parando e removendo containers..."
"${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" down

echo ""
echo "Removendo volumes..."
"${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" down -v

echo ""
echo "Removendo imagens buildadas..."
"${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" down --rmi local

echo ""
echo "Ambiente limpo com sucesso!"
echo ""
echo "Para iniciar novamente: scripts/start.sh"
