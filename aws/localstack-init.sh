#!/bin/bash
# =============================================================================
# localstack-init.sh
# Auto-runs when LocalStack is ready (mounted at /etc/localstack/init/ready.d/).
# Provisions all SNS topics, SQS queues and subscriptions for local development.
#
# Topology (mirrors setup-sns-sqs.sh):
#   users-api    → SNS: user-created    → SQS: notifications-user-created
#   catalog-api  → SNS: order-created   → SQS: payments-order-created
#   payment-api  → SNS: order-processed → SQS: notifications-order-processed
#                                       → SQS: catalog-order-processed
# =============================================================================
set -euo pipefail

ENDPOINT="http://localhost:4566"
REGION="us-east-1"
ACCOUNT="000000000000"

aws() { command aws --endpoint-url="$ENDPOINT" --region "$REGION" "$@"; }

create_topic() {
  local NAME="$1"
  aws sns create-topic --name "$NAME" --query 'TopicArn' --output text
}

create_queue() {
  local NAME="$1"
  aws sqs create-queue --queue-name "$NAME" --query 'QueueUrl' --output text
}

subscribe() {
  local TOPIC_ARN="$1"
  local QUEUE_NAME="$2"
  local QUEUE_ARN="arn:aws:sqs:$REGION:$ACCOUNT:$QUEUE_NAME"
  aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint "$QUEUE_ARN" > /dev/null
  echo "  subscribed: $(basename "$TOPIC_ARN") → $QUEUE_NAME"
}

echo "[localstack-init] Provisioning SNS topics..."
TOPIC_USER_CREATED=$(create_topic "user-created")
TOPIC_ORDER_CREATED=$(create_topic "order-created")
TOPIC_ORDER_PROCESSED=$(create_topic "order-processed")

echo "[localstack-init] Provisioning SQS queues..."
create_queue "notifications-user-created"    > /dev/null
create_queue "payments-order-created"        > /dev/null
create_queue "notifications-order-processed" > /dev/null
create_queue "catalog-order-processed"       > /dev/null

echo "[localstack-init] Subscribing queues to topics..."
subscribe "$TOPIC_USER_CREATED"    "notifications-user-created"
subscribe "$TOPIC_ORDER_CREATED"   "payments-order-created"
subscribe "$TOPIC_ORDER_PROCESSED" "notifications-order-processed"
subscribe "$TOPIC_ORDER_PROCESSED" "catalog-order-processed"

echo "[localstack-init] Done!"
echo ""
echo "  SNS Topic ARNs:"
echo "    user-created    : $TOPIC_USER_CREATED"
echo "    order-created   : $TOPIC_ORDER_CREATED"
echo "    order-processed : $TOPIC_ORDER_PROCESSED"
echo ""
echo "  SQS Queue URLs (http://localhost:4566/000000000000/<name>):"
echo "    notifications-user-created"
echo "    payments-order-created"
echo "    notifications-order-processed"
echo "    catalog-order-processed"
