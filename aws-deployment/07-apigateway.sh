#!/bin/bash
# 07-apigateway.sh
# Purpose: Creates an HTTP API Gateway with a native JWT authorizer.
# Routes /users/auth/* are public (login & register).
# All other /users/* and /catalog/* routes require a valid JWT issued by users-api.
# Integrations point directly to the ECS task public IPs captured in infra-outputs.env.
# NOTE: If ECS task IPs change (new deployment or session restart), re-run this script
#       or use the update-integration commands at the bottom to patch only the IPs.

set -e
source ./infra-outputs.env

AWS_REGION="${AWS_REGION:-us-east-1}"

# JWT settings must match what users-api puts in the token
JWT_ISSUER="${JWT_ISSUER:-users-api}"
JWT_AUDIENCE="${JWT_AUDIENCE:-course-app}"

echo "==> [07] Creating API Gateway HTTP API..."

# Create the HTTP API
API_ID=$(aws apigatewayv2 create-api \
  --name course-api-gateway \
  --protocol-type HTTP \
  --cors-configuration \
    "AllowOrigins=*,AllowMethods=GET POST PUT DELETE OPTIONS,AllowHeaders=Authorization Content-Type" \
  --query 'ApiId' --output text)
echo "  API Gateway ID: $API_ID"

# JWT Authorizer — validates Bearer tokens on protected routes
AUTHORIZER_ID=$(aws apigatewayv2 create-authorizer \
  --api-id "$API_ID" \
  --name jwt-authorizer \
  --authorizer-type JWT \
  --identity-source '$request.header.Authorization' \
  --jwt-configuration "Issuer=$JWT_ISSUER,Audience=$JWT_AUDIENCE" \
  --query 'AuthorizerId' --output text)
echo "  Authorizer ID: $AUTHORIZER_ID"

# Integration — Users API (direct HTTP to ECS task IP)
USERS_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type HTTP_PROXY \
  --integration-method ANY \
  --integration-uri "http://$USERS_IP:8080/{proxy}" \
  --payload-format-version "1.0" \
  --query 'IntegrationId' --output text)
echo "  Users   integration ID: $USERS_INTEGRATION_ID"

# Integration — Catalog API
CATALOG_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type HTTP_PROXY \
  --integration-method ANY \
  --integration-uri "http://$CATALOG_IP:8080/{proxy}" \
  --payload-format-version "1.0" \
  --query 'IntegrationId' --output text)
echo "  Catalog integration ID: $CATALOG_INTEGRATION_ID"

# --- Routes ---

# Public routes: login and register do not require a JWT
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "POST /users/auth/login" \
  --target "integrations/$USERS_INTEGRATION_ID" > /dev/null

aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "POST /users/auth/register" \
  --target "integrations/$USERS_INTEGRATION_ID" > /dev/null

# Protected users routes (all other /users/* require JWT)
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "ANY /users/{proxy+}" \
  --authorization-type JWT \
  --authorizer-id "$AUTHORIZER_ID" \
  --target "integrations/$USERS_INTEGRATION_ID" > /dev/null

# Protected catalog routes (all /catalog/* require JWT)
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "ANY /catalog/{proxy+}" \
  --authorization-type JWT \
  --authorizer-id "$AUTHORIZER_ID" \
  --target "integrations/$CATALOG_INTEGRATION_ID" > /dev/null

# Deploy to the $default stage with auto-deploy enabled
aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name '$default' \
  --auto-deploy > /dev/null

GATEWAY_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com"
echo "  API Gateway URL: $GATEWAY_URL"

cat >> ./infra-outputs.env << EOF
API_ID=$API_ID
AUTHORIZER_ID=$AUTHORIZER_ID
USERS_INTEGRATION_ID=$USERS_INTEGRATION_ID
CATALOG_INTEGRATION_ID=$CATALOG_INTEGRATION_ID
GATEWAY_URL=$GATEWAY_URL
EOF

echo ""
echo "==> [07] API Gateway done."
echo ""
echo "Quick test commands:"
echo "  # Register (public)"
echo "  curl -X POST $GATEWAY_URL/users/auth/register -H 'Content-Type: application/json' -d '{\"email\":\"test@test.com\",\"password\":\"Test123!\"}'"
echo "  # Login and grab token"
echo "  TOKEN=\$(curl -s -X POST $GATEWAY_URL/users/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"test@test.com\",\"password\":\"Test123!\"}' | jq -r '.token')"
echo "  # Call catalog (protected)"
echo "  curl -X GET $GATEWAY_URL/catalog/products -H \"Authorization: Bearer \$TOKEN\""
