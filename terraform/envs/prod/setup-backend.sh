#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
BUCKET="postech-terraform-state-us-east-1"
LOCK_TABLE="postech-terraform-locks"

echo "==> Creating S3 bucket: ${BUCKET}"
aws s3api create-bucket \
  --bucket "${BUCKET}" \
  --region "${REGION}" \
  2>/dev/null || echo "   (bucket already exists, skipping)"

aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Creating DynamoDB lock table: ${LOCK_TABLE}"
aws dynamodb create-table \
  --table-name "${LOCK_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" \
  2>/dev/null || echo "   (table already exists, skipping)"

echo "==> Done. You can now run:  terraform init"
