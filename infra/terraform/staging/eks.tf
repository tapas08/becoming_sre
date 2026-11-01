data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/sre-playground-staging-eks-cluster/cluster"
  retention_in_days = 1
}

# 
#   ============= Cluster Role =============
#
data "aws_iam_policy_document" "staging_cluster_role_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "aws:TagKeys"
      values   = ["kubernetes.io/cluster/*"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeVpcs",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstanceTopology",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_role" "cluster_role" {
  name = "sre-playground-staging-cluster-role"

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

  tags = {
    Name = "sre-playground-staging-cluster-role"
    App  = "sre-playground"
  }
}

resource "aws_iam_policy" "staging_cluster_role_policy" {
  name   = "sre-playground-staging-cluster-role-policy"
  policy = data.aws_iam_policy_document.staging_cluster_role_policy_document.json
  tags = {
    App = "sre-playground"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_role_policy_attachment" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = aws_iam_policy.staging_cluster_role_policy.arn
}

# 
#   ============= Node Role =============
#

resource "aws_iam_role" "node_role" {
  name = "sre-playground-staging-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "sre-playground-staging-node-role"
    App  = "sre-playground"
  }
}

resource "aws_iam_role_policy_attachment" "node_role_policy_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_role_registry_policy_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

# 
#   ============= EKS Cluster =============
#
resource "aws_eks_cluster" "staging_eks_cluster" {
  name    = "sre-playground-staging-eks-cluster"
  version = "1.37"

  access_config {
    authentication_mode = "API"

    bootstrap_cluster_creator_admin_permissions = false
  }

  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true

    subnet_ids = [
      aws_subnet.staging_subnet_private_01.id,
      aws_subnet.staging_subnet_private_02.id
    ]
    public_access_cidrs = ["106.222.228.231/32"]
  }

  enabled_cluster_log_types = ["audit", "authenticator"]

  upgrade_policy {
    support_type = "STANDARD"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_role_policy_attachment,
    aws_cloudwatch_log_group.eks_cluster,
  ]

  tags = {
    App = "sre-playground"
    ENV = "staging"
  }

}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.staging_eks_cluster.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"

  tags = {
    App = "sre-playground"
  }
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.staging_eks_cluster.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}


# 
#   ============= EKS - Node Group =============
#

# Launch Template
resource "aws_launch_template" "staging_node_group_lt" {
  name = "sre-playground-staging-node-group-lt"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "sre-playground-staging-node-group-lt"
    App  = "sre-playground"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "sre-playground-staging-node"
      App  = "sre-playground"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      App = "sre-playground"
    }
  }
}

# Node Group
resource "aws_eks_node_group" "staging_node_group" {
  cluster_name    = aws_eks_cluster.staging_eks_cluster.name
  node_group_name = "sre-playground-staging-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids = [
    aws_subnet.staging_subnet_private_01.id,
    aws_subnet.staging_subnet_private_02.id
  ]
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.staging_node_group_lt.id
    version = aws_launch_template.staging_node_group_lt.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_role_policy_attachment,
    aws_iam_role_policy_attachment.node_role_registry_policy_attachment
  ]

  tags = {
    App = "sre-playground"
    ENV = "staging"
  }
}
