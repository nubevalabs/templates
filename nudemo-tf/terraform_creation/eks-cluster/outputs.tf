output "eks_cluster_name" {
  value = aws_eks_cluster.nubeva-controller.name
}

output "cluster_ready" {
  value = aws_eks_node_group.nodes
}