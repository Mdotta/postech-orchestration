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
  description = "Whether RDS is publicly accessible (matches scripts default: true)"
  default     = true
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name to attach (Terraform does not generate private keys)."
  default     = "postech-key"
}

variable "lab_instance_profile_name" {
  type        = string
  description = "Existing IAM instance profile name used by the EC2 instances."
  default     = "LabInstanceProfile"
}

variable "users_image_tag" {
  type        = string
  description = "ECR image tag for users-api"
  default     = "latest"
}

variable "catalog_image_tag" {
  type        = string
  description = "ECR image tag for catalog-api"
  default     = "latest"
}

variable "payments_image_tag" {
  type        = string
  description = "ECR image tag for payments-api"
  default     = "latest"
}

variable "notifications_image_tag" {
  type        = string
  description = "ECR image tag for notifications Lambda"
  default     = "latest"
}

variable "lambda_role_name" {
  type        = string
  description = "Name of the existing IAM role for Lambda execution (create once via AWS Console before apply)"
  default     = "LabRole"
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

variable "elasticsearch_instance_type" {
  type        = string
  description = "Elasticsearch EC2 instance class"
  default     = "t3.small"
}

