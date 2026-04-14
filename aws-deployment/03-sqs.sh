#!/bin/bash
# 03-sqs.sh
# Purpose: Creates the SQS queues that replace RabbitMQ for inter-service
# messaging.  MassTransit's AmazonSQS transport uses these queues natively —
# no code changes are needed beyond swapping the transport package and config.

set -e
source ./infra-outputs.env

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "==> [03] Creating SQS queues..."

aws sqs create-queue --queue-name users-events   --region "$AWS_REGION" 2>/dev/null || echo "  users-events queue already exists"
aws sqs create-queue --queue-name catalog-events --region "$AWS_REGION" 2>/dev/null || echo "  catalog-events queue already exists"

USERS_QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name users-events --query 'QueueUrl' --output text)
CATALOG_QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name catalog-events --query 'QueueUrl' --output text)

echo "  Users   queue: $USERS_QUEUE_URL"
echo "  Catalog queue: $CATALOG_QUEUE_URL"

cat >> ./infra-outputs.env << EOF
USERS_QUEUE_URL=$USERS_QUEUE_URL
CATALOG_QUEUE_URL=$CATALOG_QUEUE_URL
EOF

echo "==> [03] SQS done."
