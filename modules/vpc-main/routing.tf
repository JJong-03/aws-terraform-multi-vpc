# ─── IGW ─────────────────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "KJW-IGW-MAIN"
  })
}

# ─── EIP + NATGW (AZ별 각 1개) ───────────────────────────────────────────────
# NATGW는 Public 서브넷에 배치, 각 AZ에 독립 구성 (AZ 장애 격리)

resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "KJW-EIP-NATGW-A"
  })
}

resource "aws_eip" "nat_c" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "KJW-EIP-NATGW-C"
  })
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = merge(var.common_tags, {
    Name = "KJW-NATGW-A"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id     = aws_subnet.public_c.id

  tags = merge(var.common_tags, {
    Name = "KJW-NATGW-C"
  })

  depends_on = [aws_internet_gateway.this]
}

# ─── 라우팅 테이블 ────────────────────────────────────────────────────────────

# RT-IGW: Public 서브넷 (0.0.0.0/0 → IGW)
resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, {
    Name = "KJW-RT-IGW"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.igw.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.igw.id
}

# RT-APP-Azone: APP-A Private (0.0.0.0/0 → NATGW-A)
# MGMT Peering 경로(10.1.0.0/16)는 peering 모듈에서 추가
resource "aws_route_table" "app_a" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }

  tags = merge(var.common_tags, {
    Name = "KJW-RT-APP-Azone"
  })
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.app_a.id
}

# RT-APP-Czone: APP-C Private (0.0.0.0/0 → NATGW-C)
resource "aws_route_table" "app_c" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.c.id
  }

  tags = merge(var.common_tags, {
    Name = "KJW-RT-APP-Czone"
  })
}

resource "aws_route_table_association" "app_c" {
  subnet_id      = aws_subnet.app_c.id
  route_table_id = aws_route_table.app_c.id
}

# RT-DB: DB Private (local only)
# MGMT Peering 경로(10.1.0.0/16)는 peering 모듈에서 추가
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "KJW-RT-DB"
  })
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_c" {
  subnet_id      = aws_subnet.db_c.id
  route_table_id = aws_route_table.db.id
}
