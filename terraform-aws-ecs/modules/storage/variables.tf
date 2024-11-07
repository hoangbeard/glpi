variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# ========================================================
# RDS Variables
# ========================================================

variable "db_instance_name" {
  description = "Name of the RDS DB instance"
  type        = string
}

variable "db_instance_class" {
  description = "Instance class for the RDS DB instance"
  type        = string
  default     = "db.t3.medium"
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

# ========================================================
# ECS Variables
# ========================================================

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

# ========================================================
# EFS Variables
# ========================================================

variable "access_point_path" {
  description = "Access point path for the EFS file system"
  type        = string
  default     = "/data"
}

# ========================================================
# KMS Variables
# ========================================================

variable "deletion_window_in_days" {
  description = "Number of days to retain the log group before deletion"
  type        = number
  default     = 7
}
