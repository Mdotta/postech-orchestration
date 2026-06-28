module "network" {
  source      = "../../modules/network"
  name_prefix = var.name_prefix
}

module "security_groups" {
  source         = "../../modules/security_groups"
  name_prefix    = var.name_prefix
  vpc_id         = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block
  admin_cidr     = var.admin_cidr
}

module "rds" {
  source              = "../../modules/rds_postgres"
  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.subnet_ids
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
  db_instance_class   = var.db_instance_class
  publicly_accessible = var.rds_publicly_accessible
  rds_sg_id           = module.security_groups.rds_sg_id
}

module "dynamodb" {
  source      = "../../modules/dynamodb"
  aws_region  = var.aws_region
  name_prefix = var.name_prefix
}

module "cognito" {
  source      = "../../modules/cognito"
  aws_region  = var.aws_region
  name_prefix = var.name_prefix
}

module "messaging" {
  source      = "../../modules/messaging"
  aws_region  = var.aws_region
  name_prefix = var.name_prefix
}

module "ecr" {
  source      = "../../modules/ecr"
  name_prefix = var.name_prefix
}

module "redis" {
  source         = "../../modules/elasticache_redis"
  name_prefix    = var.name_prefix
  aws_region     = var.aws_region
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.subnet_ids
  vpc_cidr_block = module.network.vpc_cidr_block
  node_type      = var.redis_node_type
  engine_version = var.redis_engine_version
}

module "eks" {
  source                      = "../../modules/eks"
  name_prefix                 = var.name_prefix
  vpc_id                      = module.network.vpc_id
  subnet_ids                  = module.network.subnet_ids
  node_count                  = var.eks_node_count
  existing_cluster_role_name  = var.existing_cluster_role_name
  existing_node_role_name     = var.existing_node_role_name
}

module "apigw" {
  source      = "../../modules/apigw_http"
  aws_region  = var.aws_region
  name_prefix = var.name_prefix

  jwt_issuer   = module.cognito.jwt_issuer
  jwt_audience = module.cognito.client_id

  users_integration_uri = can(kubernetes_ingress_v1.postech.status[0].load_balancer[0].ingress[0].hostname) ? "http://${kubernetes_ingress_v1.postech.status[0].load_balancer[0].ingress[0].hostname}" : "http://0.0.0.0"
  catalog_integration_uri = can(kubernetes_ingress_v1.postech.status[0].load_balancer[0].ingress[0].hostname) ? "http://${kubernetes_ingress_v1.postech.status[0].load_balancer[0].ingress[0].hostname}" : "http://0.0.0.0"
}

module "notification_user_created_lambda" {
  source        = "../../modules/lambda_notification"
  name_prefix   = var.name_prefix
  event_type    = "user-created"
  ecr_repo_url  = module.ecr.notifications_lambda_repo_url
  image_tag     = var.notifications_image_tag
  sqs_queue_arn = module.messaging.notifications_user_queue_arn
  lambda_role_name = var.lambda_role_name
}

module "notification_order_processed_lambda" {
  source           = "../../modules/lambda_notification"
  name_prefix      = var.name_prefix
  event_type       = "order-processed"
  ecr_repo_url     = module.ecr.notifications_lambda_repo_url
  image_tag        = var.notifications_image_tag
  sqs_queue_arn    = module.messaging.notifications_order_queue_arn
  lambda_role_name = var.lambda_role_name
}

module "cloudwatch" {
  source        = "../../modules/cloudwatch"
  name_prefix   = var.name_prefix
  aws_region    = var.aws_region
  service_names = ["users-api", "catalog-api", "payments-api"]
}
