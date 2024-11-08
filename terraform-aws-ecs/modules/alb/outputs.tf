# ========================================================
# ALB Outputs
# ========================================================

output "alb_dns" {
  description = "The DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = aws_lb_target_group.this.arn
}

# ========================================================
# Security Group Outputs
# ========================================================

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.alb.id
}
