#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# bootstrap-backend.sh
# Creates the Terraform remote state backend resources:
# - S3 bucket for terraform state (versioning + encryption + public access block)
# - DynamoDB table for state locking
#
# Defaults match `envs/prod/backend.tf`.
#
# Usage:
#   ./bootstrap-backend.sh
#
# Optional env vars:
#   AWS_REGION            (default: us-east-1)
#   TF_STATE_BUCKET       (default: postech-terraform-state-us-east-1)
#   TF_LOCKS_TABLE        (default: postech-terraform-locks)
# -----------------------------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-postech-terraform-state-us-east-1}"
TF_LOCKS_TABLE="${TF_LOCKS_TABLE:-postech-terraform-locks}"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

command -v aws &>/dev/null || fail "aws CLI is not installed"

ensure_bucket() {
  log "Checking S3 bucket: $TF_STATE_BUCKET"
  if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
    ok "Bucket exists: $TF_STATE_BUCKET"
  else
    log "Creating bucket in region $AWS_REGION..."
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$TF_STATE_BUCKET" >/dev/null
    else
      aws s3api create-bucket \
        --bucket "$TF_STATE_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration "LocationConstraint=$AWS_REGION" >/dev/null
    fi
    ok "Bucket created: $TF_STATE_BUCKET"
  fi

  log "Enabling bucket versioning..."
  aws s3api put-bucket-versioning \
    --bucket "$TF_STATE_BUCKET" \
    --versioning-configuration Status=Enabled >/dev/null
  ok "Versioning enabled"

  log "Enabling default encryption (SSE-S3)..."
  aws s3api put-bucket-encryption \
    --bucket "$TF_STATE_BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
      }]
    }' >/dev/null
  ok "Encryption enabled"

  log "Blocking all public access..."
  aws s3api put-public-access-block \
    --bucket "$TF_STATE_BUCKET" \
    --public-access-block-configuration '{
      "BlockPublicAcls": true,
      "IgnorePublicAcls": true,
      "BlockPublicPolicy": true,
      "RestrictPublicBuckets": true
    }' >/dev/null
  ok "Public access blocked"
}

ensure_dynamodb_table() {
  log "Checking DynamoDB table: $TF_LOCKS_TABLE"
  if aws dynamodb describe-table --table-name "$TF_LOCKS_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
    ok "Table exists: $TF_LOCKS_TABLE"
    return
  fi

  log "Creating DynamoDB table in region $AWS_REGION..."
  aws dynamodb create-table \
    --table-name "$TF_LOCKS_TABLE" \
    --region "$AWS_REGION" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null

  log "Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists --table-name "$TF_LOCKS_TABLE" --region "$AWS_REGION"
  ok "Table ready: $TF_LOCKS_TABLE"
}

ensure_bucket
ensure_dynamodb_table

echo ""
ok "Terraform backend bootstrap complete."
echo ""
echo "Bucket : $TF_STATE_BUCKET"
echo "Table  : $TF_LOCKS_TABLE"
echo "Region : $AWS_REGION"
echo ""
echo "Next:"
echo "  cd envs/prod"
echo "  terraform init"

