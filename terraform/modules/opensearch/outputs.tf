output "domain_endpoint" {
  value       = aws_opensearch_domain.this.endpoint
  description = "OpenSearch domain endpoint (VPC-internal)"
}

output "domain_arn" {
  value       = aws_opensearch_domain.this.arn
  description = "OpenSearch domain ARN"
}

output "connection_string" {
  value       = "https://${aws_opensearch_domain.this.endpoint}"
  description = "Full OpenSearch connection URL (HTTPS)"
}
