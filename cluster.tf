resource "aws_iam_role" "cluster" {
  count = var.create_iam_resources ? 1 : 0

  name = "${local.name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_amazon_eks_cluster_policy" {
  count = var.create_iam_resources ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = local.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids             = aws_subnet.public[*].id
    endpoint_public_access = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy,
  ]

  tags = local.common_tags
}

resource "aws_security_group_rule" "node_cluster_ingress" {
  description              = "Allow control plane to communicate with nodes (TCP)"
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "node_cluster_ingress_udp" {
  description              = "Allow control plane to communicate with nodes (UDP, DNS, etc.)"
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "udp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

data "tls_certificate" "cluster" {
  count = var.create_iam_resources ? 1 : 0

  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.create_iam_resources ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = local.common_tags
}

resource "aws_eks_access_entry" "cluster_admin" {
  for_each = toset(local.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = aws_eks_access_entry.cluster_admin

  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value.principal_arn

  access_scope {
    type = "cluster"
  }
}
