variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where Elasticsearch EC2 will be placed"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the EC2 instance"
}

variable "ec2_sg_id" {
  type        = string
  description = "EC2 security group ID allowed to reach Elasticsearch (port 9200)"
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Existing IAM instance profile name"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.small"
}
