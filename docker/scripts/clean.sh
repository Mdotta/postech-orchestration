#!/bin/bash

# Script para limpar completamente o ambiente Docker

set -e

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
docker-compose down

echo ""
echo "Removendo volumes..."
docker-compose down -v

echo ""
echo "Removendo imagens buildadas..."
docker-compose down --rmi local

echo ""
echo "Ambiente limpo com sucesso!"
echo ""
echo "Para iniciar novamente: scripts/start.sh"
