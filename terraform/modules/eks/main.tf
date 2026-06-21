data "aws_caller_identity" "current" {}

# ── IAM (use pre-existing roles if provided, otherwise create) ──────────────

data "aws_iam_role" "cluster" {
  name = var.existing_cluster_role_name
}

data "aws_iam_role" "node" {
  name = var.existing_node_role_name
}

locals {
  cluster_role_arn = var.existing_cluster_role_name != "" ? data.aws_iam_role.cluster.arn : aws_iam_role.cluster[0].arn
  node_role_arn    = var.existing_node_role_name != "" ? data.aws_iam_role.node.arn : aws_iam_role.node[0].arn
}

resource "aws_iam_role" "cluster" {
  count = var.existing_cluster_role_name != "" ? 0 : 1
  name  = "${var.name_prefix}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.name_prefix}-eks-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster" {
  count      = var.existing_cluster_role_name != "" ? 0 : 1
  role       = aws_iam_role.cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node" {
  count = var.existing_node_role_name != "" ? 0 : 1
  name  = "${var.name_prefix}-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.name_prefix}-eks-node-role" }
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  count      = var.existing_node_role_name != "" ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  count      = var.existing_node_role_name != "" ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  count      = var.existing_node_role_name != "" ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  count      = var.existing_node_role_name != "" ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Security Group ──────────────────────────────────────────────────────────

resource "aws_security_group" "cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.name_prefix}-eks-cluster-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cluster_https_self" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS within cluster SG"
}

# ── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-eks"
  role_arn = local.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.name_prefix}-eks"
    ManagedBy = "terraform"
  }
}

# ── Node Group ──────────────────────────────────────────────────────────────

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-eks-nodes"
  node_role_arn   = local.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count + 2
    min_size     = var.node_count
  }

  tags = {
    Name      = "${var.name_prefix}-eks-nodes"
    ManagedBy = "terraform"
  }
}
