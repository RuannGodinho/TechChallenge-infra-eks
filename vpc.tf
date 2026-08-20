resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.azs[count.index]
  cidr_block              = local.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                        = "${local.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "node" {
  name        = "${local.name}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Outbound: metrics-server, kubelet scrape, EKS API, DNS, image pulls.
  egress {
    description = "All outbound (API 443, kubelet 10250, DNS, registry)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-node-sg"
  })
}

resource "aws_security_group_rule" "node_api_nodeport" {
  description       = "API NodePort from k8s/Api-service.yml"
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_api_cidr]
}

resource "aws_security_group_rule" "node_self_ingress" {
  description       = "Allow nodes to communicate with each other (TCP)"
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "node_self_ingress_udp" {
  description       = "Allow nodes to communicate with each other (UDP, pod DNS between nodes)"
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  self              = true
}

# --- metrics-server / kubelet (TCP 10250) + aggregation (TCP 443) ---

# Pods (VPC CNI IPs in subnet CIDR) scrape kubelet stats for HPA.
resource "aws_security_group_rule" "node_kubelet_from_vpc" {
  description       = "metrics-server: kubelet 10250 from VPC pod/node IPs"
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

# Control plane and in-cluster components (APIService -> metrics-server, kubectl logs).
resource "aws_security_group_rule" "node_kubelet_from_cluster_sg" {
  description              = "metrics-server: kubelet 10250 from EKS cluster SG"
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# Worker nodes scrape each other's kubelet when metrics-server schedules elsewhere.
resource "aws_security_group_rule" "node_kubelet_from_self" {
  description       = "metrics-server: kubelet 10250 from same node SG"
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  self              = true
}

# APIService / aggregated metrics API reaches metrics-server HTTPS in kube-system.
resource "aws_security_group_rule" "node_metrics_https_from_cluster_sg" {
  description              = "metrics-server: HTTPS 443 from EKS cluster SG"
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "node_metrics_https_from_vpc" {
  description       = "metrics-server: HTTPS 443 from VPC (in-cluster callers)"
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

# Explicit outbound for metrics path (redundant with allow-all egress; documents intent).
resource "aws_security_group_rule" "node_metrics_egress_kubelet" {
  description       = "metrics-server: scrape kubelet 10250 within VPC"
  type              = "egress"
  security_group_id = aws_security_group.node.id
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "node_metrics_egress_https" {
  description       = "metrics-server: EKS Kubernetes API 443"
  type              = "egress"
  security_group_id = aws_security_group.node.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node_metrics_egress_dns_udp" {
  description       = "metrics-server: DNS UDP 53"
  type              = "egress"
  security_group_id = aws_security_group.node.id
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "node_metrics_egress_dns_tcp" {
  description       = "metrics-server: DNS TCP 53"
  type              = "egress"
  security_group_id = aws_security_group.node.id
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}
