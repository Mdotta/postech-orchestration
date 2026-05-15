output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "RDS endpoint address"
}

output "db_connection_string" {
  value       = module.rds.connection_string
  description = "Connection string used by services"
  sensitive   = true
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

output "jwt_issuer" {
  value = module.cognito.jwt_issuer
}

output "sns_user_created_topic_arn" {
  value = module.messaging.user_created_topic_arn
}

output "sns_order_created_topic_arn" {
  value = module.messaging.order_created_topic_arn
}

output "sqs_catalog_order_processed_queue_url" {
  value = module.messaging.catalog_order_processed_queue_url
}

output "sqs_payments_order_created_queue_url" {
  value = module.messaging.payments_order_created_queue_url
}

output "users_eip" {
  value = module.users_service.eip_public_ip
}

output "catalog_eip" {
  value = module.catalog_service.eip_public_ip
}

output "payments_eip" {
  value = module.payments_service.eip_public_ip
}

output "api_gateway_invoke_url" {
  value = module.apigw.invoke_url
}

output "notification_user_created_lambda" {
  value = module.notification_user_created_lambda.function_name
}

output "notification_order_processed_lambda" {
  value = module.notification_order_processed_lambda.function_name
}

output "cloudwatch_log_group_names" {
  value       = module.cloudwatch.log_group_names
  description = "CloudWatch Log Group names per service"
}

output "cloudwatch_log_group_arns" {
  value       = module.cloudwatch.log_group_arns
  description = "CloudWatch Log Group ARNs per service"
}

output "cloudwatch_logs_policy_arn" {
  value       = aws_iam_policy.cloudwatch_logs.arn
  description = "ARN of the CloudWatch Logs IAM policy — attach to LabRole manually if needed"
}

