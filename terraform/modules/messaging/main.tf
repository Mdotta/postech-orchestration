data "aws_caller_identity" "current" {}

locals {
  topic_user_created    = "${var.name_prefix}-user-created"
  topic_order_created   = "${var.name_prefix}-order-created"
  topic_order_processed = "${var.name_prefix}-order-processed"

  q_notifications_user  = "${var.name_prefix}-notifications-user-created"
  q_notifications_order = "${var.name_prefix}-notifications-order-processed"
  q_payments_order      = "${var.name_prefix}-payments-order-created"
  q_catalog_order       = "${var.name_prefix}-catalog-order-processed"

  sqs_base = "https://sqs.${var.aws_region}.amazonaws.com/${data.aws_caller_identity.current.account_id}"
}

resource "aws_sns_topic" "user_created" {
  name = local.topic_user_created
}

resource "aws_sns_topic" "order_created" {
  name = local.topic_order_created
}

resource "aws_sns_topic" "order_processed" {
  name = local.topic_order_processed
}

resource "aws_sqs_queue" "dlq_notifications_user" {
  name                      = "${local.q_notifications_user}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "dlq_notifications_order" {
  name                      = "${local.q_notifications_order}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "dlq_payments_order" {
  name                      = "${local.q_payments_order}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "dlq_catalog_order" {
  name                      = "${local.q_catalog_order}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "notifications_user" {
  name = local.q_notifications_user
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_notifications_user.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "notifications_order" {
  name = local.q_notifications_order
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_notifications_order.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "payments_order" {
  name = local.q_payments_order
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_payments_order.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "catalog_order" {
  name = local.q_catalog_order
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_catalog_order.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sns_topic_subscription" "user_created_to_notifications_user" {
  topic_arn             = aws_sns_topic.user_created.arn
  protocol              = "sqs"
  endpoint              = aws_sqs_queue.notifications_user.arn
  raw_message_delivery  = true
}

resource "aws_sns_topic_subscription" "order_created_to_payments_order" {
  topic_arn             = aws_sns_topic.order_created.arn
  protocol              = "sqs"
  endpoint              = aws_sqs_queue.payments_order.arn
  raw_message_delivery  = true
}

resource "aws_sns_topic_subscription" "order_processed_to_notifications_order" {
  topic_arn             = aws_sns_topic.order_processed.arn
  protocol              = "sqs"
  endpoint              = aws_sqs_queue.notifications_order.arn
  raw_message_delivery  = true
}

resource "aws_sns_topic_subscription" "order_processed_to_catalog_order" {
  topic_arn             = aws_sns_topic.order_processed.arn
  protocol              = "sqs"
  endpoint              = aws_sqs_queue.catalog_order.arn
  raw_message_delivery  = true
}

data "aws_iam_policy_document" "queue_policy_notifications_user" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notifications_user.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.user_created.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "notifications_user" {
  queue_url = aws_sqs_queue.notifications_user.id
  policy    = data.aws_iam_policy_document.queue_policy_notifications_user.json
}

data "aws_iam_policy_document" "queue_policy_notifications_order" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notifications_order.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.order_processed.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "notifications_order" {
  queue_url = aws_sqs_queue.notifications_order.id
  policy    = data.aws_iam_policy_document.queue_policy_notifications_order.json
}

data "aws_iam_policy_document" "queue_policy_payments_order" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.payments_order.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.order_created.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "payments_order" {
  queue_url = aws_sqs_queue.payments_order.id
  policy    = data.aws_iam_policy_document.queue_policy_payments_order.json
}

data "aws_iam_policy_document" "queue_policy_catalog_order" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.catalog_order.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.order_processed.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "catalog_order" {
  queue_url = aws_sqs_queue.catalog_order.id
  policy    = data.aws_iam_policy_document.queue_policy_catalog_order.json
}

