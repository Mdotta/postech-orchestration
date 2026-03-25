#!/bin/bash

# Script para verificar o status dos serviços

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

echo "Status dos serviços Postech:"
echo ""

"${COMPOSE_CMD[@]}" "${COMPOSE_ARGS[@]}" ps

echo ""
echo "Health checks:"
echo ""

# Verifica cada serviço
services=("postgres" "rabbitmq" "redis" "postech-users-api")

for service in "${services[@]}"; do
    health=$(docker inspect --format='{{.State.Health.Status}}' postech-$service 2>/dev/null || echo "not available")
    if [ "$health" != "not available" ]; then
        case $health in
            "healthy")
                echo "  [OK] $service: $health"
                ;;
            "unhealthy")
                echo "  [FAIL] $service: $health"
                ;;
            *)
                echo "  [WAIT] $service: $health"
                ;;
        esac
    else
        # Verifica se o container está rodando
        running=$(docker inspect --format='{{.State.Running}}' postech-$service 2>/dev/null || echo "false")
        if [ "$running" = "true" ]; then
            echo "  [OK] $service: running (no health check)"
        else
            echo "  [FAIL] $service: not running"
        fi
    fi
done
