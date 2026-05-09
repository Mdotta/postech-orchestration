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

data "aws_caller_identity" "current" {}

locals {
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  image        = "${local.ecr_registry}/${var.ecr_repo_name}:${var.image_tag}"
  container    = "${var.name_prefix}-${var.service_name}"
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_pair_name
  iam_instance_profile        = data.aws_iam_instance_profile.existing.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region     = var.aws_region
    ecr_registry   = local.ecr_registry
    image          = local.image
    container_name = local.container
    container_port = var.container_port
    env            = var.env
  })

  tags = {
    Name       = var.instance_name_tag
    ManagedBy  = "terraform"
    Service    = var.service_name
    NamePrefix = var.name_prefix
  }
}

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name      = "${var.name_prefix}-${var.service_name}-eip"
    ManagedBy = "terraform"
  }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}

