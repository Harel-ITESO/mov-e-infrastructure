variable "region" {
  default = ""
}

variable "LabRole" {
  default = ""
}

variable "security_group" {
  default = ""
}

variable "subnets" {
  default = [
    "",
    "",
  ]
}

variable "vpc" {
  default = ""
}

provider "aws" {
  region = var.region
}

data "aws_lb_target_group" "alb_1_target_group" {
  name = "alb-1-tg"
}

data "aws_lb_target_group" "alb_2_target_group" {
  name = "alb-2-tg"
}

resource "aws_ecs_task_definition" "app_1" {
  family                   = "app-1"
  execution_role_arn       = var.LabRole
  task_role_arn            = var.LabRole
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  container_definitions = jsonencode([{
    name      = "app-1"
    image     = "kennethreitz/httpbin"
    memory    = 512
    cpu       = 1
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

resource "aws_ecs_task_definition" "app_2" {
  family                   = "app-2"
  execution_role_arn       = var.LabRole
  task_role_arn            = var.LabRole
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  container_definitions = jsonencode([{
    name      = "app-2"
    image     = "kennethreitz/httpbin"
    memory    = 512
    cpu       = 1
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

resource "aws_instance" "ecs_instance_1" {
  ami           = "ami-085ad6ae776d8f09c"
  instance_type = "t2.micro"
  subnet_id     = var.subnets[0]
  security_groups = [var.security_group]
  tags = {
    Name = "ecs-instance-1"
  }
#   iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "ecs_instance_2" {
  ami           = "ami-085ad6ae776d8f09c"
  instance_type = "t2.micro"
  subnet_id     = var.subnets[1]
  security_groups = [var.security_group]
  tags = {
    Name = "ecs-instance-2"
  }
#   iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_iam_role_policy_attachment" "ecs_instance_attach" {
#   role       = "LabRole"
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

# resource "aws_iam_instance_profile" "ecs_instance_profile" {
#   name = "ecs-instance-profile"
#   role = "LabRole"
# }
#

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

resource "aws_ecs_service" "service_1" {
  name            = "service-1"
  cluster = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.app_1.arn
  desired_count   = 1
  launch_type     = "EC2"
  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.security_group]
  }
  load_balancer {
    target_group_arn = data.aws_lb_target_group.alb_1_target_group.arn
    container_name   = "app-1"
    container_port   = 80
  }
}

resource "aws_ecs_service" "service_2" {
  name            = "service-2"
  cluster = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.app_2.arn
  desired_count   = 1
  launch_type     = "EC2"
  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.security_group]
  }
  load_balancer {
    target_group_arn = data.aws_lb_target_group.alb_2_target_group.arn
    container_name   = "app-2"
    container_port   = 80
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Security group for ECS instances"
  vpc_id      = var.vpc

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
