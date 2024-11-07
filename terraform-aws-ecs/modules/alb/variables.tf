variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "alb_name" {
  description = "The name of the ALB"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC in which to create the security group"
  type        = string
}

variable "subnets" {
  description = "A list of subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "s3_logs_bucket_name" {
  description = "The name of the S3 bucket for storing ALB logs"
  type        = string
}

variable "certificate_arn" {
  description = "The ARN of the ACM certificate for the ALB"
  type        = string
}

variable "container_port" {
  description = "The port on which the container is listening"
  type        = number
  default     = 80
}
