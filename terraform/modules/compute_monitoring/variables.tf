variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where instance will be placed"
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Existing IAM instance profile name"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to access Grafana and SSH"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "scrape_targets" {
  type = map(object({
    host = string
    port = string
  }))
  description = "Services to scrape, keyed by job name. Example: { catalog-api = { host = '1.2.3.4', port = '80' } }"
}

variable "grafana_admin_password" {
  type        = string
  description = "Initial Grafana admin password"
  default     = "admin"
  sensitive   = true
}
