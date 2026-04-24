#!/bin/bash
set -euo pipefail

# =============================================================================
# setup-rds.sh
# Creates a shared PostgreSQL RDS instance for all postech microservices.
# After creation, automatically adds the EC2 security group inbound rule.
# Safe to re-run — skips already existing resources.
#
# Usage:
#   ./aws/setup-rds.sh
#
# Required environment variables:
#   DB_PASSWORD       - Master password for the RDS instance
#
# Optional:
#   AWS_REGION        - Defaults to us-east-1
#   RDS_INSTANCE_ID   - RDS instance identifier (default: postech-db)
#   DB_NAME           - Initial database name (default: postech)
#   DB_USERNAME       - Master username (default: postgres)
#   DB_INSTANCE_CLASS - RDS instance class (default: db.t3.micro)
#   PUBLICLY_ACCESSIBLE - Whether RDS is reachable from the internet (default: true)
# =============================================================================

DB_PASSWORD="${DB_PASSWORD:?❌ DB_PASSWORD is not set}"

AWS_REGION="${AWS_REGION:-us-east-1}"
RDS_INSTANCE_ID="${RDS_INSTANCE_ID:-postech-db}"
DB_NAME="${DB_NAME:-postech}"
DB_USERNAME="${DB_USERNAME:-postgres}"
DB_INSTANCE_CLASS="${DB_INSTANCE_CLASS:-db.t3.micro}"
EC2_SG_NAME="${EC2_SG_NAME:-postech-api-sg}"
PUBLICLY_ACCESSIBLE="${PUBLICLY_ACCESSIBLE:-true}"

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

# =============================================================================
# Step 1: Check if RDS instance already exists
# =============================================================================
log "Checking for existing RDS instance '$RDS_INSTANCE_ID'..."

INSTANCE_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null) || INSTANCE_STATUS=""

if [[ -n "$INSTANCE_STATUS" && "$INSTANCE_STATUS" != "None" ]]; then
  log "RDS instance '$RDS_INSTANCE_ID' already exists (status: $INSTANCE_STATUS), skipping creation."
else
  # ==========================================================================
  # Step 2: Create the RDS instance
  # ==========================================================================
  log "Creating RDS PostgreSQL instance '$RDS_INSTANCE_ID'..."
  log "  Class    : $DB_INSTANCE_CLASS"
  log "  DB name  : $DB_NAME"
  log "  Username : $DB_USERNAME"

  ACCESSIBLE_FLAG="--no-publicly-accessible"
  [[ "$PUBLICLY_ACCESSIBLE" == "true" ]] && ACCESSIBLE_FLAG="--publicly-accessible"

  aws rds create-db-instance \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --db-instance-class "$DB_INSTANCE_CLASS" \
    --engine postgres \
    --engine-version "16" \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --no-multi-az \
    $ACCESSIBLE_FLAG \
    --backup-retention-period 0 \
    --no-deletion-protection \
    --region "$AWS_REGION" > /dev/null

  ok "RDS instance creation started."

  # ==========================================================================
  # Step 3: Wait for the instance to become available (can take 5-10 min)
  # ==========================================================================
  log "Waiting for RDS instance to become available (this takes ~5-10 minutes)..."
  aws rds wait db-instance-available \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --region "$AWS_REGION"
  ok "RDS instance is available."
fi

# =============================================================================
# Step 4: Wait if instance exists but is not yet available
# =============================================================================
if [[ "$INSTANCE_STATUS" == "creating" || "$INSTANCE_STATUS" == "modifying" || "$INSTANCE_STATUS" == "backing-up" ]]; then
  log "Instance is in '$INSTANCE_STATUS' state, waiting for it to become available..."
  aws rds wait db-instance-available \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --region "$AWS_REGION"
  ok "RDS instance is available."
fi

# =============================================================================
# Step 5: Get instance details
# =============================================================================
log "Fetching RDS instance details..."

RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

RDS_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text)

RDS_SG_ID=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

ok "Endpoint : $RDS_ENDPOINT:$RDS_PORT"
ok "SG ID    : $RDS_SG_ID"

# =============================================================================
# Step 6: Allow EC2 SG → RDS on port 5432
# =============================================================================
log "Checking EC2 security group '$EC2_SG_NAME'..."

EC2_SG_ID=$(aws ec2 describe-security-groups \
  --group-names "$EC2_SG_NAME" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null) || EC2_SG_ID=""

if [[ -n "$EC2_SG_ID" && "$EC2_SG_ID" != "None" ]]; then
  aws ec2 authorize-security-group-ingress \
    --group-id "$RDS_SG_ID" \
    --protocol tcp \
    --port "$RDS_PORT" \
    --source-group "$EC2_SG_ID" \
    --region "$AWS_REGION" 2>/dev/null \
    && ok "EC2 SG ($EC2_SG_ID) → RDS port $RDS_PORT rule added." \
    || log "EC2 → RDS rule already exists, skipping."
else
  warn "EC2 security group '$EC2_SG_NAME' not found — skipping inbound rule."
  warn "Run setup-ec2-sg.sh first, then re-run this script to add the rule."
fi

# --- Allow public access from current IP (when publicly accessible) ----------
if [[ "$PUBLICLY_ACCESSIBLE" == "true" ]]; then
  MY_IP=$(curl -s ifconfig.me)
  if [[ -n "$MY_IP" ]]; then
    aws ec2 authorize-security-group-ingress \
      --group-id "$RDS_SG_ID" \
      --protocol tcp \
      --port "$RDS_PORT" \
      --cidr "$MY_IP/32" \
      --region "$AWS_REGION" 2>/dev/null \
      && ok "Public access from $MY_IP → RDS port $RDS_PORT rule added." \
      || log "Public IP rule already exists, skipping."
  fi
fi

# =============================================================================
# Step 7: Save deployment variables
# =============================================================================
DB_CONNECTION_STRING="Host=$RDS_ENDPOINT;Port=$RDS_PORT;Database=$DB_NAME;Username=$DB_USERNAME;Password=$DB_PASSWORD"

set_env_var "RDS_ENDPOINT"         "$RDS_ENDPOINT"
set_env_var "RDS_PORT"             "$RDS_PORT"
set_env_var "RDS_SG_ID"            "$RDS_SG_ID"
set_env_var "DB_CONNECTION_STRING" "$DB_CONNECTION_STRING"

# =============================================================================
# Done
# =============================================================================
echo ""
echo "🚀 RDS setup complete!"
echo ""
echo "   Instance ID : $RDS_INSTANCE_ID"
echo "   Endpoint    : $RDS_ENDPOINT:$RDS_PORT"
echo "   Database    : $DB_NAME"
echo "   Username    : $DB_USERNAME"
echo ""
echo "📋 Deployment variables saved → $ENV_FILE"
echo "   source $ENV_FILE"
echo ""
echo "📋 Test connection (from within VPC or via SSH tunnel):"
echo "   psql \"$DB_CONNECTION_STRING\""
echo ""
echo "📋 Next: run setup-ec2-sg.sh (if not done yet), then deploy-ec2.sh for each service."
echo "   DB_CONNECTION_STRING will be loaded automatically from deployment.env."
