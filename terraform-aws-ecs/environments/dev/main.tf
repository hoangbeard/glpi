provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      ManagedByTerraform = "true"
    }
  }
}

locals {
  environment            = "dev"
  app_name               = "glpi"
  cluster_name           = "${local.environment}-${local.app_name}"
  service_name           = "${local.environment}-${local.app_name}-web"
  container_port         = 80
  php_fpm_container_name = "${local.environment}-${local.app_name}-php-fpm"

  vpc_id = "vpc-08dac23aabbc5b1499"
  public_subnet_ids = [
    "subnet-084f5c8356b084af19",
    "subnet-02b1c001ba8499b039"
  ]
  private_subnet_ids = [
    "subnet-0eaa01a119bb15d959",
    "subnet-0817a8ae1b319d8619"
  ]

  db_subnet_group_name = "operation-database-subnets-group"

  access_point_path   = "/${local.app_name}-data"
  s3_logs_bucket_name = "centralized-ops-logs-bucket"
  certificate_arn     = "arn:aws:acm:ap-southeast-1:6408538365439:certificate/a944d470-4bc1-4221-bf38-e66f9d6f8d6a"

  tags = {
    AppName     = "GLPI"
    Environment = "Development"
    Owner       = "CloudOpsTeam"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "selected" {
  id = local.vpc_id
}

# ========================================================
# Module: ALB
# ========================================================

module "alb" {
  source = "../../modules/alb"

  tags = local.tags

  # ECS
  service_name = local.service_name

  # ALB
  alb_name            = "${local.environment}-${local.app_name}-alb-ext"
  vpc_id              = local.vpc_id
  subnets             = local.public_subnet_ids
  s3_logs_bucket_name = local.s3_logs_bucket_name
  certificate_arn     = local.certificate_arn
  container_port      = local.container_port
}

# ========================================================
# Module: ECS
# ========================================================

module "ecs" {
  source = "../../modules/ecs"

  tags        = local.tags
  app_name    = local.app_name
  environment = local.environment

  # ECS
  cluster_name           = local.cluster_name
  service_name           = local.service_name
  vpc_id                 = local.vpc_id
  subnets                = local.private_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  container_port         = local.container_port
  desired_count          = 1
  php_fpm_container_name = local.php_fpm_container_name
  ecr_repository_url     = module.storage.ecr_repository_url
  kms_key_id             = module.storage.kms_key_id
  retention_in_days      = 90
  efs_file_system_id     = module.storage.efs_file_system_id
  efs_access_point_id    = module.storage.efs_access_point_id
  db_instance_endpoint   = module.storage.db_instance_endpoint
}

# ========================================================
# Module: Storage
# ========================================================

module "storage" {
  source = "../../modules/storage"

  tags = local.tags

  # ECS
  cluster_name = local.cluster_name
  service_name = local.service_name
  vpc_id       = local.vpc_id
  subnets      = local.private_subnet_ids

  # RDS
  db_instance_name     = "${local.environment}-${local.app_name}-db"
  db_instance_class    = "db.t3.medium"
  db_subnet_group_name = local.db_subnet_group_name

  # EFS
  access_point_path = local.access_point_path

  # KMS
  deletion_window_in_days = 7
}
