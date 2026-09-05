module "network" {
  source = "../../modules/network"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  app_port             = var.app_port
}

module "storage" {
  source = "../../modules/storage"

  environment = var.environment
}

module "iam" {
  source = "../../modules/iam"

  environment          = var.environment
  documents_bucket_arn = module.storage.documents_bucket_arn
}

module "monitoring" {
  source = "../../modules/monitoring"

  environment = var.environment
}

module "database" {
  source = "../../modules/database"

  environment            = var.environment
  private_subnet_ids     = module.network.private_subnet_ids
  data_security_group_id = module.network.data_security_group_id
  db_username            = var.db_username
  db_password            = var.db_password
}

module "compute" {
  source = "../../modules/compute"

  environment                 = var.environment
  vpc_id                      = module.network.vpc_id
  public_subnet_ids           = module.network.public_subnet_ids
  private_subnet_ids          = module.network.private_subnet_ids
  alb_security_group_id       = module.network.alb_security_group_id
  app_security_group_id       = module.network.app_security_group_id
  data_security_group_id      = module.network.data_security_group_id
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn
  app_port                    = var.app_port
  api_image                   = var.api_image
  worker_image                = var.worker_image
  api_log_group_name          = module.monitoring.api_log_group_name
  worker_log_group_name       = module.monitoring.worker_log_group_name
  redis_log_group_name        = module.monitoring.redis_log_group_name
}
