#!/bin/bash

# Script para parar os serviços do Docker Compose

set -e

echo "Parando serviços Postech..."

docker-compose down

echo ""
echo "Serviços parados com sucesso!"
echo ""
echo "Dica: Os dados foram preservados nos volumes."
echo "   Para remover os volumes também, use: scripts/clean.sh"
