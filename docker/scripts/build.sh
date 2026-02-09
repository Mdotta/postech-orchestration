#!/bin/bash

# Script para rebuild dos serviços

set -e

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "Fazendo rebuild de todos os serviços..."
    docker-compose build --no-cache
    echo ""
    echo "Build concluído!"
    echo "Iniciando serviços..."
    docker-compose up -d
else
    echo "Fazendo rebuild do serviço: $SERVICE"
    docker-compose build --no-cache "$SERVICE"
    echo ""
    echo "Build concluído!"
    echo "Reiniciando serviço..."
    docker-compose up -d "$SERVICE"
fi

echo ""
echo "Status dos serviços:"
docker-compose ps
