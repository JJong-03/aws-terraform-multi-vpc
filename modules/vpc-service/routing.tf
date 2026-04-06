resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "KJW-IGW-SERVICE"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "KJW-EIP-NATGW-SERVICE"
  })
}

# NATGW는 PUBLIC 서브넷에 배치
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.service_public.id

  tags = merge(var.common_tags, {
    Name = "KJW-NATGW-SERVICE"
  })

  depends_on = [aws_internet_gateway.this]
}

# RT-SERVICE-PUBLIC: 0.0.0.0/0 → IGW
resource "aws_route_table" "service_public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name = "KJW-RT-SERVICE-PUBLIC"
  })
}

resource "aws_route_table_association" "service_public" {
  subnet_id      = aws_subnet.service_public.id
  route_table_id = aws_route_table.service_public.id
}

# RT-SERVICE-PRIVATE: 0.0.0.0/0 → NATGW (ECR 이미지 pull 경로)
resource "aws_route_table" "service_private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name = "KJW-RT-SERVICE-PRIVATE"
  })
}

resource "aws_route_table_association" "service_private" {
  subnet_id      = aws_subnet.service_private.id
  route_table_id = aws_route_table.service_private.id
}
