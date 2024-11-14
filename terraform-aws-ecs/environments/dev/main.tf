provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      ManagedByTerraform = "true"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_vpc" "selected" {
  id = local.vpc_id
}

locals {
  environment            = "dev"
  app_name               = "glpi"
  cluster_name           = "${local.environment}-${local.app_name}"
  service_name           = "${local.environment}-${local.app_name}-web"
  container_port         = 80
  php_fpm_container_name = "${local.environment}-${local.app_name}-php-fpm"

  vpc_id = "vpc-08dac23aabbc5b149"
  public_subnet_ids = [
    "subnet-084f5c8356b084af1",
    "subnet-02b1c001ba8499b03"
  ]
  private_subnet_ids = [
    "subnet-0eaa01a119bb15d95",
    "subnet-0817a8ae1b319d861"
  ]

  db_subnet_group_name = "operation-database-subnets-group"

  access_point_path   = "/${local.app_name}-data"
  s3_logs_bucket_name = "movi-ops-logs-bucket"
  certificate_arn     = "arn:aws:acm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:certificate/a944d470-4bc1-4221-bf38-e66f9d6f8d6a"

  tags = {
    AppName     = "GLPI"
    Environment = "Development"
    Owner       = "CloudOpsTeam"
  }
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

  tags           = local.tags
  app_name       = local.app_name
  environment    = local.environment
  region         = data.aws_region.current.name
  vpc_cidr_block = data.aws_vpc.selected.cidr_block

  # ECS
  cluster_name           = local.cluster_name
  service_name           = local.service_name
  vpc_id                 = local.vpc_id
  subnets                = local.private_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  container_port         = local.container_port
  desired_count          = 1
  php_fpm_container_name = local.php_fpm_container_name
  nginx_image_name       = "${local.app_name}-nginx"
  php_fpm_image_name     = "${local.app_name}-php-fpm"

  # KMS
  kms_key_id        = module.storage.kms_key_id
  retention_in_days = 90

  # EFS
  access_point_path   = local.access_point_path
  efs_file_system_id  = module.storage.efs_file_system_id
  efs_access_point_id = module.storage.efs_access_point_id

  # RDS
  db_instance_address = module.storage.db_instance_address
}

# ========================================================
# Module: Storage
# ========================================================

module "storage" {
  source = "../../modules/storage"

  tags           = local.tags
  aws_account_id = data.aws_caller_identity.current.account_id

  # ECS
  cluster_name   = local.cluster_name
  service_name   = local.service_name
  vpc_id         = local.vpc_id
  subnets        = local.private_subnet_ids
  vpc_cidr_block = data.aws_vpc.selected.cidr_block

  # RDS
  db_instance_name     = "${local.environment}-${local.app_name}-db"
  db_instance_class    = "db.t3.medium"
  db_subnet_group_name = local.db_subnet_group_name

  # EFS
  access_point_path = local.access_point_path

  # KMS
  deletion_window_in_days = 7
}
