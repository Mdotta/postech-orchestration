variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for API Gateway name"
}

variable "jwt_issuer" {
  type        = string
  description = "Cognito issuer URL"
}

variable "jwt_audience" {
  type        = string
  description = "Cognito app client id"
}

variable "stage_name" {
  type        = string
  description = "API stage name"
  default     = "prod"
}

variable "users_integration_uri" {
  type        = string
  description = "Integration URI for users service (e.g. http://<eip>)"
}

variable "catalog_integration_uri" {
  type        = string
  description = "Integration URI for catalog service (e.g. http://<eip>)"
}

