#!/bin/bash

# Script para verificar o status dos serviços

echo "Status dos serviços Postech:"
echo ""

docker-compose ps

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
