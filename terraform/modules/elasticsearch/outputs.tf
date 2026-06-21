output "private_ip" {
  value       = aws_instance.this.private_ip
  description = "Elasticsearch EC2 private IP (VPC internal)"
}

output "endpoint" {
  value       = "http://${aws_instance.this.private_ip}:9200"
  description = "Elasticsearch connection URL (HTTP, VPC internal)"
}
