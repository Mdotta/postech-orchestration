#!/bin/bash
set -euo pipefail

# =============================================================================
# setup.sh — Bootstrap a clean AWS environment for Postech
#
# Usage:
#   cp .env.example .env        # edit with your values
#   ./setup.sh
#
# Prerequisites:
#   terraform, kubectl, aws cli, python3, docker
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/envs/prod"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="tf-postech-eks"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        Postech — Infrastructure Bootstrap            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Phase 1: Check prerequisites ────────────────────────────────────────────
log "Phase 1/10 — Checking prerequisites..."

command -v terraform &>/dev/null || fail "terraform is not installed. See: https://developer.hashicorp.com/terraform/downloads"
command -v kubectl   &>/dev/null || fail "kubectl is not installed. See: https://kubernetes.io/docs/tasks/tools/"
command -v aws       &>/dev/null || fail "aws CLI is not installed. See: https://aws.amazon.com/cli/"
command -v python3   &>/dev/null || fail "python3 is not installed."

ok "All prerequisites found"

# ── Phase 2: Load .env ──────────────────────────────────────────────────────
log "Phase 2/10 — Loading .env..."

ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  fail ".env file not found. Run: cp .env.example .env  and fill in your values."
fi

set -a
source "$ENV_FILE"
set +a

: "${TF_VAR_db_password:?❌ TF_VAR_db_password is required in .env}"
: "${AWS_ACCESS_KEY_ID:?❌ AWS_ACCESS_KEY_ID is required in .env}"
: "${AWS_SECRET_ACCESS_KEY:?❌ AWS_SECRET_ACCESS_KEY is required in .env}"
: "${AWS_SESSION_TOKEN:?❌ AWS_SESSION_TOKEN is required in .env}"

# Export for Terraform
export TF_VAR_db_password

ok ".env loaded"

# ── Phase 3: Discover EKS roles (vary per AWS Academy session) ─────────────
log "Phase 3/10 — Discovering EKS IAM roles..."

EKS_CLUSTER_ROLE=$(aws iam list-roles --query 'Roles[*].RoleName' \
  --output text | tr '\t' '\n' | grep LabEksClusterRole) || fail "No LabEksClusterRole found in this account"
EKS_NODE_ROLE=$(aws iam list-roles --query 'Roles[*].RoleName' \
  --output text | tr '\t' '\n' | grep LabEksNodeRole) || fail "No LabEksNodeRole found in this account"

export TF_VAR_existing_cluster_role_name="$EKS_CLUSTER_ROLE"
export TF_VAR_existing_node_role_name="$EKS_NODE_ROLE"

ok "EKS roles discovered"

# ── Phase 4: Terraform backend ──────────────────────────────────────────────
log "Phase 4/10 — Setting up Terraform backend (S3 + DynamoDB)..."

"$SCRIPT_DIR/aws/setup-terraform-backend.sh"

ok "Terraform backend ready"

# ── Phase 4: EC2 key pair (needed for EKS nodes) ────────────────────────────
log "Phase 4/10 — Ensuring EC2 key pair exists..."

KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$AWS_REGION" \
  --key-names postech-key --query 'KeyPairs[0].KeyName' --output text 2>/dev/null) || KEY_EXISTS=""

if [[ -z "$KEY_EXISTS" || "$KEY_EXISTS" == "None" ]]; then
  log "Creating key pair 'postech-key'..."
  KEY_PATH="$SCRIPT_DIR/postech-key.pem"
  rm -f "$KEY_PATH"
  aws ec2 create-key-pair --region "$AWS_REGION" --key-name postech-key \
    --query 'KeyMaterial' --output text > "$KEY_PATH"
  chmod 400 "$KEY_PATH"
  ok "Key pair created: $KEY_PATH"
else
  ok "Key pair 'postech-key' already exists"
fi

# ── Phase 5: Terraform (ECR + infra) ────────────────────────────────────────
log "Phase 5/10 — Terraform init..."

cd "$TF_DIR"
terraform init

# Step 5a: Create ECR repos first (needed before images can be pushed)
log "Step 5a: Creating ECR repositories..."
terraform apply -target=module.ecr -auto-approve
ok "ECR repositories created"

# Step 5b: Prompt user to build and push images
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ECR repos are ready. Now build & push images:        ║"
echo "║                                                       ║"
echo "║  From each service repo, run:                         ║"
echo "║    AWS_ACCOUNT_ID=565655678867 ./infra/deploy-ecr.sh  ║"
echo "║                                                       ║"
echo "║  Repos:                                               ║"
echo "║    - postech-catalog-api                              ║"
echo "║    - postech-users-api                                ║"
echo "║    - postech-payments-api                             ║"
echo "║    - postech-notifications-api (Lambda, required!)    ║"
echo "╠═══════════════════════════════════════════════════════╣"
echo "║  Press Enter when all images are pushed to continue.  ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
read -r

# Step 5c: Full terraform apply (everything else)
log "Step 5c: Running full terraform apply (this takes ~15-20 minutes)..."

log "Using EKS roles: cluster=${TF_VAR_existing_cluster_role_name:-NOT SET} node=${TF_VAR_existing_node_role_name:-NOT SET}"

terraform apply -auto-approve
ok "Infrastructure provisioned"

# ── Phase 6: EKS kubeconfig ─────────────────────────────────────────────────
log "Phase 6/10 — Connecting to EKS..."

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

kubectl get nodes &>/dev/null || fail "Cannot reach EKS cluster. Check your VPN/AWS credentials."
ok "EKS connected ($(kubectl get nodes --no-headers | wc -l | tr -d ' ') nodes)"

# ── Phase 7: Nginx Ingress Controller ───────────────────────────────────────
log "Phase 7/10 — Installing nginx ingress controller..."

NGINX_VERSION="controller-v1.11.1"
NGINX_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/$NGINX_VERSION/deploy/static/provider/aws/deploy.yaml"

kubectl apply --validate=false -f "$NGINX_MANIFEST" 2>/dev/null

log "Waiting for nginx controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s 2>/dev/null || warn "Nginx controller not ready yet — retry if needed"

ok "Nginx ingress controller installed"

# ── Phase 8: AWS credentials for pods ───────────────────────────────────────
log "Phase 8/10 — Creating aws-credentials K8s secret..."

kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

ok "aws-credentials secret created"

# ── Phase 9: Deploy shared K8s resources ────────────────────────────────────
log "Phase 10/10 — Deploying shared K8s resources..."

kubectl apply -f "$SCRIPT_DIR/k8s/elasticsearch/"
kubectl apply -f "$SCRIPT_DIR/k8s/catalog-api/servicemonitor.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/users-api/servicemonitor.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/payments-api/servicemonitor.yaml"

log "Waiting for Elasticsearch..."
kubectl wait --for=condition=ready pod --selector=app=elasticsearch --timeout=180s 2>/dev/null || warn "Elasticsearch not ready yet — may take a minute"

ok "Shared K8s resources deployed"

# ── Phase 10: Terraform re-apply (API Gateway → NLB DNS) ────────────────────
log "Phase 10/10 — Running terraform apply (API Gateway wiring)..."

terraform apply -auto-approve

ok "API Gateway wired to NLB"

# ── Summary ─────────────────────────────────────────────────────────────────
log "Bootstrap complete!"

API_URL=$(terraform output -raw api_gateway_invoke_url 2>/dev/null || echo "not available yet")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║                 Bootstrap Complete                    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  API Gateway  $API_URL"
echo "║                                                      ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  NEXT STEPS:                                         ║"
echo "║                                                      ║"
echo "║  1. Build & push images:                              ║"
echo "║     For each service repo, run its CI 'docker' job   ║"
echo "║     or run: ./infra/deploy-ecr.sh                    ║"
echo "║                                                      ║"
echo "║  2. Deploy services:                                 ║"
echo "║     For each service repo, trigger 'deploy' workflow ║"
echo "║     (Actions tab → Run workflow)                     ║"
echo "║                                                      ║"
echo "║  3. Verify:                                          ║"
echo "║     curl $API_URL/health"
echo "║                                                      ║"
echo "║  4. Grafana (login: admin/admin):                    ║"
echo "║     kubectl port-forward -n monitoring \\            ║"
echo "║       svc/kube-prometheus-stack-grafana 3000:80     ║"
echo "║     → http://localhost:3000                          ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
