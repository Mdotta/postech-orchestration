#!/bin/bash
set -euo pipefail

# =============================================================================
# cleanup-aws.sh
# Destroys Postech AWS resources (EC2, API Gateway, Cognito, RDS, ECR).
#
# IMPORTANT:
# - This is destructive and intended for teardown in dev/test environments.
# - By default, deletes only Postech-named resources.
#
# Usage:
#   ./aws/cleanup-aws.sh
#
# Optional environment variables:
#   AWS_REGION            - Defaults to us-east-1
#   API_NAME              - Defaults to postech-gateway
#   RDS_INSTANCE_ID       - Defaults to postech-db
#   EC2_TAG_NAMES         - Comma-separated tag:Name values
#                           (default: postech-users-api,postech-catalog-api,postech-payments-api,postech-notifications-api)
#   ECR_REPOS             - Comma-separated repository names to delete
#                           (default: auto-discover repos starting with postech-)
#   DELETE_EC2            - true/false (default: true)
#   DELETE_API_GATEWAY    - true/false (default: true)
#   DELETE_COGNITO        - true/false (default: true)
#   DELETE_RDS            - true/false (default: true)
#   DELETE_ECR            - true/false (default: true)
#   DELETE_RDS_SNAPSHOTS  - true/false (default: true)
#   FORCE                 - true/false (default: false)
# =============================================================================

AWS_REGION="${AWS_REGION:-us-east-1}"
API_NAME="${API_NAME:-postech-gateway}"
RDS_INSTANCE_ID="${RDS_INSTANCE_ID:-postech-db}"
EC2_TAG_NAMES="${EC2_TAG_NAMES:-postech-users-api,postech-catalog-api,postech-payments-api,postech-notifications-api}"
ECR_REPOS="${ECR_REPOS:-}"

DELETE_EC2="${DELETE_EC2:-true}"
DELETE_API_GATEWAY="${DELETE_API_GATEWAY:-true}"
DELETE_COGNITO="${DELETE_COGNITO:-true}"
DELETE_RDS="${DELETE_RDS:-true}"
DELETE_ECR="${DELETE_ECR:-true}"
DELETE_RDS_SNAPSHOTS="${DELETE_RDS_SNAPSHOTS:-true}"
FORCE="${FORCE:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/deployment.env"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

command -v aws &>/dev/null || fail "aws CLI is not installed"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  log "Loaded deployment variables from $ENV_FILE"
fi

# Prefer discovered values from deployment.env when available
API_GATEWAY_ID="${API_GATEWAY_ID:-}"
COGNITO_USER_POOL_ID="${COGNITO_USER_POOL_ID:-}"

print_plan() {
  echo ""
  echo "⚠️  AWS teardown plan (region: $AWS_REGION)"
  echo "   EC2               : $DELETE_EC2"
  echo "   API Gateway       : $DELETE_API_GATEWAY"
  echo "   Cognito User Pool : $DELETE_COGNITO"
  echo "   RDS Instance      : $DELETE_RDS"
  echo "   RDS Snapshots     : $DELETE_RDS_SNAPSHOTS"
  echo "   ECR Repositories  : $DELETE_ECR"
  echo ""
}

require_confirmation() {
  if [[ "$FORCE" == "true" ]]; then
    return
  fi

  print_plan
  echo "This will permanently delete resources and data."
  read -r -p "Type DELETE to continue: " CONFIRM
  [[ "$CONFIRM" == "DELETE" ]] || fail "Confirmation failed. Aborting teardown."
}

delete_ec2_instances() {
  [[ "$DELETE_EC2" == "true" ]] || { log "Skipping EC2 teardown"; return; }

  IFS=',' read -r -a TAGS <<< "$EC2_TAG_NAMES"
  local ids=()
  local tag instance_ids

  for tag in "${TAGS[@]}"; do
    instance_ids=$(aws ec2 describe-instances \
      --region "$AWS_REGION" \
      --filters "Name=tag:Name,Values=$tag" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text 2>/dev/null || true)

    if [[ -n "$instance_ids" && "$instance_ids" != "None" ]]; then
      for id in $instance_ids; do
        ids+=("$id")
      done
    fi
  done

  if [[ ${#ids[@]} -eq 0 ]]; then
    log "No matching EC2 instances found"
    return
  fi

  log "Terminating EC2 instances: ${ids[*]}"
  aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids "${ids[@]}" > /dev/null
  aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids "${ids[@]}"
  ok "EC2 instances terminated"
}

resolve_api_gateway_id() {
  if [[ -n "$API_GATEWAY_ID" ]]; then
    echo "$API_GATEWAY_ID"
    return
  fi

  aws apigatewayv2 get-apis \
    --region "$AWS_REGION" \
    --query "Items[?Name=='$API_NAME'].ApiId" \
    --output text 2>/dev/null || true
}

delete_api_gateway() {
  [[ "$DELETE_API_GATEWAY" == "true" ]] || { log "Skipping API Gateway teardown"; return; }

  local api_id
  api_id="$(resolve_api_gateway_id)"
  if [[ -z "$api_id" || "$api_id" == "None" ]]; then
    log "API Gateway not found (name: $API_NAME)"
    return
  fi

  log "Deleting API Gateway: $api_id"
  aws apigatewayv2 delete-api --region "$AWS_REGION" --api-id "$api_id"
  ok "API Gateway deleted"
}

delete_cognito() {
  [[ "$DELETE_COGNITO" == "true" ]] || { log "Skipping Cognito teardown"; return; }

  if [[ -z "$COGNITO_USER_POOL_ID" || "$COGNITO_USER_POOL_ID" == "None" ]]; then
    warn "COGNITO_USER_POOL_ID not set; skipping Cognito deletion"
    return
  fi

  log "Deleting Cognito user pool: $COGNITO_USER_POOL_ID"
  aws cognito-idp delete-user-pool \
    --region "$AWS_REGION" \
    --user-pool-id "$COGNITO_USER_POOL_ID"
  ok "Cognito user pool deleted"
}

delete_rds_snapshots() {
  [[ "$DELETE_RDS_SNAPSHOTS" == "true" ]] || { log "Skipping RDS snapshot teardown"; return; }

  local snapshots snapshot
  snapshots=$(aws rds describe-db-snapshots \
    --region "$AWS_REGION" \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --snapshot-type manual \
    --query 'DBSnapshots[].DBSnapshotIdentifier' \
    --output text 2>/dev/null || true)

  if [[ -z "$snapshots" || "$snapshots" == "None" ]]; then
    log "No manual RDS snapshots found for $RDS_INSTANCE_ID"
    return
  fi

  for snapshot in $snapshots; do
    log "Deleting RDS snapshot: $snapshot"
    aws rds delete-db-snapshot --region "$AWS_REGION" --db-snapshot-identifier "$snapshot" > /dev/null || true
  done
  ok "Requested deletion of manual RDS snapshots"
}

delete_rds_instance() {
  [[ "$DELETE_RDS" == "true" ]] || { log "Skipping RDS teardown"; return; }

  local status
  status=$(aws rds describe-db-instances \
    --region "$AWS_REGION" \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || true)

  if [[ -z "$status" || "$status" == "None" ]]; then
    log "RDS instance not found: $RDS_INSTANCE_ID"
    return
  fi

  log "Deleting RDS instance: $RDS_INSTANCE_ID (skip final snapshot)"
  aws rds delete-db-instance \
    --region "$AWS_REGION" \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --skip-final-snapshot \
    --delete-automated-backups > /dev/null

  log "Waiting for RDS instance deletion to complete..."
  aws rds wait db-instance-deleted \
    --region "$AWS_REGION" \
    --db-instance-identifier "$RDS_INSTANCE_ID"
  ok "RDS instance deleted"
}

collect_ecr_repos() {
  if [[ -n "$ECR_REPOS" ]]; then
    echo "$ECR_REPOS"
    return
  fi

  local all repos=() repo
  all=$(aws ecr describe-repositories \
    --region "$AWS_REGION" \
    --query 'repositories[].repositoryName' \
    --output text 2>/dev/null || true)

  for repo in $all; do
    if [[ "$repo" == postech-* ]]; then
      repos+=("$repo")
    fi
  done

  if [[ ${#repos[@]} -eq 0 ]]; then
    echo ""
    return
  fi

  local joined
  joined=$(IFS=,; echo "${repos[*]}")
  echo "$joined"
}

delete_ecr_repositories() {
  [[ "$DELETE_ECR" == "true" ]] || { log "Skipping ECR teardown"; return; }

  local repos repo
  repos="$(collect_ecr_repos)"

  if [[ -z "$repos" ]]; then
    log "No matching ECR repositories found"
    return
  fi

  IFS=',' read -r -a repo_list <<< "$repos"
  for repo in "${repo_list[@]}"; do
    repo="${repo// /}"
    [[ -n "$repo" ]] || continue

    log "Deleting ECR repository (force): $repo"
    aws ecr delete-repository \
      --region "$AWS_REGION" \
      --repository-name "$repo" \
      --force > /dev/null || warn "Could not delete ECR repo $repo"
  done
  ok "ECR repository deletion requested"
}

cleanup_deployment_env() {
  [[ -f "$ENV_FILE" ]] || return

  # Keep historical file but remove keys that point to deleted resources.
  local keys_regex
  keys_regex='^(export (COGNITO_USER_POOL_ID|COGNITO_CLIENT_ID|JWT_ISSUER|JWT_AUDIENCE|RDS_ENDPOINT|RDS_PORT|RDS_SG_ID|DB_CONNECTION_STRING|API_GATEWAY_ID|API_GATEWAY_ENDPOINT|EC2_SG_ID)=)'
  grep -Ev "$keys_regex" "$ENV_FILE" > "$ENV_FILE.tmp" || true
  mv "$ENV_FILE.tmp" "$ENV_FILE"
  ok "Cleaned deleted resource keys from deployment.env"
}

main() {
  require_confirmation

  log "Starting AWS teardown..."

  delete_api_gateway
  delete_ec2_instances
  delete_cognito

  # Delete DB first, then clean leftover manual snapshots if requested.
  delete_rds_instance
  delete_rds_snapshots

  delete_ecr_repositories
  cleanup_deployment_env

  echo ""
  ok "AWS teardown completed"
}

main "$@"
