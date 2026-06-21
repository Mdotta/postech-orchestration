#!/bin/bash
set -euo pipefail

# =============================================================================
# update-api-gateway-eks.sh
# Updates API Gateway integrations to point to the EKS ALB DNS.
# Run after: kubectl apply -f k8s/ingress.yaml
#            (wait ~2 min for ALB to provision)
#
# Usage:
#   ./aws/update-api-gateway-eks.sh
# =============================================================================

AWS_REGION="${AWS_REGION:-us-east-1}"
API_NAME="${API_NAME:-tf-postech-gateway}"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

command -v kubectl &>/dev/null || fail "kubectl is not installed"
command -v aws      &>/dev/null || fail "aws CLI is not installed"

# ── Get ALB DNS ─────────────────────────────────────────────────────────────
log "Getting ALB DNS from Ingress..."
ALB_DNS=$(kubectl get ingress postech-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null) || ALB_DNS=""

if [ -z "$ALB_DNS" ]; then
  fail "Ingress hostname not found. Wait for ALB provisioning, then retry."
fi

log "ALB DNS: $ALB_DNS"

# ── Find API Gateway ────────────────────────────────────────────────────────
log "Looking up API Gateway..."
API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='$API_NAME'].ApiId" \
  --output text 2>/dev/null) || API_ID=""

if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  fail "API Gateway '$API_NAME' not found."
fi

ok "API Gateway ID: $API_ID"

# ── Update integrations ─────────────────────────────────────────────────────
ALB_URI="http://$ALB_DNS"

log "Updating users-api integration..."
USERS_INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query "Items[?contains(IntegrationUri, 'users')].IntegrationId" \
  --output text 2>/dev/null) || USERS_INTEGRATION_ID=""

if [ -n "$USERS_INTEGRATION_ID" ] && [ "$USERS_INTEGRATION_ID" != "None" ]; then
  aws apigatewayv2 update-integration \
    --api-id "$API_ID" \
    --integration-id "$USERS_INTEGRATION_ID" \
    --integration-uri "$ALB_URI" \
    --request-parameters '{"overwrite:path":"$request.path","append:header.X-User-Id":"$context.authorizer.jwt.claims.sub","append:header.X-User-Name":"$context.authorizer.jwt.claims.email"}' \
    --region "$AWS_REGION" > /dev/null
  ok "users-api integration updated → $ALB_URI"
else
  log "users-api integration not found, skipping."
fi

log "Updating catalog-api integration..."
CATALOG_INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query "Items[?contains(IntegrationUri, 'catalog')].IntegrationId" \
  --output text 2>/dev/null) || CATALOG_INTEGRATION_ID=""

if [ -n "$CATALOG_INTEGRATION_ID" ] && [ "$CATALOG_INTEGRATION_ID" != "None" ]; then
  aws apigatewayv2 update-integration \
    --api-id "$API_ID" \
    --integration-id "$CATALOG_INTEGRATION_ID" \
    --integration-uri "$ALB_URI" \
    --request-parameters '{"overwrite:path":"$request.path","append:header.X-User-Id":"$context.authorizer.jwt.claims.sub","append:header.X-User-Name":"$context.authorizer.jwt.claims.email"}' \
    --region "$AWS_REGION" > /dev/null
  ok "catalog-api integration updated → $ALB_URI"
else
  log "catalog-api integration not found, skipping."
fi

echo ""
echo "🚀 API Gateway updated!"
echo "   Invoke URL: $(aws apigatewayv2 get-api --api-id $API_ID --region $AWS_REGION --query 'ApiEndpoint' --output text)"
echo ""
echo "   Verify: curl \$(terraform output -raw api_gateway_invoke_url)/health"
