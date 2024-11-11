# ========================================================
# ECS Cluster
# ========================================================

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_id
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      }
    }
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ========================================================
# CloudWatch Log Group
# ========================================================

resource "aws_cloudwatch_log_group" "this" {
  name              = "${var.service_name}-cwlg"
  retention_in_days = var.retention_in_days
  skip_destroy      = false
  # kms_key_id        = var.kms_key_id
  tags = var.tags
}

# ========================================================
# ECS Service
# ========================================================
resource "aws_ecs_service" "this" {
  name                              = var.service_name
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  enable_execute_command            = true
  force_new_deployment              = true
  health_check_grace_period_seconds = 120
  # launch_type     = "FARGATE"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
    subnets         = var.subnets
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
}

# ========================================================
# Service Discovery
# ========================================================

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${var.app_name}.${var.environment}"
  description = "${var.app_name} private DNS namespace"
  vpc         = var.vpc_id

  tags = var.tags
}

resource "aws_service_discovery_service" "this" {
  name = var.service_name
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}

# ========================================================
# ECS Task Definitions
# ========================================================

data "aws_ecr_repository" "nginx" {
  name = var.nginx_image_name
}

data "aws_ecr_repository" "php_fpm" {
  name = var.php_fpm_image_name
}

data "aws_ecs_task_definition" "this" {
  task_definition = aws_ecs_task_definition.this.family

  depends_on = [
    # Needs to exist first on first deployment
    aws_ecs_task_definition.this
  ]
}

locals {
  # This allows us to query both the existing as well as Terraform's state and get
  # and get the max version of either source, useful for when external resources
  # update the container definition
  max_task_def_revision = max(aws_ecs_task_definition.this.revision, data.aws_ecs_task_definition.this.revision)

  # GLPI Nginx image
  nginx_ecr_version = try([for tag in data.aws_ecr_repository.nginx.most_recent_image_tags : tag if tag != "latest"][0], "latest")
  nginx_image       = "${data.aws_ecr_repository.nginx.repository_url}:${local.nginx_ecr_version}"

  # GLPI PHP-FPM image
  php_fpm_ecr_version = try([for tag in data.aws_ecr_repository.php_fpm.most_recent_image_tags : tag if tag != "latest"][0], "latest")
  php_fpm_image       = "${data.aws_ecr_repository.php_fpm.repository_url}:${local.php_fpm_ecr_version}"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.service_name}-taskdef"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  skip_destroy             = true

  volume {
    name = "${var.service_name}-efs-volume"

    efs_volume_configuration {
      file_system_id          = var.efs_file_system_id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name              = var.service_name
      image             = local.nginx_image
      essential         = true
      memoryReservation = 128
      dependsOn = [
        {
          containerName = var.php_fpm_container_name
          condition     = "HEALTHY"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "${var.service_name}-efs-volume"
          containerPath = "/var/www/glpi"
          readOnly      = false
        }
      ]
      portMappings = [
        {
          hostPort      = var.container_port
          containerPort = var.container_port
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
          awslogs-group         = "/ecs/${var.cluster_name}/${var.service_name}"
          awslogs-create-group  = "true"
          awslogs-region        = var.region
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
      name              = var.php_fpm_container_name
      image             = local.php_fpm_image
      essential         = true
      memoryReservation = 256
      mountPoints = [
        {
          sourceVolume  = "${var.service_name}-efs-volume"
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
          value = var.db_instance_address
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
        },
        {
          "name" : "GLPI_VERSION",
          "value" : "10.0.17"
        },
        {
          "name" : "GLPI_SAML_VERSION",
          "value" : "v1.1.10"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
          awslogs-group         = "/ecs/${var.cluster_name}/${var.service_name}"
          awslogs-create-group  = "true"
          awslogs-region        = var.region
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

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================================
# EventBridge Scheduler resource
# ========================================================

locals {
  # Schedules
  schedule_expression_timezone = "Asia/Ho_Chi_Minh"

  schedules = {
    start = {
      name                         = "start-${var.service_name}"
      flexible_time_window_mode    = "OFF"
      schedule_expression          = "cron(30 7 * * ? *)"
      schedule_expression_timezone = local.schedule_expression_timezone
      service_arn                  = "ecs:updateService"
      role_arn                     = aws_iam_role.scheduler_role.arn
      input = {
        "Cluster"      = var.cluster_name
        "Service"      = var.service_name
        "DesiredCount" = var.desired_count
      }
    }
    stop = {
      name                         = "stop-${var.service_name}"
      flexible_time_window_mode    = "OFF"
      schedule_expression          = "cron(30 23 * * ? *)"
      schedule_expression_timezone = local.schedule_expression_timezone
      service_arn                  = "ecs:updateService"
      role_arn                     = aws_iam_role.scheduler_role.arn
      input = {
        "Cluster"      = var.cluster_name
        "Service"      = var.service_name
        "DesiredCount" = 0
      }
    }
  }
}

resource "aws_scheduler_schedule_group" "this" {
  name = "${var.service_name}-schedule-group"
  tags = var.tags
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

# ========================================================
# ECS Tasks Security Group
# ========================================================

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.service_name}-ecs-tasks-sg-"
  description = "Allow inbound access from the VPC only"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_ingress_http_ipv4" {
  security_group_id = aws_security_group.ecs_tasks.id

  cidr_ipv4   = var.vpc_cidr_block
  from_port   = var.container_port
  ip_protocol = "tcp"
  to_port     = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_egress_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_tasks.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

# ========================================================
# ECS Task Exec Role
# ========================================================

resource "aws_iam_role" "ecs_task_exec_role" {
  name = "${var.service_name}-ecs-task-exec-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_role_assume_role_policy.json

  tags = var.tags
}

data "aws_iam_policy_document" "ecs_task_exec_role_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "ecs_task_exec_role_policy" {
  name        = "${var.service_name}-ecs-task-exec-role-policy"
  path        = "/"
  description = "${var.service_name} ECS task execution role policy"
  policy      = data.aws_iam_policy_document.ecs_task_exec_role_policy_document.json

  tags = var.tags
}

data "aws_iam_policy_document" "ecs_task_exec_role_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
      "s3:GetObject",
      "s3:GetBucketLocation",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = aws_iam_policy.ecs_task_exec_role_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_role_managed_policy_attachment" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ========================================================
# ECS Task Role
# ========================================================

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.service_name}-ecs-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_assume_role_policy.json

  tags = var.tags
}

data "aws_iam_policy_document" "ecs_task_role_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "ecs_task_role_policy" {
  name        = "${var.service_name}-ecs-task-role-policy"
  path        = "/"
  description = "${var.service_name} ECS task role policy"
  policy      = data.aws_iam_policy_document.ecs_task_role_policy_document.json

  tags = var.tags
}

data "aws_iam_policy_document" "ecs_task_role_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "kms:GenerateDataKey",
      "kms:Encrpyt",
      "kms:Decrypt",
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation",
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeMountTargets"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_managed_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ========================================================
# Scheduler
# ========================================================

resource "aws_iam_role" "scheduler_role" {
  name = "${var.service_name}-scheduler-role"

  assume_role_policy = data.aws_iam_policy_document.scheduler_role_assume_role_policy.json

  tags = var.tags
}

data "aws_iam_policy_document" "scheduler_role_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "scheduler_role_policy" {
  name        = "${var.service_name}-scheduler-role-policy"
  path        = "/"
  description = "${var.service_name} scheduler role policy"
  policy      = data.aws_iam_policy_document.scheduler_role_policy_document.json

  tags = var.tags
}

data "aws_iam_policy_document" "scheduler_role_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeClusters"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "scheduler_role_policy_attachment" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_role_policy.arn
}
