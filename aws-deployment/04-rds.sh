#!/bin/bash
# 04-rds.sh
# Purpose: Creates a DB subnet group and two PostgreSQL RDS instances
# (one for users-api, one for catalog-api) using db.t3.micro (free-tier eligible).
# Both instances are placed in private subnets and are only reachable from ECS tasks.
# NOTE: RDS instances are destroyed when an AWS Academy session ends.
#       Re-run this script at the start of each session and then re-run migrations.

set -e
source ./infra-outputs.env

AWS_REGION="${AWS_REGION:-us-east-1}"

# Use the env var if set, otherwise fall back to the placeholder below.
# IMPORTANT: Change this before running — never commit a real password.
DB_PASSWORD="${DB_PASSWORD:-ChangeMe_CoursePassword123!}"

echo "==> [04] Creating RDS PostgreSQL instances..."

# Subnet group spanning two AZs (required by RDS)
aws rds create-db-subnet-group \
  --db-subnet-group-name course-db-subnet \
  --db-subnet-group-description "Course DB Subnet Group" \
  --subnet-ids "$PRIV_SUBNET_1" "$PRIV_SUBNET_2" \
  2>/dev/null || echo "  Subnet group already exists"

# Users DB
aws rds create-db-instance \
  --db-instance-identifier users-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version "16.3" \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --db-name usersdb \
  --db-subnet-group-name course-db-subnet \
  --vpc-security-group-ids "$RDS_SG" \
  --no-multi-az \
  --no-publicly-accessible \
  --region "$AWS_REGION" \
  2>/dev/null || echo "  users-db already exists"

# Catalog DB
aws rds create-db-instance \
  --db-instance-identifier catalog-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version "16.3" \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --db-name catalogdb \
  --db-subnet-group-name course-db-subnet \
  --vpc-security-group-ids "$RDS_SG" \
  --no-multi-az \
  --no-publicly-accessible \
  --region "$AWS_REGION" \
  2>/dev/null || echo "  catalog-db already exists"

echo "  Waiting for RDS instances to become available (typically 5-10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier users-db   --region "$AWS_REGION"
aws rds wait db-instance-available --db-instance-identifier catalog-db --region "$AWS_REGION"

USERS_DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier users-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)
CATALOG_DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier catalog-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)

echo "  Users   DB endpoint: $USERS_DB_HOST"
echo "  Catalog DB endpoint: $CATALOG_DB_HOST"

cat >> ./infra-outputs.env << EOF
USERS_DB_HOST=$USERS_DB_HOST
CATALOG_DB_HOST=$CATALOG_DB_HOST
DB_PASSWORD=$DB_PASSWORD
EOF

echo "==> [04] RDS done."
