resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.name_prefix}-cloudwatch-logs"
  description = "Allow EC2 instances to push Docker logs to CloudWatch. Attach this policy to your LabRole manually if needed."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
