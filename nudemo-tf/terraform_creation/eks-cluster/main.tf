# EKS
resource "aws_iam_role" "eks-master" {
  depends_on         = [var.dependencies]
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  depends_on = [var.dependencies]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  depends_on = [var.dependencies]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-master.name
}

resource "aws_eks_cluster" "nubeva-controller" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks-master.arn
  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [aws_iam_role_policy_attachment.AmazonEKSClusterPolicy, aws_iam_role_policy_attachment.AmazonEKSServicePolicy]

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    subnet_ids              = var.private_subnet_ids # EKS requires at least 2 subnets in different availability zones
    security_group_ids      = [var.endpoint_sg_id]
  }
}

# EKS nodes IAM
resource "aws_iam_role" "eks-nodes" {
  depends_on = [var.dependencies]
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  depends_on = [var.dependencies]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  depends_on = [var.dependencies]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-nodes.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  depends_on = [var.dependencies]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-nodes.name
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.nubeva-controller.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks-nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.xlarge"]

  scaling_config {
    desired_size = 4
    max_size     = 4
    min_size     = 4
  }

  remote_access {
    ec2_ssh_key               = var.ec2_key_pair_name
    source_security_group_ids = [var.endpoint_sg_id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}