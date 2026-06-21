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
  description = "VPC ID where OpenSearch will be placed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the OpenSearch domain VPC attachment"
}

variable "ec2_sg_id" {
  type        = string
  description = "EC2 security group ID allowed to reach OpenSearch"
}

variable "instance_type" {
  type        = string
  description = "OpenSearch instance class"
  default     = "t3.small.search"
}

variable "instance_count" {
  type        = number
  description = "Number of OpenSearch data nodes"
  default     = 1
}

variable "engine_version" {
  type        = string
  description = "OpenSearch engine version"
  default     = "OpenSearch_2.17"
}

variable "volume_size" {
  type        = number
  description = "EBS volume size in GB per data node"
  default     = 10
}
