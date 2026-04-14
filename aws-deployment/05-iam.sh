#!/bin/bash
# 05-iam.sh
# Purpose: AWS Academy uses a pre-provisioned "LabRole" IAM role that already
# has broad permissions (ECR, ECS, RDS, SQS, CloudWatch Logs, Secrets Manager).
# Creating new IAM roles is NOT permitted in Academy environments.
# This script simply looks up the LabRole ARN and writes it to infra-outputs.env
# so that 06-ecs.sh can reference it for both the task role and execution role.

set -e

echo "==> [05] Resolving LabRole ARN (AWS Academy)..."

LAB_ROLE_ARN=$(aws iam get-role \
  --role-name LabRole \
  --query 'Role.Arn' --output text)

echo "  LabRole ARN: $LAB_ROLE_ARN"

cat >> ./infra-outputs.env << EOF
TASK_ROLE_ARN=$LAB_ROLE_ARN
EXECUTION_ROLE_ARN=$LAB_ROLE_ARN
EOF

echo "==> [05] IAM (LabRole) done."
