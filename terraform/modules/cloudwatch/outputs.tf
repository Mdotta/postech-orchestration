output "log_group_names" {
  value = {
    for k, v in aws_cloudwatch_log_group.this : k => v.name
  }
  description = "Map of service name to log group name"
}

output "log_group_arns" {
  value = {
    for k, v in aws_cloudwatch_log_group.this : k => v.arn
  }
  description = "Map of service name to log group ARN"
}
