locals {
  pool_name   = "${var.name_prefix}-users-pool"
  client_name = "${var.name_prefix}-api-client"
}

resource "aws_cognito_user_pool" "this" {
  name = local.pool_name

  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  username_configuration {
    case_sensitive = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name         = local.client_name
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
}

resource "aws_cognito_user_group" "administrator" {
  user_pool_id = aws_cognito_user_pool.this.id
  name         = "Administrator"
  description  = "Full administrative access"
}

resource "aws_cognito_user_group" "user" {
  user_pool_id = aws_cognito_user_pool.this.id
  name         = "User"
  description  = "Standard user access"
}

