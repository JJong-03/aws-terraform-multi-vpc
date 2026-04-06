resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "KJW-IGW-MGMT"
  })
}

# RT-MGMT: 0.0.0.0/0 → IGW
# MAIN Peering 경로(10.0.0.0/16)는 peering 모듈에서 추가
resource "aws_route_table" "mgmt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name = "KJW-RT-MGMT"
  })
}

resource "aws_route_table_association" "mgmt_public" {
  subnet_id      = aws_subnet.mgmt_public.id
  route_table_id = aws_route_table.mgmt.id
}
