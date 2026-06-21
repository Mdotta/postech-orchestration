variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS cluster will be placed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs (private) for EKS node groups"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the managed node group"
  default     = 3
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
  default     = "t3.medium"
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes version"
  default     = "1.31"
}

variable "existing_cluster_role_name" {
  type        = string
  description = "Name of pre-existing IAM role for EKS cluster (use if iam:CreateRole is denied)"
  default     = ""
}

variable "existing_node_role_name" {
  type        = string
  description = "Name of pre-existing IAM role for EKS nodes (use if iam:CreateRole is denied)"
  default     = ""
}
