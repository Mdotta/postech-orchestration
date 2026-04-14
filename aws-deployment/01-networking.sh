#!/bin/bash
# 01-networking.sh
# Purpose: Creates the VPC, subnets (public for ECS, private for RDS),
# internet gateway, route tables, and security groups needed for the course project.
# Outputs all resource IDs to infra-outputs.env for use by subsequent scripts.

set -e

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "==> [01] Creating VPC and networking resources in $AWS_REGION..."

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=course-vpc
echo "VPC: $VPC_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
echo "IGW: $IGW_ID"

# Public subnets (ECS Fargate tasks run here with public IPs)
PUB_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone "${AWS_REGION}a" \
  --query 'Subnet.SubnetId' --output text)
PUB_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 \
  --availability-zone "${AWS_REGION}b" \
  --query 'Subnet.SubnetId' --output text)
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUBNET_1" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUBNET_2" --map-public-ip-on-launch

# Private subnets (RDS instances live here, not directly reachable from internet)
PRIV_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block 10.0.3.0/24 \
  --availability-zone "${AWS_REGION}a" \
  --query 'Subnet.SubnetId' --output text)
PRIV_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" --cidr-block 10.0.4.0/24 \
  --availability-zone "${AWS_REGION}b" \
  --query 'Subnet.SubnetId' --output text)

echo "Public  Subnets: $PUB_SUBNET_1  $PUB_SUBNET_2"
echo "Private Subnets: $PRIV_SUBNET_1 $PRIV_SUBNET_2"

# Route table for public subnets (default route via IGW)
RTB_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route \
  --route-table-id "$RTB_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$PUB_SUBNET_1"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$PUB_SUBNET_2"

# Security group for ECS tasks (allow inbound on container port 8080)
ECS_SG=$(aws ec2 create-security-group \
  --group-name ecs-tasks-sg \
  --description "ECS Tasks Security Group" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id "$ECS_SG" \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0

# Security group for RDS (allow PostgreSQL only from ECS tasks)
RDS_SG=$(aws ec2 create-security-group \
  --group-name rds-sg \
  --description "RDS PostgreSQL Security Group" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id "$RDS_SG" \
  --protocol tcp --port 5432 \
  --source-group "$ECS_SG"

echo "ECS SG: $ECS_SG"
echo "RDS SG: $RDS_SG"

# Write outputs for use by subsequent scripts
cat > ./infra-outputs.env << EOF
VPC_ID=$VPC_ID
PUB_SUBNET_1=$PUB_SUBNET_1
PUB_SUBNET_2=$PUB_SUBNET_2
PRIV_SUBNET_1=$PRIV_SUBNET_1
PRIV_SUBNET_2=$PRIV_SUBNET_2
ECS_SG=$ECS_SG
RDS_SG=$RDS_SG
EOF

echo "==> [01] Networking done. Outputs saved to infra-outputs.env"
