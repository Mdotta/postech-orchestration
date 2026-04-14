#!/bin/bash
# redeploy.sh
# Purpose: Master script that re-runs the entire deployment pipeline in the
# correct order.  Run this at the start of every AWS Academy session because
# all resources (VPC, RDS, ECS tasks) are destroyed when the session ends.
# ECR images persist between sessions, so the Docker build/push step in
# 02-ecr-push.sh is skipped after the first run (set SKIP_ECR_PUSH=true).
#
# Required environment variables (export before running, or set in a .env file):
#   AWS_REGION        — defaults to us-east-1
#   DB_PASSWORD       — PostgreSQL master password (never commit a real value)
#   JWT_KEY           — 256-bit secret used by users-api to sign JWTs
#   JWT_ISSUER        — must match the issuer claim in JWTs (default: users-api)
#   JWT_AUDIENCE      — must match the audience claim in JWTs (default: course-app)
#   USERS_API_PATH    — absolute path to your local users-api repository
#   CATALOG_API_PATH  — absolute path to your local catalog-api repository
#   SKIP_ECR_PUSH     — set to "true" to skip docker build/push (after first run)

set -e

export AWS_REGION="${AWS_REGION:-us-east-1}"

echo "======================================"
echo " AWS Academy — Full Redeploy"
echo " Region: $AWS_REGION"
echo " Account: $(aws sts get-caller-identity --query Account --output text)"
echo "======================================"

# Change to the script directory so relative paths work
cd "$(dirname "$0")"

echo ""
echo "--- Step 1/7: Networking ---"
bash 01-networking.sh

echo ""
echo "--- Step 2/7: ECR ---"
if [ "${SKIP_ECR_PUSH:-false}" = "true" ]; then
  echo "  Skipping ECR push (SKIP_ECR_PUSH=true)."
  # Still need ECR_REGISTRY in infra-outputs.env
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  echo "ECR_REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" >> ./infra-outputs.env
else
  bash 02-ecr-push.sh
fi

echo ""
echo "--- Step 3/7: SQS ---"
bash 03-sqs.sh

echo ""
echo "--- Step 4/7: RDS ---"
bash 04-rds.sh

echo ""
echo "--- Step 5/7: IAM (LabRole) ---"
bash 05-iam.sh

echo ""
echo "--- Step 6/7: ECS ---"
bash 06-ecs.sh

echo ""
echo "--- Step 7/7: API Gateway ---"
bash 07-apigateway.sh

echo ""
echo "======================================"
echo " Deployment complete!"
echo " Gateway URL: $(grep GATEWAY_URL infra-outputs.env | cut -d= -f2)"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Run EF Core migrations against the new RDS endpoints (see README.md)."
echo "  2. Test the gateway with the curl commands printed by 07-apigateway.sh."
echo "  3. Save infra-outputs.env locally — it will be overwritten next session."
