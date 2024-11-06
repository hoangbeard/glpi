# ========================================================
# EFS
# ========================================================

resource "aws_efs_file_system" "efs" {
  creation_token   = "${local.service_name}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(
    { "Name" = "${local.service_name}-efs" },
    local.tags
  )
}

# ========================================================
# EFS automatic backup
# ========================================================

resource "aws_efs_backup_policy" "efs" {
  file_system_id = aws_efs_file_system.efs.id

  backup_policy {
    status = "ENABLED"
  }
}

# ========================================================
# EFS mount targets
# ========================================================

resource "aws_efs_mount_target" "efs" {
  count = length(local.private_subnet_ids)

  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = local.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# ========================================================
# EFS access points
# ========================================================

resource "aws_efs_access_point" "efs" {
  file_system_id = aws_efs_file_system.efs.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = local.access_point_path

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 0755
    }
  }

  tags = merge(
    { "Name" = "${local.service_name}-efs-access-point" },
    local.tags
  )
}

# ========================================================
# EFS access policy
# ========================================================

data "aws_iam_policy_document" "efs" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ]

    effect = "Allow"

    resources = [
      aws_efs_file_system.efs.arn,
    ]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
        "ec2.amazonaws.com"
      ]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
  }
}

resource "aws_efs_file_system_policy" "efs" {
  file_system_id = aws_efs_file_system.efs.id

  policy = data.aws_iam_policy_document.efs.json
}
