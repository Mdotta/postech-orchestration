output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private subnet IDs (for RDS, Redis, EC2 instances)"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs (for ALB/Ingress)"
}

output "vpc_cidr_block" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR block"
}

output "azs" {
  value       = local.azs
  description = "Availability zones used"
}
