# ========================================================
# ECS Outputs
# ========================================================

output "cluster_id" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_ecs_cluster.this.id
}

output "service_id" {
  description = "The Amazon Resource Name (ARN) of the service"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "The Amazon Resource Name (ARN) of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family_revision" {
  description = "The family and revision (family:revision) of the task definition"
  value       = "${try(aws_ecs_task_definition.this.family, "")}:${local.max_task_def_revision}"
}

# ========================================================
# Service Discovery Outputs
# ========================================================

output "dns_namespace_id" {
  description = "The ID of the namespace"
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "service_discovery_id" {
  description = "The ID of the service discovery"
  value       = aws_service_discovery_service.this.id
}

# ========================================================
# CloudWatch Log Group Outputs
# ========================================================

output "cloud_watch_log_group_name" {
  description = "The name of the cloud watch log group"
  value = {
    exec_command  = aws_cloudwatch_log_group.exec_command.name
    container_log = aws_cloudwatch_log_group.container_log.name
  }
}

# ========================================================
# Scheduler Outputs
# ========================================================

output "schedule_group_id" {
  description = "The name of the schedule group"
  value       = aws_scheduler_schedule_group.this.id
}

# ========================================================
# Security Group Outputs
# ========================================================

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.ecs_tasks.id
}

# ========================================================
# IAM Role Outputs
# ========================================================

output "ecs_task_exec_role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.ecs_task_exec_role.arn
}

output "ecs_task_role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "scheduler_role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.scheduler_role.arn
}
