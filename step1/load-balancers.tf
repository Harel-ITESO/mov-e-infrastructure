variable "region" {
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

resource "aws_lb" "alb_1" {
  name               = "alb-1"
  internal           = false
  load_balancer_type = "application"
  security_groups = [var.security_group]
  subnets            = var.subnets
  enable_deletion_protection = false
}

resource "aws_lb" "alb_2" {
  name               = "alb-2"
  internal           = false
  load_balancer_type = "application"
  security_groups = [var.security_group]
  subnets            = var.subnets
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "alb_1_target_group" {
  name     = "alb-1-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc
  target_type = "ip"
}

resource "aws_lb_target_group" "alb_2_target_group" {
  name     = "alb-2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc
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

resource "aws_lb_listener" "alb_2_listener" {
  load_balancer_arn = aws_lb.alb_2.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_2_target_group.arn
  }
}

output "alb_1_dns" {
  value = aws_lb.alb_1.dns_name
}

output "alb_2_dns" {
  value = aws_lb.alb_2.dns_name
}
