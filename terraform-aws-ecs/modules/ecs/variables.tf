variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "glpi"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group for the service"
  type        = string
}

variable "container_port" {
  description = "Port number on which the container listens"
  type        = number
  default     = 80
}

variable "desired_count" {
  description = "Number of tasks to run in the service"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "ID of the VPC where the service will be deployed"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs where the service will be deployed"
  type        = list(string)
}

variable "php_fpm_container_name" {
  description = "Name of the PHP-FPM container"
  type        = string
  default     = "php-fpm"
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository containing the Docker image"
  type        = string
}

variable "kms_key_id" {
  description = "ID of the KMS key for data encryption"
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
}

variable "efs_file_system_id" {
  description = "ID of the EFS file system"
  type        = string
}

variable "efs_access_point_id" {
  description = "ID of the EFS access point"
  type        = string
}

variable "db_instance_endpoint" {
  description = "The DB instance Endpoint URL"
  type        = string
}
