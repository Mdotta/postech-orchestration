resource "aws_dynamodb_table" "catalog_games" {
  name         = "${var.name_prefix}-catalog-games"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Id"

  attribute {
    name = "Id"
    type = "S"
  }

  tags = {
    Name      = "${var.name_prefix}-catalog-games"
    ManagedBy = "terraform"
    Service   = "catalog-api"
  }
}

resource "aws_dynamodb_table" "notifications_event_logs" {
  name         = "${var.name_prefix}-notifications-event-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Id"

  attribute {
    name = "Id"
    type = "S"
  }

  tags = {
    Name      = "${var.name_prefix}-notifications-event-logs"
    ManagedBy = "terraform"
    Service   = "notifications-api"
  }
}
