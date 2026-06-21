#!/bin/bash
set -euo pipefail

# =============================================================================
# setup-terraform-backend.sh
# Creates the S3 bucket and DynamoDB table for Terraform remote state.
# Safe to re-run — skips already existing resources.
#
# Usage:
#   ./aws/setup-terraform-backend.sh
#
# Required:
#   AWS CLI configured with credentials
#   Defaults: bucket=postech-terraform-state-us-east-1, region=us-east-1
# =============================================================================

BUCKET="${TF_STATE_BUCKET:-postech-terraform-state-us-east-1}"
LOCK_TABLE="${TF_LOCK_TABLE:-postech-terraform-locks}"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Terraform Backend Setup ==="
echo "Bucket:    $BUCKET"
echo "Lock Table: $LOCK_TABLE"
echo "Region:    $REGION"
echo ""

# --- S3 bucket ---
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "[SKIP] S3 bucket '$BUCKET' already exists."
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET" \
        --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    aws s3api put-public-access-block --bucket "$BUCKET" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    echo "[OK] S3 bucket '$BUCKET' created (versioned + encrypted + private)."
fi

# --- DynamoDB lock table ---
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" 2>/dev/null; then
    echo "[SKIP] DynamoDB table '$LOCK_TABLE' already exists."
else
    aws dynamodb create-table \
        --table-name "$LOCK_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$REGION"
    echo "[OK] DynamoDB table '$LOCK_TABLE' created."
fi

echo ""
echo "=== Done. You can now run: cd terraform/envs/prod && terraform init ==="
