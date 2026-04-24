#!/bin/bash
set -euo pipefail

# =============================================================================
# setup-api-gateway.sh
# Creates (or updates) a single shared HTTP API Gateway with Cognito JWT
# authorization in front of ALL postech microservices.
# Safe to re-run — skips already existing resources.
#
# Services covered:
#   users-api   → EC2 instance tagged "postech-users-api"
#   catalog-api → EC2 instance tagged "postech-catalog-api"
#
# Usage:
#   ./aws/setup-api-gateway.sh
#
# Required environment variables:
#   AWS_ACCOUNT_ID  - Your AWS account ID
#   JWT_ISSUER      - Cognito issuer URL
#                     (e.g. https://cognito-idp.us-east-1.amazonaws.com/<pool-id>)
#   JWT_AUDIENCE    - Cognito App Client ID
#
# Optional:
#   AWS_REGION      - Defaults to us-east-1
#   API_NAME        - Defaults to postech-gateway
#   STAGE_NAME      - Defaults to prod
# =============================================================================

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?❌ AWS_ACCOUNT_ID is not set}"
JWT_ISSUER="${JWT_ISSUER:?❌ JWT_ISSUER is not set}"
JWT_AUDIENCE="${JWT_AUDIENCE:?❌ JWT_AUDIENCE is not set}"

AWS_REGION="${AWS_REGION:-us-east-1}"
API_NAME="${API_NAME:-postech-gateway}"
STAGE_NAME="${STAGE_NAME:-prod}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/deployment.env"

log()  { echo "[$(date '+%H:%M:%S')] $*" >&2; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*" >&2; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*" >&2; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

set_env_var() {
  local KEY="$1" VAL="$2"
  touch "$ENV_FILE"
  grep -v "^${KEY}=" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || true
  echo "export ${KEY}='${VAL}'" >> "${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
}

command -v aws &>/dev/null || fail "aws CLI is not installed"

# =============================================================================
# Resolve EC2 instances
# =============================================================================
resolve_ec2_ip() {
  local TAG_NAME="$1"
  local IP
  IP=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$TAG_NAME" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null) || IP=""
  [[ -n "$IP" && "$IP" != "None" ]] || { warn "No running EC2 tagged '$TAG_NAME' found — skipping its routes."; echo ""; return; }
  echo "$IP"
}

log "Resolving EC2 instances..."
USERS_IP=$(resolve_ec2_ip "postech-users-api")
CATALOG_IP=$(resolve_ec2_ip "postech-catalog-api")

[[ -n "$USERS_IP" ]] && ok "users-api  → http://$USERS_IP" || warn "users-api EC2 not found"
[[ -n "$CATALOG_IP" ]] && ok "catalog-api → http://$CATALOG_IP" || warn "catalog-api EC2 not found"

[[ -n "$USERS_IP" || -n "$CATALOG_IP" ]] || fail "No EC2 instances found. Deploy at least one service before running this script."

log "JWT Issuer  : $JWT_ISSUER"
log "JWT Audience: $JWT_AUDIENCE"

# =============================================================================
# Step 1: Create or reuse HTTP API
# =============================================================================
log "Checking for existing API Gateway '$API_NAME'..."
EXISTING_API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='$API_NAME'].ApiId" \
  --output text)

if [[ -n "$EXISTING_API_ID" && "$EXISTING_API_ID" != "None" ]]; then
  log "API '$API_NAME' already exists (ID: $EXISTING_API_ID), reusing."
  API_ID="$EXISTING_API_ID"
else
  API_ID=$(aws apigatewayv2 create-api \
    --region "$AWS_REGION" \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --query 'ApiId' --output text)
  ok "API created: $API_ID"
  sleep 5
fi

# =============================================================================
# Step 2: Create or reuse JWT Authorizer
# =============================================================================
log "Checking for existing JWT Authorizer..."
EXISTING_AUTHORIZER_ID=$(aws apigatewayv2 get-authorizers \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query "Items[?Name=='JwtAuthorizer'].AuthorizerId" \
  --output text)

if [[ -n "$EXISTING_AUTHORIZER_ID" && "$EXISTING_AUTHORIZER_ID" != "None" ]]; then
  log "Authorizer already exists (ID: $EXISTING_AUTHORIZER_ID), reusing."
  AUTHORIZER_ID="$EXISTING_AUTHORIZER_ID"
else
  MAX_RETRIES=5; ATTEMPT=1
  while [[ $ATTEMPT -le $MAX_RETRIES ]]; do
    log "Attempt $ATTEMPT/$MAX_RETRIES to create authorizer..."
    AUTHORIZER_ID=$(aws apigatewayv2 create-authorizer \
      --region "$AWS_REGION" \
      --api-id "$API_ID" \
      --authorizer-type JWT \
      --name JwtAuthorizer \
      --identity-source '$request.header.Authorization' \
      --jwt-configuration "{\"Audience\":[\"$JWT_AUDIENCE\"],\"Issuer\":\"$JWT_ISSUER\"}" \
      --query 'AuthorizerId' --output text 2>&1) && break
    sleep 10; ATTEMPT=$((ATTEMPT + 1))
  done
  [[ $ATTEMPT -gt $MAX_RETRIES ]] && fail "Failed to create authorizer after $MAX_RETRIES attempts."
  ok "Authorizer created: $AUTHORIZER_ID"
fi

# =============================================================================
# Step 3: Create or update integrations (one per service)
# =============================================================================
create_or_update_integration() {
  local LABEL="$1"
  local TARGET_IP="$2"

  [[ -z "$TARGET_IP" || "$TARGET_IP" == "None" ]] && { warn "Skipping integration for $LABEL (no IP)."; echo ""; return; }

  local EXISTING_ID
  EXISTING_ID=$(aws apigatewayv2 get-integrations \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --query "Items[?Description=='$LABEL'].IntegrationId" \
    --output text 2>/dev/null) || EXISTING_ID=""

  if [[ -n "$EXISTING_ID" && "$EXISTING_ID" != "None" ]]; then
    log "Integration for $LABEL exists ($EXISTING_ID), updating URI..."
    aws apigatewayv2 update-integration \
      --api-id "$API_ID" \
      --integration-id "$EXISTING_ID" \
      --integration-uri "http://$TARGET_IP" \
      --request-parameters '{"overwrite:path": "$request.path"}' \
      --region "$AWS_REGION" > /dev/null
    ok "Integration for $LABEL updated → http://$TARGET_IP"
    echo "$EXISTING_ID"
  else
    local INT_ID
    INT_ID=$(aws apigatewayv2 create-integration \
      --region "$AWS_REGION" \
      --api-id "$API_ID" \
      --integration-type HTTP_PROXY \
      --integration-uri "http://$TARGET_IP" \
      --integration-method ANY \
      --payload-format-version "1.0" \
      --description "$LABEL" \
      --request-parameters '{"overwrite:path": "$request.path"}' \
      --query 'IntegrationId' --output text)
    ok "Integration for $LABEL created: $INT_ID → http://$TARGET_IP"
    echo "$INT_ID"
  fi
}

log "Setting up integrations..."
USERS_INTEGRATION_ID=$(create_or_update_integration "users-api" "$USERS_IP")
CATALOG_INTEGRATION_ID=$(create_or_update_integration "catalog-api" "$CATALOG_IP")

# =============================================================================
# Step 4: Create routes
# =============================================================================
create_route_if_not_exists() {
  local ROUTE_KEY="$1"
  local AUTH_TYPE="$2"
  local INTEGRATION_ID="$3"

  [[ -z "$INTEGRATION_ID" || "$INTEGRATION_ID" == "None" ]] && { warn "Skipping route '$ROUTE_KEY' — no integration available."; return; }

  local EXISTING
  EXISTING=$(aws apigatewayv2 get-routes \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --query "Items[?RouteKey=='$ROUTE_KEY'].RouteId" \
    --output text)

  if [[ -n "$EXISTING" && "$EXISTING" != "None" ]]; then
    log "Route '$ROUTE_KEY' already exists, skipping."
    return
  fi

  if [[ "$AUTH_TYPE" == "JWT" ]]; then
    aws apigatewayv2 create-route \
      --region "$AWS_REGION" \
      --api-id "$API_ID" \
      --route-key "$ROUTE_KEY" \
      --authorization-type JWT \
      --authorizer-id "$AUTHORIZER_ID" \
      --target "integrations/$INTEGRATION_ID" > /dev/null
  else
    aws apigatewayv2 create-route \
      --region "$AWS_REGION" \
      --api-id "$API_ID" \
      --route-key "$ROUTE_KEY" \
      --target "integrations/$INTEGRATION_ID" > /dev/null
  fi
  ok "Route created: $ROUTE_KEY ($AUTH_TYPE)"
}

delete_route_if_exists() {
  local ROUTE_KEY="$1"
  local ROUTE_ID

  ROUTE_ID=$(aws apigatewayv2 get-routes \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --query "Items[?RouteKey=='$ROUTE_KEY'].RouteId" \
    --output text)

  if [[ -n "$ROUTE_ID" && "$ROUTE_ID" != "None" ]]; then
    aws apigatewayv2 delete-route \
      --api-id "$API_ID" \
      --route-id "$ROUTE_ID" \
      --region "$AWS_REGION" > /dev/null
    ok "Removed legacy route: $ROUTE_KEY"
  fi
}

log "Creating routes..."

# Remove legacy users-api route keys with /api prefix
delete_route_if_exists "GET /api/users/{proxy+}"
delete_route_if_exists "PATCH /api/users/{proxy+}"

# --- users-api routes ---------------------------------------------------------
# $default catches: POST /auth/*, GET /health, scalar/openapi docs
create_route_if_not_exists '$default'                "NONE" "$USERS_INTEGRATION_ID"
create_route_if_not_exists "GET /users/{proxy+}" "JWT"  "$USERS_INTEGRATION_ID"
create_route_if_not_exists "PATCH /users/{proxy+}" "JWT" "$USERS_INTEGRATION_ID"

# --- catalog-api routes -------------------------------------------------------
create_route_if_not_exists "GET /game"                  "NONE" "$CATALOG_INTEGRATION_ID"
create_route_if_not_exists "POST /game"                 "JWT"  "$CATALOG_INTEGRATION_ID"
create_route_if_not_exists "GET /game/{proxy+}"         "JWT"  "$CATALOG_INTEGRATION_ID"
create_route_if_not_exists "POST /game/{proxy+}"        "JWT"  "$CATALOG_INTEGRATION_ID"
create_route_if_not_exists "PATCH /game/{proxy+}"       "JWT"  "$CATALOG_INTEGRATION_ID"
create_route_if_not_exists "DELETE /game/{proxy+}"      "JWT"  "$CATALOG_INTEGRATION_ID"

# =============================================================================
# Step 5: Create stage
# =============================================================================
log "Checking stage '$STAGE_NAME'..."
EXISTING_STAGE=$(aws apigatewayv2 get-stages \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query "Items[?StageName=='$STAGE_NAME'].StageName" \
  --output text)

if [[ -n "$EXISTING_STAGE" && "$EXISTING_STAGE" != "None" ]]; then
  log "Stage '$STAGE_NAME' already exists, skipping."
else
  aws apigatewayv2 create-stage \
    --region "$AWS_REGION" \
    --api-id "$API_ID" \
    --stage-name "$STAGE_NAME" \
    --auto-deploy > /dev/null
  ok "Stage '$STAGE_NAME' created with auto-deploy"
fi

# =============================================================================
# Done
# =============================================================================
API_ENDPOINT=$(aws apigatewayv2 get-api \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query 'ApiEndpoint' --output text)

INVOKE_URL="$API_ENDPOINT/$STAGE_NAME"

# --- Save deployment variables -----------------------------------------------
set_env_var "API_GATEWAY_ID"       "$API_ID"
set_env_var "API_GATEWAY_ENDPOINT" "$INVOKE_URL"

echo ""
echo "🚀 API Gateway setup complete!"
echo ""
echo "   API ID      : $API_ID"
echo "   Invoke URL  : $INVOKE_URL"
echo "   JWT Issuer  : $JWT_ISSUER"
echo "   JWT Audience: $JWT_AUDIENCE"
[[ -n "$USERS_IP" ]]   && echo "   users-api   : http://$USERS_IP"
[[ -n "$CATALOG_IP" ]] && echo "   catalog-api : http://$CATALOG_IP"
echo ""
echo "📋 Test commands:"
echo ""
echo "  # Health check (public)"
echo "  curl $INVOKE_URL/health"
echo ""
echo "  # Login"
echo "  TOKEN=\$(curl -s -X POST $INVOKE_URL/auth/login \\" 
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@test.com\",\"password\":\"Test@1234\"}' | jq -r '.token')"
echo ""
echo "  # List games (public)"
echo "  curl $INVOKE_URL/game"
echo ""
echo "  # Place order (protected)"
echo "  curl -X POST $INVOKE_URL/game/create-order \\"
  echo "    -H \"Authorization: Bearer \$TOKEN\" \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"gameId\":\"<game-id>\"}'"
echo ""
echo "📋 Deployment variables saved → $ENV_FILE"
echo "   source $ENV_FILE"
