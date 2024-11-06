provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      ManagedByTerraform = "true"
    }
  }
}

locals {
  environment            = "prod"
  app_name               = "glpi"
  cluster_name           = "${local.environment}-${local.app_name}"
  service_name           = "${local.environment}-${local.app_name}-web"
  php_fpm_container_name = "${local.environment}-${local.app_name}-php-fpm"
  desired_count          = 1

  vpc_id = "vpc-0123456789abcdef0"
  public_subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]
  private_subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]
  db_subnet_group_name = ""

  access_point_path   = "/${local.app_name}-data"
  s3_logs_bucket_name = ""
  certificate_arn     = ""

  tags = {
    Name        = "GLPI"
    Environment = "Production"
    Owner       = "CloudOpsTeam"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

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

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.glpi.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.glpi.name
      }
    }
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "glpi" {
  cluster_name = aws_ecs_cluster.glpi.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ========================================================
# KMS
# ========================================================

resource "aws_kms_key" "glpi" {
  description             = "Execution command logs in ${local.cluster_name} cluster"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "glpi" {
  name          = "alias/ecs/${local.service_name}-exec-command"
  target_key_id = aws_kms_key.glpi.key_id
}

resource "aws_cloudwatch_log_group" "glpi" {
  name              = "${local.service_name}-cwlg"
  retention_in_days = 30
  skip_destroy      = false
  tags              = local.tags
}

# ========================================================
# ECS Service
# ========================================================
resource "aws_ecs_service" "glpi" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.glpi.id
  task_definition = aws_ecs_task_definition.glpi.arn
  desired_count   = local.desired_count
  # launch_type     = "FARGATE"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
    subnets         = local.private_subnet_ids
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = local.service_name
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.glpi
  ]
}

# ========================================================
# Service Discovery
# ========================================================

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${local.app_name}.${local.environment}"
  description = "${local.app_name} private DNS namespace"
  vpc         = local.vpc_id

  tags = local.tags
}

resource "aws_service_discovery_service" "this" {
  name = local.service_name
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    # namespace_id = local.namespace_id

    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = local.tags
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
    name = "${local.service_name}-efs-volume"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.efs.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = aws_efs_access_point.efs.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = local.service_name
      image     = "${aws_ecr_repository.glpi.repository_url}:nginx"
      essential = true
      depends_on = [
        {
          containerName = "${php_fpm_container_name}"
          condition     = "HEALTHY"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "${local.service_name}-efs-volume"
          containerPath = "/var/www/glpi"
          readOnly      = false
        }
      ]
      portMappings = [
        {
          hostPort      = 80
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "FASTCGI_PASS"
          value = "127.0.0.1:9000"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
          awslogs-group         = "/ecs/${local.cluster_name}/${local.service_name}"
          awslogs-create-group  = "true"
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "/logs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = local.php_fpm_container_name
      image     = "${aws_ecr_repository.glpi.repository_url}:php-fpm"
      essential = true
      mountPoints = [
        {
          sourceVolume  = "${local.service_name}-efs-volume"
          containerPath = "/var/www/glpi"
          readOnly      = false
        }
      ]
      portMappings = [
        {
          hostPort      = 9000
          containerPort = 9000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "GLPI_DB_HOST"
          value = "rds-endpoint"
        },
        {
          name  = "GLPI_DB_PORT"
          value = "3306"
        },
        {
          name  = "GLPI_DB_DATABASE"
          value = "glpi"
        },
        {
          name  = "GLPI_DB_USER"
          value = "glpi"
        },
        {
          name  = "GLPI_DB_PASSWORD"
          value = "glpipass"
        },
        {
          name  = "GLPI_ADMIN_USER"
          value = "glpi"
        },
        {
          name  = "GLPI_LANGUAGE"
          value = "en_US"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
          awslogs-group         = "/ecs/${local.cluster_name}/${local.service_name}"
          awslogs-create-group  = "true"
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "/logs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "php-fpm -t || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.tags
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

# ========================================================
# EventBridge Scheduler resource
# ========================================================

locals {
  # Schedules
  schedule_expression_timezone = "Asia/Ho_Chi_Minh"
  iam_scheduler_role_arn       = aws_iam_role.scheduler_role.arn

  schedules = {
    start = {
      name                         = "start-${local.service_name}"
      flexible_time_window_mode    = "OFF"
      schedule_expression          = "cron(30 7 * * ? *)"
      schedule_expression_timezone = local.schedule_expression_timezone
      service_arn                  = "ecs:updateService"
      role_arn                     = local.iam_scheduler_role_arn
      input = {
        "Cluster"      = local.cluster_name
        "Service"      = local.service_name
        "DesiredCount" = local.desired_count
      }
    }
    stop = {
      name                         = "stop-${local.service_name}"
      flexible_time_window_mode    = "OFF"
      schedule_expression          = "cron(30 23 * * ? *)"
      schedule_expression_timezone = local.schedule_expression_timezone
      service_arn                  = "ecs:updateService"
      role_arn                     = local.iam_scheduler_role_arn
      input = {
        "Cluster"      = local.cluster_name
        "Service"      = local.service_name
        "DesiredCount" = 0
      }
    }
  }
}

resource "aws_scheduler_schedule_group" "this" {
  name = "${local.service_name}-schedule-group"
  tags = local.tags
}

resource "aws_scheduler_schedule" "this" {
  for_each = local.schedules

  name        = try(lookup(each.value, "name", null), null)
  name_prefix = length(each.value.name) == 0 ? lookup(each.value, "name_prefix", "schedule-") : null

  group_name = aws_scheduler_schedule_group.this.name

  flexible_time_window {
    mode = each.value.flexible_time_window_mode
  }

  # https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html
  # schedule_expression = "rate(1 hours)"
  schedule_expression          = each.value.schedule_expression
  schedule_expression_timezone = each.value.schedule_expression_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:${each.value.service_arn}"
    role_arn = each.value.role_arn

    input = jsonencode(each.value.input)
  }
}
