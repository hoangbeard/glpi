# ========================================================
# ECR Outputs
# ========================================================

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.this.repository_url
}

# ========================================================
# RDS Outputs
# ========================================================

output "db_instance_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "db_engine_version_actual" {
  description = "The running version of the database"
  value       = aws_db_instance.this.engine_version_actual
}

# ========================================================
# EFS Outputs
# ========================================================

output "efs_file_system_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "efs_access_point_id" {
  description = "The ID of the EFS access point"
  value       = aws_efs_access_point.this.id
}

# ========================================================
# Security Group Outputs
# ========================================================

output "db_security_group_id" {
  description = "The ID of the DB security group"
  value       = aws_security_group.db.id
}

output "efs_security_group_id" {
  description = "The ID of the EFS security group"
  value       = aws_security_group.efs.id
}

# ========================================================
# KMS Outputs
# ========================================================

output "kms_key_id" {
  description = "The ID of the KMS key"
  value       = aws_kms_key.this.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = aws_kms_key.this.arn
}
