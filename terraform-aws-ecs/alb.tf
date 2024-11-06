# ========================================================
# ALB
# ========================================================

resource "aws_lb" "this" {
  name               = "${local.environment}-${local.app_name}-alb-ext"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = false

  access_logs {
    bucket  = local.s3_logs_bucket_name
    prefix  = "/ALBs/${local.environment}-${local.app_name}-alb-ext/AccessLogs"
    enabled = true
  }

  connection_logs {
    bucket  = local.s3_logs_bucket_name
    prefix  = "/ALBs/${local.environment}-${local.app_name}-alb-ext/AccessLogs"
    enabled = true
  }

  tags = local.tags
}

# ========================================================
# ALB Target Group
# ========================================================

resource "aws_lb_target_group" "this" {
  name        = "${local.service_name}-tg-ext"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id
}

# ========================================================
# ALB Listener
# ========================================================

resource "aws_lb_listener" "redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

