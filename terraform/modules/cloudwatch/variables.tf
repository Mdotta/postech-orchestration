variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "service_names" {
  type        = list(string)
  description = "List of service names for log groups (e.g. ['users-api', 'catalog-api', 'payments-api'])"
}

variable "retention_in_days" {
  type        = number
  description = "Log retention period in days"
  default     = 30
}