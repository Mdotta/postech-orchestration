output "users_repo_name" {
  value = aws_ecr_repository.users.name
}

output "catalog_repo_name" {
  value = aws_ecr_repository.catalog.name
}

output "payments_repo_name" {
  value = aws_ecr_repository.payments.name
}

