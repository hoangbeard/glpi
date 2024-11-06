# ========================================================
# RDS MySQL Instance
# ========================================================

resource "aws_db_instance" "this" {
  # Operation
  apply_immediately         = true
  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "${local.environment}-${local.app_name}-db-final-snapshot"

  # Engine configuration
  identifier               = "${local.environment}-${local.app_name}-db"
  allocated_storage        = 100
  instance_class           = "db.t3.medium"
  engine                   = "mysql"
  multi_az                 = false
  engine_version           = "8.0.35"
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"

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
  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]

  # Backup and maintenance
  backup_window              = "20:00-21:00"
  backup_retention_period    = 7
  maintenance_window         = "sat:21:00-sat:22:00"
  auto_minor_version_upgrade = true

  # Enable Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.glpi.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = "arn:aws:iam::698875276003:role/rds-monitoring-role"

  # Storage
  storage_type          = "gp3"
  iops                  = 3000
  storage_throughput    = 125
  max_allocated_storage = 1000
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.glpi.arn

  # Logging
  enabled_cloudwatch_logs_exports = [
    "audit",
    "error",
    "slowquery",
  ]

  tags = local.tags
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
  name   = "${local.environment}-${local.app_name}-db-params-group"
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
    local.tags,
    {
      "Name" = "${local.environment}-${local.app_name}-db-params-group"
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
  name                     = "${local.environment}-${local.app_name}-db-options-group"
  option_group_description = "${local.environment}-${local.app_name}-db-options-group"
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
    local.tags,
    {
      Name = "${local.environment}-${local.app_name}-db-options-group"
    }
  )

  timeouts {
    delete = "5m"
  }

  lifecycle {
    create_before_destroy = true
  }
}
