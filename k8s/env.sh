#!/bin/bash

#  Configuração do ambiente Kubernetes - FIAP Cloud Games
#  Edite este arquivo com os valores do seu cluster

# IP do LoadBalancer (MetalLB ou cloud provider)
# Exemplo local:  192.168.13.20
# Exemplo AKS:    obtenha com: kubectl get svc -n ingress-nginx
export LOAD_BALANCER_IP="127.0.0.1"

# Domínio base (nip.io resolve automaticamente para o IP)
# Para produção troque por seu domínio real: ex. meudominio.com.br
export BASE_DOMAIN="${LOAD_BALANCER_IP}.nip.io"

# Docker Hub username (dono das imagens)
export DOCKER_USER="seuUsuario"

# Tag das imagens
export IMAGE_TAG="v1"

#  NÃO EDITE ABAIXO DESTA LINHA

export USERS_API_IMAGE="${DOCKER_USER}/users-api:${IMAGE_TAG}"
export CATALOG_API_IMAGE="${DOCKER_USER}/catalog-api:${IMAGE_TAG}"
export PAYMENTS_API_IMAGE="${DOCKER_USER}/payments-api:${IMAGE_TAG}"
export NOTIFICATIONS_API_IMAGE="${DOCKER_USER}/notifications-api:${IMAGE_TAG}"

export USERS_API_HOST="users-api.${BASE_DOMAIN}"
export CATALOG_API_HOST="catalog-api.${BASE_DOMAIN}"
export PAYMENTS_API_HOST="payments-api.${BASE_DOMAIN}"
export NOTIFICATIONS_API_HOST="notifications-api.${BASE_DOMAIN}"
