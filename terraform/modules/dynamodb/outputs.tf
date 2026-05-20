output "catalog_games_table_name" {
  value       = aws_dynamodb_table.catalog_games.name
  description = "DynamoDB table name for catalog games"
}

output "catalog_games_table_arn" {
  value       = aws_dynamodb_table.catalog_games.arn
  description = "DynamoDB table ARN for catalog games"
}

output "notifications_event_logs_table_name" {
  value       = aws_dynamodb_table.notifications_event_logs.name
  description = "DynamoDB table name for notifications event logs"
}

output "notifications_event_logs_table_arn" {
  value       = aws_dynamodb_table.notifications_event_logs.arn
  description = "DynamoDB table ARN for notifications event logs"
}
