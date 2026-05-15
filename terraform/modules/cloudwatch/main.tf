resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(var.service_names)

  name              = "/ecs/${var.name_prefix}-${each.key}"
  retention_in_days = var.retention_in_days

  tags = {
    Name      = "${var.name_prefix}-${each.key}"
    Service   = each.key
    ManagedBy = "terraform"
  }
}
