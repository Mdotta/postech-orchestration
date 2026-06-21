# ── Kubernetes Secrets (created by Terraform from module outputs) ──────────

resource "kubernetes_secret" "catalog_api" {
  metadata {
    name = "catalog-api-secret"
  }

  data = {
    "ConnectionStrings__DefaultConnection" = module.rds.connection_string
    "AWS__SnsTopicArn"                     = module.messaging.order_created_topic_arn
    "AWS__SqsQueueUrl"                     = module.messaging.catalog_order_processed_queue_url
    "Redis__ConnectionString"              = module.redis.connection_string
    "DynamoDB__TableName"                  = module.dynamodb.catalog_games_table_name
  }
}

resource "kubernetes_secret" "users_api" {
  metadata {
    name = "users-api-secret"
  }

  data = {
    "ConnectionStrings__DefaultConnection" = module.rds.connection_string
    "AWS__SnsTopicArn"                     = module.messaging.user_created_topic_arn
    "CognitoSettings__UserPoolId"          = module.cognito.user_pool_id
    "CognitoSettings__ClientId"            = module.cognito.client_id
  }
}

resource "kubernetes_secret" "payments_api" {
  metadata {
    name = "payments-api-secret"
  }

  data = {
    "ConnectionStrings__DefaultConnection" = module.rds.connection_string
    "AWS__SnsTopicArn"                     = module.messaging.order_processed_topic_arn
    "AWS__SqsQueueUrl"                     = module.messaging.payments_order_created_queue_url
  }
}
