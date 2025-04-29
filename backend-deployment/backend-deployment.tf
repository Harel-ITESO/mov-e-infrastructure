variable "REGION" {}
variable "VPC" {}
variable "SUBNETS" {}
variable "ROLE" {}
variable "EC2_AMI" {}
variable "EC2_TYPE" {}
variable "EC2_KEY" {}
variable "EC2_INSTANCES" {}
variable "ECR_REPOSITORY" {}
variable "ECR_IMAGE" {}
variable "APP_PORT" {}
variable "CONTAINER_PORT" {}
variable "APP_HEALTH" {}
variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}
variable "AWS_SESSION_TOKEN" {}
variable "SMTP_API_KEY" {}
variable "SMTP_NAME" {}
variable "SMTP_EMAIL" {}
variable "S3_BUCKET" {}
variable "RESET_PASSWORD_JWT_SECRET" {}
variable "EMAIL_VERIFICATION_JWT_SECRET" {}
variable "COOKIE_SECRET" {}
variable "TMDB_API_KEY" {}
variable "DB_NAME" {}
variable "DB_USER" {}
variable "DB_PASSWORD" {}
variable "DB_ENDPOINT" {}
variable "REDIS_CACHE_PASSWORD" {}
variable "REDIS_CACHE_ENDPOINT" {}
variable "REDIS_SESSION_PASSWORD" {}
variable "REDIS_SESSION_ENDPOINT" {}

provider "aws" {
  region = var.REGION
}

resource "aws_security_group" "alb_sg" {
  ingress {
    from_port   = var.APP_PORT
    to_port     = var.APP_PORT
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

resource "aws_security_group" "ec2_sg" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = var.APP_PORT
    to_port     = var.APP_PORT
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

resource "aws_instance" "ec2_instances" {
  ami             = var.EC2_AMI
  instance_type   = var.EC2_TYPE
  count           = var.EC2_INSTANCES
  key_name        = var.EC2_KEY
  subnet_id       = var.SUBNETS[0]
  security_groups = [aws_security_group.ec2_sg.id]
  user_data       = <<-EOF
    #!/bin/bash
    sudo su
    exec > /var/log/user-data.log 2>&1
    yum update -y
    yum install -y docker
    service docker start
    export AWS_ACCESS_KEY_ID="${var.AWS_ACCESS_KEY_ID}"
    export AWS_SECRET_ACCESS_KEY="${var.AWS_SECRET_ACCESS_KEY}"
    export AWS_SESSION_TOKEN="${var.AWS_SESSION_TOKEN}"
    export AWS_DEFAULT_REGION="${var.REGION}"
    aws ecr get-login-password --region ${var.REGION} | docker login --username AWS --password-stdin ${var.ECR_REPOSITORY}
    docker pull ${var.ECR_IMAGE}

    cat <<EOT >> /home/ec2-user/.env
REDIS_CACHE_URL=redis://:${var.REDIS_CACHE_PASSWORD}@${var.REDIS_CACHE_ENDPOINT}:6379/0
REDIS_SESSION_URL=redis://:${var.REDIS_SESSION_PASSWORD}@${var.REDIS_SESSION_ENDPOINT}:6379/0
DATABASE_URL=postgres://${var.DB_USER}:${var.DB_PASSWORD}@${var.DB_ENDPOINT}/${var.DB_NAME}
TMDB_API_KEY=${var.TMDB_API_KEY}
COOKIE_SECRET=${var.COOKIE_SECRET}
EMAIL_VERIFICATION_JWT_SECRET=${var.EMAIL_VERIFICATION_JWT_SECRET}
RESET_PASSWORD_JWT_SECRET=${var.RESET_PASSWORD_JWT_SECRET}
BUCKET_NAME=${var.S3_BUCKET}
AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}
AWS_SESSION_TOKEN=${var.AWS_SESSION_TOKEN}
AWS_REGION=${var.REGION}
AWS_DEFAULT_REGION=${var.REGION}
NODE_ENV=production
SMTP_API_KEY=${var.SMTP_API_KEY}
SMTP_NAME=${var.SMTP_NAME}
SMTP_EMAIL=${var.SMTP_EMAIL}
EOT

    docker run -d --restart always \
      -p ${var.APP_PORT}:${var.CONTAINER_PORT} \
      --env-file /home/ec2-user/.env \
      ${var.ECR_IMAGE}
    EOF
}

resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.SUBNETS
}

resource "aws_lb_target_group" "target_group" {
  health_check {
    interval            = 10
    path                = var.APP_HEALTH
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
  name        = "target-group"
  port        = var.APP_PORT
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.VPC
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.APP_PORT
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.target_group.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "ec2_attach" {
  count            = length(aws_instance.ec2_instances)
  target_group_arn = aws_lb_target_group.target_group.arn
  target_id        = aws_instance.ec2_instances[count.index].id
}

output "alb_dns" {
  value = aws_lb.alb.dns_name
}
