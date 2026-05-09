module "network" {
  source     = "../../modules/network-default"
  aws_region = var.aws_region
}

module "security_groups" {
  source      = "../../modules/security_groups"
  name_prefix = var.name_prefix
  vpc_id      = module.network.vpc_id
  admin_cidr  = var.admin_cidr
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

module "users_service" {
  source                    = "../../modules/compute_ec2_service"
  aws_region                = var.aws_region
  name_prefix               = var.name_prefix
  service_name              = "users-api"
  instance_name_tag         = "postech-users-api"
  ecr_repo_name             = module.ecr.users_repo_name
  image_tag                 = var.users_image_tag
  key_pair_name             = var.key_pair_name
  iam_instance_profile_name = var.lab_instance_profile_name
  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.subnet_ids[0]
  security_group_ids        = [module.security_groups.ec2_sg_id]

  container_port = 80
  health_path    = "/health"

  env = {
    "ConnectionStrings__DefaultConnection" = module.rds.connection_string
    "AWS__Region"                          = var.aws_region
    "AWS__SnsTopicArn"                     = module.messaging.user_created_topic_arn
    "CognitoSettings__UserPoolId"          = module.cognito.user_pool_id
    "CognitoSettings__ClientId"            = module.cognito.client_id
    "CognitoSettings__Region"              = var.aws_region
  }
}

module "catalog_service" {
  source                    = "../../modules/compute_ec2_service"
  aws_region                = var.aws_region
  name_prefix               = var.name_prefix
  service_name              = "catalog-api"
  instance_name_tag         = "postech-catalog-api"
  ecr_repo_name             = module.ecr.catalog_repo_name
  image_tag                 = var.catalog_image_tag
  key_pair_name             = var.key_pair_name
  iam_instance_profile_name = var.lab_instance_profile_name
  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.subnet_ids[0]
  security_group_ids        = [module.security_groups.ec2_sg_id]

  container_port = 80
  health_path    = "/health"

  env = {
    "ConnectionStrings__DefaultConnection" = module.rds.connection_string
    "AWS__Region"                          = var.aws_region
    "AWS__SnsTopicArn"                     = module.messaging.order_created_topic_arn
    "AWS__SqsQueueUrl"                     = module.messaging.catalog_order_processed_queue_url
  }
}

module "payments_service" {
  source                    = "../../modules/compute_ec2_service"
  aws_region                = var.aws_region
  name_prefix               = var.name_prefix
  service_name              = "payments-api"
  instance_name_tag         = "postech-payments-api"
  ecr_repo_name             = module.ecr.payments_repo_name
  image_tag                 = var.payments_image_tag
  key_pair_name             = var.key_pair_name
  iam_instance_profile_name = var.lab_instance_profile_name
  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.subnet_ids[0]
  security_group_ids        = [module.security_groups.ec2_sg_id]

  container_port = 80
  health_path    = "/health"

  env = {
    "ConnectionStrings__DefaultConnection" = module.rds.connection_string
    "AWS__Region"                          = var.aws_region
    "AWS__SnsTopicArn"                     = module.messaging.order_processed_topic_arn
    "AWS__SqsQueueUrl"                     = module.messaging.payments_order_created_queue_url
  }
}

module "apigw" {
  source      = "../../modules/apigw_http"
  aws_region  = var.aws_region
  name_prefix = var.name_prefix

  jwt_issuer   = module.cognito.jwt_issuer
  jwt_audience = module.cognito.client_id

  users_integration_uri   = "http://${module.users_service.eip_public_ip}"
  catalog_integration_uri = "http://${module.catalog_service.eip_public_ip}"
}

