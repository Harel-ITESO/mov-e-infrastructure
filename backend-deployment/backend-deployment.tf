variable "REGION" {}
variable "VPC" {}
variable "SUBNETS" {}
variable "ROLE" {}
variable "DOCKER_IMAGE" {}
variable "APP_INSTANCES" {}

provider "aws" {
  region = var.REGION
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  vpc_id      = var.VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb_1" {
  name               = "alb-1"
  internal           = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets            = var.SUBNETS
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "alb_1_target_group" {
  name     = "alb-1-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.VPC
  target_type = "ip"
}

resource "aws_lb_listener" "alb_1_listener" {
  load_balancer_arn = aws_lb.alb_1.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_1_target_group.arn
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

resource "aws_ecs_task_definition" "app_1" {
  family                   = "app-1"
  execution_role_arn       = var.ROLE
  task_role_arn            = var.ROLE
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  container_definitions = jsonencode([
    {
      name      = "app-1"
      image     = var.DOCKER_IMAGE
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "service_1" {
  name            = "service-1"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.app_1.arn
  desired_count   = var.APP_INSTANCES
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.SUBNETS
    security_groups  = [aws_security_group.alb_sg.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.alb_1_target_group.arn
    container_name   = "app-1"
    container_port   = 80
  }
}

output "alb_1_dns" {
  value = aws_lb.alb_1.dns_name
}
