#!/bin/bash
# 02-ecr-push.sh
# Purpose: Creates ECR repositories for users-api and catalog-api,
# authenticates Docker to ECR, then builds and pushes both images.
# Edit the USERS_API_PATH and CATALOG_API_PATH variables below to point
# to your local clones of each API repository.
# After the first run, images are persisted in ECR between Academy sessions —
# you can skip the build/push steps and only update INFRA_OUTPUTS.

set -e
source ./infra-outputs.env

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# --- CONFIGURE THESE PATHS ---
USERS_API_PATH="${USERS_API_PATH:-/path/to/users-api}"
CATALOG_API_PATH="${CATALOG_API_PATH:-/path/to/catalog-api}"
# ----------------------------

echo "==> [02] Setting up ECR and pushing images..."

ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Create ECR repositories (safe to re-run; will skip if they already exist)
aws ecr create-repository --repository-name users-api   --region "$AWS_REGION" 2>/dev/null || echo "  users-api repo already exists"
aws ecr create-repository --repository-name catalog-api --region "$AWS_REGION" 2>/dev/null || echo "  catalog-api repo already exists"

# Authenticate Docker to ECR
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Build and push Users API
cd "$USERS_API_PATH"
docker build -t users-api:latest .
docker tag  users-api:latest "$ECR_REGISTRY/users-api:latest"
docker push "$ECR_REGISTRY/users-api:latest"
echo "  Users API pushed: $ECR_REGISTRY/users-api:latest"

# Build and push Catalog API
cd "$CATALOG_API_PATH"
docker build -t catalog-api:latest .
docker tag  catalog-api:latest "$ECR_REGISTRY/catalog-api:latest"
docker push "$ECR_REGISTRY/catalog-api:latest"
echo "  Catalog API pushed: $ECR_REGISTRY/catalog-api:latest"

# Append registry info to outputs
cat >> ./infra-outputs.env << EOF
ECR_REGISTRY=$ECR_REGISTRY
EOF

echo "==> [02] ECR push done."
