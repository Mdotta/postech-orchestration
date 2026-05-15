variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "service_name" {
  type        = string
  description = "Short service name (users-api, catalog-api)"
}

variable "instance_name_tag" {
  type        = string
  description = "Value for EC2 Name tag (keeps script-friendly tag names)"
}

variable "ecr_repo_name" {
  type        = string
  description = "ECR repository name"
}

variable "image_tag" {
  type        = string
  description = "Image tag"
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Existing IAM instance profile name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where instance will be placed"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for EC2"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "container_port" {
  type        = number
  description = "Container port exposed on host"
  default     = 80
}

variable "health_path" {
  type        = string
  description = "Health check path (informational output)"
  default     = "/health"
}

variable "env" {
  type        = map(string)
  description = "Environment variables passed to docker run"
  default     = {}
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name for container logs. Leave empty to skip CloudWatch Agent setup."
  default     = ""
}

