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

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

# ========================================================
# ECS Variables
# ========================================================

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "desired_count" {
  description = "Number of tasks to run in the service"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port number on which the container listens"
  type        = number
  default     = 80
}

variable "php_fpm_container_name" {
  description = "Name of the PHP-FPM container"
  type        = string
  default     = "php-fpm"
}

# ========================================================
# VPC Variables
# ========================================================

variable "vpc_id" {
  description = "ID of the VPC where the service will be deployed"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets" {
  description = "List of subnet IDs where the service will be deployed"
  type        = list(string)
}

# ========================================================
# ALB Variables
# ========================================================

variable "target_group_arn" {
  description = "ARN of the target group for the service"
  type        = string
}

# ========================================================
# ECR Variables
# ========================================================

variable "nginx_image_name" {
  description = "The name of ECR repository containing the Nginx image"
  type        = string
  default     = "glpi-nginx"
}

variable "php_fpm_image_name" {
  description = "The name of ECR repository containing the PHP-FPM image"
  type        = string
  default     = "glpi-php-fpm"
}

# ========================================================
# KMS Variables
# ========================================================

variable "kms_key_id" {
  description = "ID of the KMS key for data encryption"
  type        = string
}

# ========================================================
# CloudWatch Log Group Variables
# ========================================================

variable "retention_in_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
}

# ========================================================
# EFS Variables
# ========================================================

variable "efs_file_system_id" {
  description = "ID of the EFS file system"
  type        = string
}

variable "efs_access_point_id" {
  description = "ID of the EFS access point"
  type        = string
}

variable "access_point_path" {
  description = "Access point path for the EFS file system"
  type        = string
  default     = "/glpi-data"
}


# ========================================================
# RDS Variables
# ========================================================

variable "db_instance_address" {
  description = "The DB instance Endpoint URL"
  type        = string
}
