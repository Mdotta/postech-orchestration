#!/bin/bash
# 06-ecs.sh
# Purpose: Creates an ECS Fargate cluster, registers task definitions for
# users-api and catalog-api (with env vars pointing to the RDS and SQS resources
# created earlier), and launches one Fargate task per service.
# After tasks start, the script retrieves their public IPs and appends them to
# infra-outputs.env so that 07-apigateway.sh can wire up the integrations.
# NOTE: Task public IPs change every time tasks are replaced or the session restarts.

set -e
source ./infra-outputs.env

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# JWT configuration — set via environment variables, never hardcode secrets
JWT_ISSUER="${JWT_ISSUER:-users-api}"
JWT_AUDIENCE="${JWT_AUDIENCE:-course-app}"
JWT_KEY="${JWT_KEY:-CHANGE_THIS_TO_A_256_BIT_SECRET_KEY}"

echo "==> [06] Creating ECS cluster, task definitions, and services..."

# ECS Cluster
aws ecs create-cluster \
  --cluster-name course-cluster \
  --capacity-providers FARGATE \
  --region "$AWS_REGION" \
  2>/dev/null || echo "  Cluster already exists"

# CloudWatch log groups
aws logs create-log-group --log-group-name /ecs/users-api   2>/dev/null || true
aws logs create-log-group --log-group-name /ecs/catalog-api 2>/dev/null || true

# --- Users API task definition ---
cat > /tmp/users-task-def.json << EOF
{
  "family": "users-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "taskRoleArn": "$TASK_ROLE_ARN",
  "containerDefinitions": [{
    "name": "users-api",
    "image": "$ECR_REGISTRY/users-api:latest",
    "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
    "environment": [
      { "name": "ASPNETCORE_ENVIRONMENT",               "value": "Production" },
      { "name": "ASPNETCORE_URLS",                      "value": "http://+:8080" },
      { "name": "ConnectionStrings__DefaultConnection",
        "value": "Host=$USERS_DB_HOST;Database=usersdb;Username=postgres;Password=$DB_PASSWORD" },
      { "name": "AWS__Region",   "value": "$AWS_REGION" },
      { "name": "Jwt__Issuer",   "value": "$JWT_ISSUER" },
      { "name": "Jwt__Audience", "value": "$JWT_AUDIENCE" },
      { "name": "Jwt__Key",      "value": "$JWT_KEY" }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group":         "/ecs/users-api",
        "awslogs-region":        "$AWS_REGION",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }]
}
EOF

aws ecs register-task-definition \
  --cli-input-json file:///tmp/users-task-def.json \
  --region "$AWS_REGION" > /dev/null
echo "  users-api task definition registered"

# --- Catalog API task definition ---
cat > /tmp/catalog-task-def.json << EOF
{
  "family": "catalog-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "taskRoleArn": "$TASK_ROLE_ARN",
  "containerDefinitions": [{
    "name": "catalog-api",
    "image": "$ECR_REGISTRY/catalog-api:latest",
    "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
    "environment": [
      { "name": "ASPNETCORE_ENVIRONMENT",               "value": "Production" },
      { "name": "ASPNETCORE_URLS",                      "value": "http://+:8080" },
      { "name": "ConnectionStrings__DefaultConnection",
        "value": "Host=$CATALOG_DB_HOST;Database=catalogdb;Username=postgres;Password=$DB_PASSWORD" },
      { "name": "AWS__Region",   "value": "$AWS_REGION" },
      { "name": "Jwt__Issuer",   "value": "$JWT_ISSUER" },
      { "name": "Jwt__Audience", "value": "$JWT_AUDIENCE" },
      { "name": "Jwt__Key",      "value": "$JWT_KEY" }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group":         "/ecs/catalog-api",
        "awslogs-region":        "$AWS_REGION",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }]
}
EOF

aws ecs register-task-definition \
  --cli-input-json file:///tmp/catalog-task-def.json \
  --region "$AWS_REGION" > /dev/null
echo "  catalog-api task definition registered"

# --- Create ECS Services (1 Fargate task each) ---
aws ecs create-service \
  --cluster course-cluster \
  --service-name users-api-service \
  --task-definition users-api \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PUB_SUBNET_1,$PUB_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=ENABLED}" \
  --region "$AWS_REGION" \
  2>/dev/null || echo "  users-api-service already exists — updating..."

aws ecs update-service \
  --cluster course-cluster \
  --service users-api-service \
  --task-definition users-api \
  --force-new-deployment \
  --region "$AWS_REGION" > /dev/null 2>&1 || true

aws ecs create-service \
  --cluster course-cluster \
  --service-name catalog-api-service \
  --task-definition catalog-api \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PUB_SUBNET_1,$PUB_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=ENABLED}" \
  --region "$AWS_REGION" \
  2>/dev/null || echo "  catalog-api-service already exists — updating..."

aws ecs update-service \
  --cluster course-cluster \
  --service catalog-api-service \
  --task-definition catalog-api \
  --force-new-deployment \
  --region "$AWS_REGION" > /dev/null 2>&1 || true

echo "  Waiting 45 seconds for tasks to start..."
sleep 45

# Retrieve the public IP of a running task for a given service
get_task_ip() {
  local SERVICE_NAME=$1
  local TASK_ARN
  TASK_ARN=$(aws ecs list-tasks \
    --cluster course-cluster \
    --service-name "$SERVICE_NAME" \
    --query 'taskArns[0]' --output text)
  local ENI
  ENI=$(aws ecs describe-tasks \
    --cluster course-cluster \
    --tasks "$TASK_ARN" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
  aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI" \
    --query 'NetworkInterfaces[0].Association.PublicIp' --output text
}

USERS_IP=$(get_task_ip "users-api-service")
CATALOG_IP=$(get_task_ip "catalog-api-service")

echo "  Users   API public IP: $USERS_IP"
echo "  Catalog API public IP: $CATALOG_IP"

cat >> ./infra-outputs.env << EOF
USERS_IP=$USERS_IP
CATALOG_IP=$CATALOG_IP
EOF

echo "==> [06] ECS done."
