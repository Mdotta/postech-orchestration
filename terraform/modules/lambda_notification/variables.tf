variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "event_type" {
  type        = string
  description = "Event type suffix for function name (e.g. user-created, order-processed)"
}

variable "ecr_repo_url" {
  type        = string
  description = "ECR repository URL for the Lambda container image"
}

variable "image_tag" {
  type        = string
  description = "Image tag for the Lambda container"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS queue to trigger this Lambda"
}

variable "lambda_role_name" {
  type        = string
  description = "Name of an existing IAM role for Lambda execution (pre-created, since IAM:CreateRole is restricted)"
}
