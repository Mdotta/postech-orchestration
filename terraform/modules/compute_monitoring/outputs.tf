output "grafana_eip" {
  value       = aws_eip.this.public_ip
  description = "Grafana public IP address"
}

output "grafana_url" {
  value       = "http://${aws_eip.this.public_ip}:3000"
  description = "Grafana dashboard URL"
}

output "prometheus_url" {
  value       = "http://${aws_eip.this.public_ip}:9090"
  description = "Prometheus UI URL"
}
