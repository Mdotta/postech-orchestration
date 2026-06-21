output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "EKS cluster API endpoint"
}

output "cluster_ca_certificate" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "EKS cluster CA certificate (base64)"
}

output "node_role_arn" {
  value       = local.node_role_arn
  description = "Node IAM role ARN"
}
