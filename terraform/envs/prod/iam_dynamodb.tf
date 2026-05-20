resource "aws_iam_policy" "dynamodb" {
  name        = "${var.name_prefix}-dynamodb"
  description = "Allow EC2 instances to read/write to DynamoDB tables. Attach this policy to your LabRole/LabInstanceProfile manually if needed."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          module.dynamodb.catalog_games_table_arn,
          module.dynamodb.notifications_event_logs_table_arn
        ]
      }
    ]
  })
}
