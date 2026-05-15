data "aws_iam_role" "existing" {
  name = var.lambda_role_name
}

resource "aws_lambda_function" "this" {
  function_name = "${var.name_prefix}-notifications-${var.event_type}"
  role          = data.aws_iam_role.existing.arn
  package_type  = "Image"
  image_uri     = "${var.ecr_repo_url}:${var.image_tag}"
  timeout       = 30
  memory_size   = 256
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = 10
}
