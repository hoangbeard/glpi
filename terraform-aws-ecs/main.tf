provider "aws" {
  region = "ap-southeast-1"
}

locals {
  environment               = "prod"
  app_name                  = "glpi"
  cluster_name              = "${local.environment}-${local.app_name}"
  service_name              = "${local.environment}-${local.app_name}-web"
  web_server_container_name = local.service_name
  vpc_id                    = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1",
    "subnet-0123456789abcdef2"
  ]
  tags = {
    Name        = "glpi"
    Environment = "production"
  }
}

data "aws_vpc" "selected" {
  id = local.vpc_id
}

# ========================================================
# ECS Cluster
# ========================================================
resource "aws_ecs_cluster" "glpi" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ========================================================
# ECS Task Definitions
# ========================================================
resource "aws_ecs_task_definition" "glpi" {
  family                   = "${local.service_name}-taskdef"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "service-storage"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.fs.id
      root_directory          = "/opt/data"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.test.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = templatefile("${path.module}/container-definitions.tftpl", {
    web_server_image          = "hoangbeard/glpi:nginx"
    web_server_container_name = "nginx"
    php_fpm_image             = "hoangbeard/glpi:php-fpm"
    php_fpm_container_name    = "php"
  })

  tags = local.tags
}

# ========================================================
# ECS Service
# ========================================================
resource "aws_ecs_service" "glpi" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.glpi.id
  task_definition = aws_ecs_task_definition.glpi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
    subnets         = local.subnet_ids
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.glpi.arn
    container_name   = local.web_server_container_name
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.glpi
  ]
}

# ========================================================
# ECR Repository
# ========================================================
resource "aws_ecr_repository" "glpi" {
  name                 = local.service_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "glpi" {
  repository = aws_ecr_repository.glpi.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        action = {
          type = "expire"
        }
        selection = {
          tagStatus   = "tagged"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
      },
      {
        rulePriority = 2
        description  = "Expire images older than 14 days"
        action = {
          type = "expire"
        }
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
      }
    ]
  })
}
