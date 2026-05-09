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

