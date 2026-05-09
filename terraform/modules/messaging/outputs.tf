output "user_created_topic_arn" {
  value = aws_sns_topic.user_created.arn
}

output "order_created_topic_arn" {
  value = aws_sns_topic.order_created.arn
}

output "order_processed_topic_arn" {
  value = aws_sns_topic.order_processed.arn
}

output "catalog_order_processed_queue_url" {
  value = "${local.sqs_base}/${aws_sqs_queue.catalog_order.name}"
}

output "payments_order_created_queue_url" {
  value = "${local.sqs_base}/${aws_sqs_queue.payments_order.name}"
}

