#!/bin/bash
set -euo pipefail

# =============================================================================
# setup-ec2-sg.sh
# Creates the shared EC2 security group used by all postech API services
# and opens the required ports.
# Also adds an inbound rule on the RDS security group to allow EC2 → Postgres.
# Run once — shared by users-api, catalog-api, payments-api, etc.
#
# Usage:
#   ./aws/setup-ec2-sg.sh
#
# Optional environment variables:
#   AWS_REGION              - AWS region (default: us-east-1)
#   RDS_INSTANCE_ID         - RDS instance identifier (default: postech-db)
#   EC2_SG_NAME             - EC2 security group name (default: postech-api-sg)
# =============================================================================

AWS_REGION="${AWS_REGION:-us-east-1}"
RDS_INSTANCE_ID="${RDS_INSTANCE_ID:-postech-db}"
EC2_SG_NAME="${EC2_SG_NAME:-postech-api-sg}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/deployment.env"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

set_env_var() {
  local KEY="$1" VAL="$2"
  touch "$ENV_FILE"
  grep -v "^${KEY}=" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || true
  echo "export ${KEY}='${VAL}'" >> "${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
}

command -v aws &>/dev/null || fail "aws CLI is not installed"

# --- Get current public IP ----------------------------------------------------
MY_IP=$(curl -s ifconfig.me)
[[ -n "$MY_IP" ]] || fail "Could not determine public IP"
log "Your public IP: $MY_IP"

# --- Create EC2 security group ------------------------------------------------
log "Creating EC2 security group '$EC2_SG_NAME'..."

if aws ec2 describe-security-groups \
     --group-names "$EC2_SG_NAME" \
     --region "$AWS_REGION" &>/dev/null; then
  log "Security group '$EC2_SG_NAME' already exists, skipping creation."
else
  aws ec2 create-security-group \
    --group-name "$EC2_SG_NAME" \
    --description "Shared security group for postech API services" \
    --region "$AWS_REGION"
  ok "Security group '$EC2_SG_NAME' created."
fi

EC2_SG_ID=$(aws ec2 describe-security-groups \
  --group-names "$EC2_SG_NAME" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].GroupId' --output text)

log "EC2 Security Group ID: $EC2_SG_ID"

# --- Add inbound rules to EC2 SG (ignore errors if rules already exist) -------
log "Adding inbound rules to EC2 security group..."

aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 \
  --region "$AWS_REGION" 2>/dev/null && ok "HTTP (80) rule added." || log "HTTP (80) rule already exists, skipping."

aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp --port 22 --cidr "$MY_IP/32" \
  --region "$AWS_REGION" 2>/dev/null && ok "SSH (22) rule added for $MY_IP." || log "SSH (22) rule already exists, skipping."

# --- Allow EC2 SG → RDS on port 5432 -----------------------------------------
log "Fetching RDS security group for '$RDS_INSTANCE_ID'..."

RDS_SG_ID=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text \
  2>/dev/null) || RDS_SG_ID=""

if [[ -n "$RDS_SG_ID" && "$RDS_SG_ID" != "None" ]]; then
  log "RDS Security Group ID: $RDS_SG_ID"
  aws ec2 authorize-security-group-ingress \
    --group-id "$RDS_SG_ID" \
    --protocol tcp --port 5432 \
    --source-group "$EC2_SG_ID" \
    --region "$AWS_REGION" 2>/dev/null && ok "EC2 → RDS (5432) rule added." || log "EC2 → RDS (5432) rule already exists, skipping."
else
  warn "RDS instance '$RDS_INSTANCE_ID' not found — skipping RDS SG rule."
  warn "Re-run this script after creating the RDS instance, or the rule will be added automatically by deploy-ec2.sh."
  RDS_SG_ID="(not found)"
fi

# --- Save deployment variables -----------------------------------------------
set_env_var "EC2_SG_NAME" "$EC2_SG_NAME"
set_env_var "EC2_SG_ID"   "$EC2_SG_ID"

# --- Done --------------------------------------------------------------------
echo ""
echo "🚀 Security groups ready!"
echo "   EC2 SG : $EC2_SG_ID ($EC2_SG_NAME)"
echo "   RDS SG : $RDS_SG_ID"
echo "   Run the service-specific deploy-ec2.sh to launch each EC2 instance."
echo ""
echo "📋 Deployment variables saved → $ENV_FILE"
echo "   source $ENV_FILE"