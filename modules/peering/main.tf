# ─── VPC Peering 생성 + 자동 수락 ─────────────────────────────────────────────
# 동일 계정 내 Peering이므로 auto_accept = true 사용 가능
# 요청 방향: MGMT → MAIN (requester = mgmt, accepter = main)

resource "aws_vpc_peering_connection" "mgmt_to_main" {
  vpc_id      = var.mgmt_vpc_id   # 요청 측 (Requester)
  peer_vpc_id = var.main_vpc_id   # 수락 측 (Accepter)
  auto_accept = true              # 동일 계정이므로 자동 수락

  tags = {
    Name = "KJW-PEERING-MGMT-MAIN"
    Side = "requester"
  }
}

# ─── MAIN VPC RT에 MGMT 경로 추가 ────────────────────────────────────────────
# 경로 추가 대상: RT-APP-Azone, RT-APP-Czone, RT-DB
# 목적지: MGMT VPC CIDR (10.1.0.0/16) → Peering

resource "aws_route" "main_app_a_to_mgmt" {
  route_table_id            = var.main_rt_app_a_id
  destination_cidr_block    = var.mgmt_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.mgmt_to_main.id
}

resource "aws_route" "main_app_c_to_mgmt" {
  route_table_id            = var.main_rt_app_c_id
  destination_cidr_block    = var.mgmt_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.mgmt_to_main.id
}

# RT-DB에도 MGMT 경로 추가 — MGMT OpenVPN 경유 Aurora 직접 접속 지원
resource "aws_route" "main_db_to_mgmt" {
  route_table_id            = var.main_rt_db_id
  destination_cidr_block    = var.mgmt_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.mgmt_to_main.id
}

# ─── MGMT VPC RT에 MAIN 경로 추가 ────────────────────────────────────────────
# 목적지: MAIN VPC CIDR (10.0.0.0/16) → Peering

resource "aws_route" "mgmt_to_main" {
  route_table_id            = var.mgmt_rt_id
  destination_cidr_block    = var.main_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.mgmt_to_main.id
}
