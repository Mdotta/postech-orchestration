locals {
  api_name = "${var.name_prefix}-gateway"
}

resource "aws_apigatewayv2_api" "this" {
  name          = local.api_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id          = aws_apigatewayv2_api.this.id
  authorizer_type = "JWT"
  name            = "JwtAuthorizer"

  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.jwt_issuer
    audience = [var.jwt_audience]
  }
}

resource "aws_apigatewayv2_integration" "users" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.users_integration_uri
  payload_format_version = "1.0"
  description            = "users-api"

  request_parameters = {
    "overwrite:path"            = "$request.path"
    "append:header.X-User-Id"   = "$context.authorizer.jwt.claims.sub"
    "append:header.X-User-Name" = "$context.authorizer.jwt.claims.email"
  }
}

resource "aws_apigatewayv2_integration" "catalog" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.catalog_integration_uri
  payload_format_version = "1.0"
  description            = "catalog-api"

  request_parameters = {
    "overwrite:path"            = "$request.path"
    "append:header.X-User-Id"   = "$context.authorizer.jwt.claims.sub"
    "append:header.X-User-Name" = "$context.authorizer.jwt.claims.email"
  }
}

resource "aws_apigatewayv2_route" "default_users" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.users.id}"
}

resource "aws_apigatewayv2_route" "users_get" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /users/{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.users.id}"
}

resource "aws_apigatewayv2_route" "users_patch" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "PATCH /users/{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.users.id}"
}

resource "aws_apigatewayv2_route" "catalog_list_public" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /game"
  target    = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_route" "catalog_search_public" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /game/search"
  target    = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_route" "catalog_post" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /game"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_route" "catalog_get_proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /game/{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_route" "catalog_post_proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /game/{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_route" "catalog_patch_proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "PATCH /game/{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_route" "catalog_delete_proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "DELETE /game/{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  target             = "integrations/${aws_apigatewayv2_integration.catalog.id}"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true
}

