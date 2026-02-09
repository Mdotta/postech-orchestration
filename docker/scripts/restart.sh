#!/bin/bash

# Script para reiniciar os serviços do Docker Compose

set -e

echo "Reiniciando serviços Postech..."

docker-compose restart

echo ""
echo "Serviços reiniciados com sucesso!"
echo ""
docker-compose ps
