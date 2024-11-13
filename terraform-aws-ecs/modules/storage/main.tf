# ========================================================
# ECR Repository
# ========================================================

locals {
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 10
        description  = "Expire images older than 7 days"
        action = {
          type = "expire"
        }
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
      },
      {
        rulePriority = 11
        description  = "Keep last 15 images"
        action = {
          type = "expire"
        }
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 15
        }
      }
    ]
  })

  ecr_repositories = {
    nginx = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      lifecycle_policy     = local.lifecycle_policy
    }
    php-fpm = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      lifecycle_policy     = local.lifecycle_policy
    }
  }
}

resource "aws_ecr_repository" "this" {
  for_each = local.ecr_repositories

  name         = "${var.app_name}-${each.key}"
  force_delete = true

  image_tag_mutability = each.value.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = local.ecr_repositories

  repository = aws_ecr_repository.this[each.key].name
  policy     = each.value.lifecycle_policy
}

# ========================================================
# RDS MySQL Instance
# ========================================================

resource "aws_db_instance" "this" {
  # Operation
  apply_immediately         = true
  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.db_instance_name}-final-snapshot"

  # Engine configuration
  identifier        = var.db_instance_name
  allocated_storage = 100
  instance_class    = var.db_instance_class
  engine            = "mysql"
  multi_az          = false
  engine_version    = "8.0"
  # db_name           = "glpi"
  # engine_lifecycle_support = "open-source-rds-extended-support-disabled"

  # Database credentials
  username                            = "dbmaster"
  password                            = "dbmaster12345"
  port                                = 3306
  iam_database_authentication_enabled = true

  # DB parameters and options
  parameter_group_name = aws_db_parameter_group.this.name
  option_group_name    = aws_db_option_group.this.name

  # Network access control
  publicly_accessible    = false
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]

  # Backup and maintenance
  backup_window              = "20:00-21:00"
  backup_retention_period    = 7
  maintenance_window         = "sat:21:00-sat:22:00"
  auto_minor_version_upgrade = true

  # Enable Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.this.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = "arn:aws:iam::${var.aws_account_id}:role/rds-monitoring-role"

  # Storage
  storage_type          = "gp3"
  max_allocated_storage = 1000
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.this.arn
  # iops                  = 3000 # Need allocated_storage over 400GB
  # storage_throughput    = 125 # Need allocated_storage over 400GB

  # Logging
  enabled_cloudwatch_logs_exports = [
    "audit",
    "error",
    "slowquery",
  ]

  tags = var.tags
}

# ========================================================
# RDS Parameters
# ========================================================

locals {
  rds_parameters = [
    # Set all parameters of Character_set to utf8mb4
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "character_set_connection"
      value = "utf8mb4"
    },
    {
      name  = "character_set_database"
      value = "utf8mb4"
    },
    {
      name  = "character_set_filesystem"
      value = "utf8mb4"
    },
    {
      name  = "character_set_results"
      value = "utf8mb4"
    },
    # Logging settings
    {
      name  = "general_log"
      value = "0"
    },
    {
      name  = "slow_query_log"
      value = "1"
    },
    {
      name  = "long_query_time"
      value = 5.0
    },
    {
      name  = "log_queries_not_using_indexes"
      value = "1"
    },
    {
      name  = "log_output"
      value = "FILE"
    }
  ]
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.db_instance_name}-params-group"
  family = "mysql8.0"

  dynamic "parameter" {
    for_each = local.rds_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.db_instance_name}-params-group"
    }
  )
  lifecycle {
    create_before_destroy = true
  }
}

# ========================================================
# RDS Options group
# ========================================================

locals {
  # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.MariaDB.Options.html
  rds_options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT,QUERY_DDL,QUERY_DML_NO_SELECT,QUERY_DCL"
        },
        {
          name  = "SERVER_AUDIT_QUERY_LOG_LIMIT"
          value = "10240"
        },
        {
          name  = "SERVER_AUDIT_EXCL_USERS"
          value = "rdsadmin"
        }
      ]
    }
  ]
}

resource "aws_db_option_group" "this" {
  name                     = "${var.db_instance_name}-options-group"
  option_group_description = "${var.db_instance_name}-options-group"
  engine_name              = "mysql"
  major_engine_version     = "8.0"

  dynamic "option" {
    for_each = local.rds_options
    content {
      option_name                    = option.value.option_name
      port                           = lookup(option.value, "port", null)
      version                        = lookup(option.value, "version", null)
      db_security_group_memberships  = lookup(option.value, "db_security_group_memberships", null)
      vpc_security_group_memberships = lookup(option.value, "vpc_security_group_memberships", null)

      dynamic "option_settings" {
        for_each = lookup(option.value, "option_settings", [])
        content {
          name  = lookup(option_settings.value, "name", null)
          value = lookup(option_settings.value, "value", null)
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.db_instance_name}-options-group"
    }
  )

  timeouts {
    delete = "5m"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================================
# EFS
# ========================================================

resource "aws_efs_file_system" "this" {
  creation_token   = "${var.service_name}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(
    { "Name" = "${var.service_name}-efs" },
    var.tags
  )
}

# ========================================================
# EFS automatic backup
# ========================================================

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = "ENABLED"
  }
}

# ========================================================
# EFS mount targets
# ========================================================

resource "aws_efs_mount_target" "this" {
  count = length(var.subnets)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

# ========================================================
# EFS access points
# ========================================================

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid            = 33
    gid            = 33
    secondary_gids = [1000]
  }

  root_directory {
    path = var.access_point_path

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = 0775
    }
  }

  tags = merge(
    { "Name" = "${var.service_name}-efs-access-point" },
    var.tags
  )
}

# ========================================================
# EFS access policy
# ========================================================

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowGLPIAccessWithSecureTransport"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]
    resources = [
      aws_efs_file_system.this.arn,
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
  }

  statement {
    sid    = "NonSecureTransport"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["*"]
    resources = [
      aws_efs_file_system.this.arn,
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "NonSecureTransportAccessedViaMountTarget"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientMount"
    ]
    resources = [
      aws_efs_file_system.this.arn,
    ]
    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }
  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  policy = data.aws_iam_policy_document.this.json
}

# ========================================================
# Database Security Group
# ========================================================

resource "aws_security_group" "db" {
  name_prefix = "${var.service_name}-db-sg-"
  description = "Allow inbound access from the ECS only"
  vpc_id      = var.vpc_id
  
  tags = merge(
    { "Name" = "${var.service_name}-db-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_ingress_http_ipv4" {
  security_group_id = aws_security_group.db.id

  # referenced_security_group_id = aws_security_group.ecs_tasks.id
  cidr_ipv4   = var.vpc_cidr_block
  from_port   = 3306
  ip_protocol = "tcp"
  to_port     = 3306
}

resource "aws_vpc_security_group_egress_rule" "db_egress_all_traffic_ipv4" {
  security_group_id = aws_security_group.db.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

# ========================================================
# EFS Security Group
# ========================================================

resource "aws_security_group" "efs" {
  name_prefix = "${var.service_name}-efs-sg-"
  description = "Allow inbound access from the VPC only"
  vpc_id      = var.vpc_id
  tags = merge(
    { "Name" = "${var.service_name}-efs-sg" },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_ingress_nfs_ipv4" {
  security_group_id = aws_security_group.efs.id

  cidr_ipv4   = var.vpc_cidr_block
  from_port   = 2049
  ip_protocol = "tcp"
  to_port     = 2049
}

resource "aws_vpc_security_group_egress_rule" "efs_egress_all_traffic_ipv4" {
  security_group_id = aws_security_group.efs.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

# ========================================================
# KMS
# ========================================================

resource "aws_kms_key" "this" {
  description             = "The key to the encryption of everything"
  deletion_window_in_days = var.deletion_window_in_days
}

resource "aws_kms_alias" "this" {
  name          = "alias/ecs/${var.service_name}-exec-command"
  target_key_id = aws_kms_key.this.key_id
}
