# ========================================================
# ECS Task Exec Role
# ========================================================

resource "aws_iam_role" "ecs_task_exec_role" {
  name = "${local.service_name}-ecs-task-exec-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec_role_assume_role_policy.json

  tags = local.tags
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
  name        = "${local.service_name}-ecs-task-exec-role-policy"
  path        = "/"
  description = "${local.service_name} ECS task execution role policy"
  policy      = data.aws_iam_policy_document.ecs_task_exec_role_policy_document.json

  tags = local.tags
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
  name = "${local.service_name}-ecs-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_assume_role_policy.json

  tags = local.tags
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
  name        = "${local.service_name}-ecs-task-role-policy"
  path        = "/"
  description = "${local.service_name} ECS task role policy"
  policy      = data.aws_iam_policy_document.ecs_task_role_policy_document.json

  tags = local.tags
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
      "kms:Decrypt",
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
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
  name = "${local.service_name}-scheduler-role"

  assume_role_policy = data.aws_iam_policy_document.scheduler_role_assume_role_policy.json

  tags = local.tags
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
  name        = "${local.service_name}-scheduler-role-policy"
  path        = "/"
  description = "${local.service_name} scheduler role policy"
  policy      = data.aws_iam_policy_document.scheduler_role_policy_document.json

  tags = local.tags
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
