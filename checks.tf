check "lab_role_exclusive" {
  assert {
    condition     = !(var.use_lab_role && var.create_iam_resources)
    error_message = "Set use_lab_role = true OR create_iam_resources = true, not both."
  }
}

check "iam_roles_when_not_creating" {
  assert {
    condition = var.use_lab_role || var.create_iam_resources || (
      var.cluster_role_arn != "" && var.node_role_arn != ""
    )
    error_message = "When create_iam_resources is false and use_lab_role is false, set cluster_role_arn and node_role_arn."
  }
}

check "ebs_csi_role_when_needed" {
  assert {
    condition     = !var.enable_ebs_csi || var.use_lab_role || var.create_iam_resources || var.ebs_csi_role_arn != ""
    error_message = "When enable_ebs_csi is true without use_lab_role or create_iam_resources, set ebs_csi_role_arn."
  }
}

check "cluster_admin_principal_iam_arn" {
  assert {
    condition = alltrue([
      for arn in local.cluster_admin_principals :
      startswith(arn, "arn:aws:iam::") && !startswith(arn, "arn:aws:sts::")
    ])
    error_message = "EKS access entry principals must be IAM ARNs (arn:aws:iam::...), not STS session ARNs (arn:aws:sts::...)."
  }
}
