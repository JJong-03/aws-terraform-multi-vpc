# ─── Public 서브넷 ────────────────────────────────────────────────────────────
# ALB, NATGW 배치
# map_public_ip_on_launch = false: EC2가 이 서브넷에 들어와도 퍼블릭 IP 자동 부여 안 함
#   → 퍼블릭 IP가 필요한 리소스(OpenVPN 등)는 EC2 리소스에서 개별 지정
#   → MAIN VPC의 EC2 Nginx는 Private(APP 서브넷) 배치이므로 여기서는 불필요

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name                     = "KJW-SUBNET-PUBLIC-Azone"
    "kubernetes.io/role/elb" = "1" # EKS 및 향후 AWS Load Balancer 연동 호환성 확보용
  })
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.110.0/24"
  availability_zone       = var.az_c
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name                     = "KJW-SUBNET-PUBLIC-Czone"
    "kubernetes.io/role/elb" = "1" # EKS 및 향후 AWS Load Balancer 연동 호환성 확보용
  })
}

# ─── App 서브넷 (Private) ──────────────────────────────────────────────────────
# EC2 Nginx, EKS Node 배치

resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = var.az_a

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-APP-Azone"
  })
}

resource "aws_subnet" "app_c" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.130.0/24"
  availability_zone = var.az_c

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-APP-Czone"
  })
}

# ─── DB 서브넷 (Private) ───────────────────────────────────────────────────────
# Aurora Writer(A), Reader(C) 배치

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.50.0/24"
  availability_zone = var.az_a

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-DB-Azone"
  })
}

resource "aws_subnet" "db_c" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.150.0/24"
  availability_zone = var.az_c

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-DB-Czone"
  })
}
