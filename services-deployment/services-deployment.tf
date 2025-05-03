variable "REGION" {}
variable "SUBNETS" {}
variable "DB_NAME" {}
variable "DB_USER" {}
variable "DB_PASSWORD" {}
variable "S3_BUCKET" {}
variable "REDIS_CACHE_PASSWORD" {}
variable "REDIS_SESSION_PASSWORD" {}

provider "aws" {
  region = var.REGION
}

locals {
  redis_clusters = [
    {
      id          = "redis-cluster-1"
      description = "Redis Cluster 1"
      password    = var.REDIS_CACHE_PASSWORD
    },
    {
      id          = "redis-cluster-2"
      description = "Redis Cluster 2"
      password    = var.REDIS_SESSION_PASSWORD
    }
  ]

  tables = {
    password-resets = {
      hash_key_name = "resetId"
    }
    email-verifications = {
      hash_key_name = "verificationId"
    }
  }
}

# redis clusters
resource "aws_security_group" "redis_sg" {
  ingress {
    from_port   = 6379
    to_port     = 6379
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

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = var.SUBNETS
}

resource "aws_elasticache_replication_group" "redis" {
  count = length(local.redis_clusters)
  security_group_ids            = [aws_security_group.redis_sg.id]
  replication_group_id          = local.redis_clusters[count.index].id
  description                   = local.redis_clusters[count.index].description
  node_type                     = "cache.t3.micro"
  engine                        = "redis"
  engine_version                = "7.0"
  port                          = 6379
  subnet_group_name             = aws_elasticache_subnet_group.redis_subnet_group.name
  automatic_failover_enabled    = false
  multi_az_enabled              = false
  num_node_groups               = 1
  replicas_per_node_group       = 0
  transit_encryption_enabled    = true
  at_rest_encryption_enabled    = false
  auth_token                    = local.redis_clusters[count.index].password
}

output "redis_endpoints" {
  value = [
    for r in aws_elasticache_replication_group.redis : r.primary_endpoint_address
  ]
}

# postgres database
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t3.micro"
  db_name              = var.DB_NAME
  username             = var.DB_USER
  password             = var.DB_PASSWORD
  parameter_group_name = "default.postgres16"
  skip_final_snapshot  = true
  publicly_accessible  = true
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

# s3 bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.S3_BUCKET
}

resource "aws_s3_bucket_ownership_controls" "bucket_controls" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_access" {
  bucket = aws_s3_bucket.s3_bucket.id
  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.s3_bucket.arn}/*"
      }
    ]
  })
}

output "s3_bucket_name" {
  value = aws_s3_bucket.s3_bucket.bucket
}

# dynamodb tables
resource "aws_dynamodb_table" "dynamodb_tables" {
  for_each = local.tables
  name         = each.key
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key_name
  attribute {
    name = each.value.hash_key_name
    type = "S"
  }
}

output "dynamodb_table_names" {
  value = [for table in aws_dynamodb_table.dynamodb_tables : table.name]
}
