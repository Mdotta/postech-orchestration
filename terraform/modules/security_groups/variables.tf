variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to SSH"
}

