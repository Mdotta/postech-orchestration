locals {
  users_repo    = "${var.name_prefix}-postech-users-api"
  catalog_repo  = "${var.name_prefix}-postech-catalog-api"
  payments_repo = "${var.name_prefix}-postech-payments-api"
}

resource "aws_ecr_repository" "users" {
  name                 = local.users_repo
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "catalog" {
  name                 = local.catalog_repo
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "payments" {
  name                 = local.payments_repo
  image_tag_mutability = "MUTABLE"
}

