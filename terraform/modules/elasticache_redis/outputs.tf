output "primary_endpoint" {
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
  description = "Redis primary endpoint address"
}

output "port" {
  value       = aws_elasticache_replication_group.this.port
  description = "Redis port"
}

output "connection_string" {
  value       = "${aws_elasticache_replication_group.this.primary_endpoint_address}:${var.port},password=${random_password.auth.result},ssl=true"
  description = "StackExchange.Redis connection string"
  sensitive   = true
}
