output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_mgmt_public_id" {
  value = aws_subnet.mgmt_public.id
}

output "rt_mgmt_id" {
  description = "MGMT RT ID (peering 모듈에서 MAIN 경로 추가에 사용)"
  value       = aws_route_table.mgmt.id
}
