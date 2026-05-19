resource "random_password" "auth" {
  length           = 32
  special          = true
  override_special = "!#$^&-<>"
}

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.name_prefix}-redis-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ec2" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = var.ec2_sg_id
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  description                  = "Allow EC2 instances to reach Redis"
}

resource "aws_elasticache_subnet_group" "this" {
  name        = "${var.name_prefix}-redis-subnet"
  description = "Subnet group for ElastiCache Redis"
  subnet_ids  = var.subnet_ids
}

resource "aws_elasticache_parameter_group" "this" {
  family      = "redis7"
  name        = "${var.name_prefix}-redis-params"
  description = "Redis 7 parameter group for postech services"

  parameter {
    name  = "timeout"
    value = "300"
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "${var.name_prefix}-redis"
  description                = "Redis cache for postech services"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = 1
  automatic_failover_enabled = false

  parameter_group_name = aws_elasticache_parameter_group.this.name
  port                 = var.port
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.redis.id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = random_password.auth.result

  tags = {
    Name      = "${var.name_prefix}-redis"
    ManagedBy = "terraform"
  }
}
