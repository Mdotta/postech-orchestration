#!/bin/bash

# =============================================================
#  Deploy completo no Kubernetes - FIAP Cloud Games
#  Execute a partir da pasta k8s/
# =============================================================

set -e

# Carregar configurações do ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"

echo "=================================================="
echo "  Deploy Postech - FIAP Cloud Games"
echo "  LoadBalancer IP: $LOAD_BALANCER_IP"
echo "  Imagens: $DOCKER_USER/*:$IMAGE_TAG"
echo "=================================================="
echo ""

# Verificar se kubectl está configurado
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ kubectl não está configurado ou cluster inacessível."
  echo "   Configure o ~/.kube/config antes de continuar."
  exit 1
fi

# 1. Namespaces
echo "[1/5] Criando namespaces..."
kubectl apply -f "$SCRIPT_DIR/../namespace.yaml"
echo ""

# 2. Infraestrutura
echo "[2/5] Subindo infraestrutura (PostgreSQL, RabbitMQ, Redis)..."
kubectl apply -f "$SCRIPT_DIR/../infrastructure/postgresql.yaml"
kubectl apply -f "$SCRIPT_DIR/../infrastructure/rabbitmq.yaml"
kubectl apply -f "$SCRIPT_DIR/../infrastructure/redis.yaml"
echo ""
echo "Aguardando PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgresql -n infrastructure --timeout=120s
echo "Aguardando RabbitMQ..."
kubectl wait --for=condition=ready pod -l app=rabbitmq -n infrastructure --timeout=180s
echo "Aguardando Redis..."
kubectl wait --for=condition=ready pod -l app=redis -n infrastructure --timeout=60s
echo ""

# 3. Microsserviços com substituição de variáveis
echo "[3/5] Fazendo deploy dos microsserviços..."

for SERVICE in users-api catalog-api payments-api notifications-api; do
  FILE="$SCRIPT_DIR/../${SERVICE}/${SERVICE}.yaml"
  echo "  -> $SERVICE"
  LOAD_BALANCER_IP=$LOAD_BALANCER_IP \
  BASE_DOMAIN=$BASE_DOMAIN \
  DOCKER_USER=$DOCKER_USER \
  IMAGE_TAG=$IMAGE_TAG \
  envsubst < "$FILE" | kubectl apply -f -
done
echo ""

# 4. Aguardar microsserviços
echo "[4/5] Aguardando microsserviços subirem..."
for SERVICE in users-api catalog-api payments-api notifications-api; do
  kubectl wait --for=condition=ready pod -l app=$SERVICE -n gamestore --timeout=120s
done
echo ""

# 5. Status final
echo "[5/5] Status do deploy:"
echo ""
echo "--- Infraestrutura ---"
kubectl get pods -n infrastructure
echo ""
echo "--- Microsserviços ---"
kubectl get pods -n gamestore
echo ""
echo "--- Ingresses ---"
kubectl get ingress -n gamestore
echo ""
echo "=================================================="
echo "  ✅ Deploy concluído!"
echo "=================================================="
echo ""
echo "URLs dos serviços:"
echo "  Users API:         http://$USERS_API_HOST"
echo "  Catalog API:       http://$CATALOG_API_HOST"
echo "  Payments API:      http://$PAYMENTS_API_HOST"
echo "  Notifications API: http://$NOTIFICATIONS_API_HOST"
echo ""
