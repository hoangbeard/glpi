provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_ecs_cluster" "glpi" {
  name = "glpi"
}

resource "aws_ecs_task_definition" "glpi" {
  family = "glpi"
  container_definitions = templatefile("${path.module}/container-definitions.tftpl", {
    web_server_image = "hoangbeard/glpi:nginx"
    php_fpm_image    = "hoangbeard/glpi:php-fpm"
  })
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
}

resource "aws_ecs_service" "glpi" {
  name            = "glpi"
  cluster         = aws_ecs_cluster.glpi.id
  task_definition = aws_ecs_task_definition.glpi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
    subnets         = aws_subnet.public.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.glpi.arn
    container_name   = "glpi"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.glpi
  ]
}
