# Node group is ACTIVE before EC2 instances join the cluster as Ready.
resource "time_sleep" "wait_for_nodes" {
  count = var.enable_ebs_csi ? 1 : 0

  create_duration = "${var.ebs_csi_addon_delay_seconds}s"

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_access_policy_association.cluster_admin,
  ]
}

# Core networking addons must be healthy before EBS CSI (needs DNS -> ec2.us-east-1.amazonaws.com).
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_ebs_csi ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_access_policy_association.cluster_admin,
    time_sleep.wait_for_nodes,
  ]
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_ebs_csi ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    replicaCount = var.coredns_replica_count
    autoScaling = {
      enabled     = var.coredns_replica_count >= 2
      minReplicas = max(var.coredns_replica_count, 2)
      maxReplicas = max(var.coredns_replica_count, 2)
    }
  })

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_access_policy_association.cluster_admin,
    time_sleep.wait_for_nodes,
    aws_eks_addon.vpc_cni,
  ]
}

resource "time_sleep" "wait_for_coredns" {
  count = var.enable_ebs_csi ? 1 : 0

  create_duration = "60s"

  depends_on = [aws_eks_addon.coredns]
}

# Academy LabRole: no Pod Identity / IRSA (LabRole trust policy cannot be changed).
# Install EBS CSI without service_account_role_arn so the driver uses the node LabRole via IMDS.
resource "aws_eks_addon" "ebs_csi_lab" {
  count = var.enable_ebs_csi && var.use_lab_role ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_eks_access_policy_association.cluster_admin,
    time_sleep.wait_for_nodes,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    time_sleep.wait_for_coredns,
  ]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# Personal account / IRSA: dedicated role via OIDC.
resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi && !var.use_lab_role ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = local.ebs_csi_role_arn

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_eks_access_policy_association.cluster_admin,
    time_sleep.wait_for_nodes,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    time_sleep.wait_for_coredns,
    aws_iam_role_policy_attachment.ebs_csi,
  ]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
