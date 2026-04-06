output "cluster_name" {
  description = "EKS 클러스터 이름 (kubectl config에 사용)"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  description = "EKS 클러스터 CA 인증서 (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_sg_id" {
  description = "EKS Node Group에 연결된 Security Group ID"
  value       = var.sg_eks_node_id
}
