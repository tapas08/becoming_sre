# Daemonset to hand out IAM credentials to pods
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.staging_eks_cluster.name
  addon_name   = "eks-pod-identity-agent"
}

# IAM role for CNI
# This will separate the CNI role from the node role, which is a best practice.
resource "aws_iam_role" "staging_cni_role" {
  name = "sre-playground-staging-cni-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    App = "sre-playground"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_role_policy_attachment" {
  role       = aws_iam_role.staging_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_addon" "staging_vpc_cni" {
  cluster_name                = aws_eks_cluster.staging_eks_cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"

  pod_identity_association {
    role_arn        = aws_iam_role.staging_cni_role.arn
    service_account = "aws-node"
  }

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.vpc_cni_role_policy_attachment,
  ]
}

# Kube-proxy addon
resource "aws_eks_addon" "staging_kube_proxy" {
  cluster_name                = aws_eks_cluster.staging_eks_cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
}

# coredns addon
resource "aws_eks_addon" "staging_coredns" {
  cluster_name                = aws_eks_cluster.staging_eks_cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
}

# CSI Driver addon
resource "aws_iam_role" "csi_role" {
  name = "sre-playground-staging-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "csi_role_policy_attachment" {
  role       = aws_iam_role.csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "staging_ebs_csi_driver" {
  cluster_name = aws_eks_cluster.staging_eks_cluster.name
  addon_name   = "aws-ebs-csi-driver"

  pod_identity_association {
    role_arn        = aws_iam_role.csi_role.arn
    service_account = "ebs-csi-controller-sa"
  }

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.csi_role_policy_attachment
  ]
}