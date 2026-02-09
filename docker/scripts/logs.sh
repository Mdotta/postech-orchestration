#!/bin/bash

# Script para visualizar logs dos serviços

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "Exibindo logs de todos os serviços..."
    echo "Dica: Use 'scripts/logs.sh <nome-do-servico>' para ver logs específicos"
    echo "   Serviços disponíveis: postgres, pgadmin, rabbitmq, redis, postech-users-api"
    echo ""
    docker-compose logs -f
else
    echo "Exibindo logs do serviço: $SERVICE"
    echo ""
    docker-compose logs -f "$SERVICE"
fi
