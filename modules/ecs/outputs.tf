output "cluster_id" {
  description = "ECS 클러스터 ID"
  value       = aws_ecs_cluster.this.id
}

output "service_name" {
  description = "ECS 서비스 이름"
  value       = aws_ecs_service.wp.name
}
