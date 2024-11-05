# ========================================================
# ALB Security Group
# ========================================================
resource "aws_security_group" "alb" {
  name_prefix = "${local.service_name}-alb-sg-"
  description = "Allow inbound access from the Internet"
  vpc_id      = local.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http_ipv4" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_https_ipv4" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_egress_all_traffic_ipv4" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

# ========================================================
# ECS Tasks Security Group
# ========================================================
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${local.service_name}-ecs-tasks-sg-"
  description = "Allow inbound access from the VPC only"
  vpc_id      = local.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_ingress_http_ipv4" {
  security_group_id = aws_security_group.ecs_tasks.id

  cidr_ipv4   = data.aws_vpc.selected.cidr_block
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_egress_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_tasks.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

# ========================================================
# Database Security Group
# ========================================================
resource "aws_security_group" "db" {
  name_prefix = "${local.service_name}-db-sg-"
  description = "Allow inbound access from the ECS only"
  vpc_id      = local.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_ingress_http_ipv4" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.ecs_tasks.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "db_egress_all_traffic_ipv4" {
  security_group_id = aws_security_group.db.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}