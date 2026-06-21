resource "aws_security_group" "opensearch" {
  name        = "${var.name_prefix}-opensearch-sg"
  description = "Security group for OpenSearch domain"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.name_prefix}-opensearch-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "opensearch_from_ec2" {
  security_group_id            = aws_security_group.opensearch.id
  referenced_security_group_id = var.ec2_sg_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow EC2 instances to reach OpenSearch over HTTPS"
}

resource "aws_opensearch_domain" "this" {
  domain_name    = "${var.name_prefix}-games"
  engine_version = var.engine_version

  cluster_config {
    instance_type  = var.instance_type
    instance_count = var.instance_count
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  # VPC-only domain: permissive access policy; network security is handled by the SG
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "es:*"
        Resource  = "arn:aws:es:${var.aws_region}:*:domain/${var.name_prefix}-games/*"
      }
    ]
  })

  tags = {
    Name      = "${var.name_prefix}-games"
    ManagedBy = "terraform"
  }
}
