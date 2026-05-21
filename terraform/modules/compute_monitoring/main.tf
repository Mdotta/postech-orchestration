data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_iam_instance_profile" "existing" {
  name = var.iam_instance_profile_name
}

resource "aws_security_group" "monitoring" {
  name        = "${var.name_prefix}-monitoring-sg"
  description = "Security group for Prometheus + Grafana monitoring instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.name_prefix}-monitoring-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = data.aws_iam_instance_profile.existing.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    scrape_targets         = var.scrape_targets
    grafana_admin_password = var.grafana_admin_password
  })

  tags = {
    Name       = "${var.name_prefix}-monitoring"
    ManagedBy  = "terraform"
    Service    = "monitoring"
    NamePrefix = var.name_prefix
  }
}

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name      = "${var.name_prefix}-monitoring-eip"
    ManagedBy = "terraform"
  }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
