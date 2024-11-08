variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

# ========================================================
# ALB Variables
# ========================================================

variable "alb_name" {
  description = "The name of the ALB"
  type        = string
}

variable "internal" {
  description = "Whether the ALB is internal or not"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Whether the ALB should have deletion protection enabled"
  type        = bool
  default     = false
}

variable "ssl_policy" {
  description = "The SSL policy for the ALB"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

# ========================================================
# VPC Variables
# ========================================================

variable "vpc_id" {
  description = "The ID of the VPC in which to create the security group"
  type        = string
}

variable "subnets" {
  description = "A list of subnets inside the VPC"
  type        = list(string)
  default     = []
}

# ========================================================
# S3 Bucket Logs Variables
# ========================================================

variable "s3_logs_bucket_name" {
  description = "The name of the S3 bucket for storing ALB logs"
  type        = string
}

# ========================================================
# ACM Variables
# ========================================================

variable "certificate_arn" {
  description = "The ARN of the ACM certificate for the ALB"
  type        = string
}

# ========================================================
# ECS Variables
# ========================================================

variable "container_port" {
  description = "The port on which the container is listening"
  type        = number
  default     = 80
}
