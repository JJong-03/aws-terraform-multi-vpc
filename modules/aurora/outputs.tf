output "cluster_endpoint" {
  description = "Aurora Writer 엔드포인트 (쓰기 전용)"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Aurora Reader 엔드포인트 (읽기 분산용)"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_id" {
  description = "Aurora Cluster ID"
  value       = aws_rds_cluster.this.id
}
