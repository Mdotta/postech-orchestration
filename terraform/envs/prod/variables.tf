variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix applied to resource names to avoid collisions with existing resources."
  default     = "tf-postech"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to SSH to EC2 instances."
  default     = "0.0.0.0/32"
}

variable "db_username" {
  type        = string
  description = "RDS master username"
  default     = "postgres"
}

variable "db_password" {
  type        = string
  description = "RDS master password"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "Initial database name"
  default     = "postech"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "rds_publicly_accessible" {
  type        = bool
  description = "Whether RDS is publicly accessible"
  default     = true
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache Redis instance class"
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.0"
}

variable "eks_node_count" {
  type        = number
  description = "Number of EKS worker nodes"
  default     = 3
}

variable "notifications_image_tag" {
  type        = string
  description = "ECR image tag for notifications Lambda"
  default     = "latest"
}

variable "lambda_role_name" {
  type        = string
  description = "Name of the existing IAM role for Lambda execution"
  default     = "LabRole"
}

