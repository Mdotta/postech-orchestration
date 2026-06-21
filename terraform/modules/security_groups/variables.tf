variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block for ingress rules"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed for admin access"
}
