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

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.this.arn
  description = "OIDC provider ARN for IRSA"
}

output "oidc_provider_url" {
  value       = aws_iam_openid_connect_provider.this.url
  description = "OIDC provider URL"
}

output "node_role_arn" {
  value       = aws_iam_role.node.arn
  description = "Node IAM role ARN"
}
