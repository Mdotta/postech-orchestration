data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_iam_instance_profile" "existing" {
  name = var.iam_instance_profile_name
}

resource "aws_security_group" "elasticsearch" {
  name        = "${var.name_prefix}-elasticsearch-sg"
  description = "Security group for self-hosted Elasticsearch container"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Elasticsearch API"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [var.ec2_sg_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.name_prefix}-elasticsearch-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.elasticsearch.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing.name
  associate_public_ip_address = true

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -euo pipefail

    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf

    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker

    docker rm -f elasticsearch 2>/dev/null || true

    docker run -d \
      --name elasticsearch \
      --restart unless-stopped \
      --ulimit memlock=-1:-1 \
      -p 9200:9200 \
      -e "discovery.type=single-node" \
      -e "xpack.security.enabled=false" \
      -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
      docker.elastic.co/elasticsearch/elasticsearch:8.17.0
    USERDATA
  )

  tags = {
    Name      = "${var.name_prefix}-elasticsearch"
    ManagedBy = "terraform"
  }
}
