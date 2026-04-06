output "vpc_id" {
  value = aws_vpc.this.id
}

# ─── 서브넷 ID ────────────────────────────────────────────────────────────────

output "subnet_public_a_id" {
  value = aws_subnet.public_a.id
}

output "subnet_public_c_id" {
  value = aws_subnet.public_c.id
}

output "subnet_app_a_id" {
  value = aws_subnet.app_a.id
}

output "subnet_app_c_id" {
  value = aws_subnet.app_c.id
}

output "subnet_db_a_id" {
  value = aws_subnet.db_a.id
}

output "subnet_db_c_id" {
  value = aws_subnet.db_c.id
}

# ─── NATGW ID (peering 모듈에서 참조 불필요, 필요 시 사용) ─────────────────────

output "natgw_a_id" {
  value = aws_nat_gateway.a.id
}

output "natgw_c_id" {
  value = aws_nat_gateway.c.id
}

# ─── RT ID (peering 모듈에서 경로 추가에 사용) ────────────────────────────────

output "rt_app_a_id" {
  value = aws_route_table.app_a.id
}

output "rt_app_c_id" {
  value = aws_route_table.app_c.id
}

output "rt_db_id" {
  value = aws_route_table.db.id
}
