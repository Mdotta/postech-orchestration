variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ElastiCache will be placed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ElastiCache subnet group"
}

variable "ec2_sg_id" {
  type        = string
  description = "EC2 security group ID allowed to reach Redis"
}

variable "node_type" {
  type        = string
  description = "ElastiCache instance class"
  default     = "cache.t3.micro"
}

variable "engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.0"
}

variable "port" {
  type        = number
  description = "Redis port"
  default     = 6379
}
