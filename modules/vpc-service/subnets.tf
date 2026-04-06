# PUBLIC: NATGW 전용 (ECS는 여기에 배치하지 않음)
resource "aws_subnet" "service_public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.2.10.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-SERVICE-PUBLIC"
  })
}

# PRIVATE: ECS/Fargate Task 배치 / Public IP 비활성화
resource "aws_subnet" "service_private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.2.20.0/24"
  availability_zone = var.az_a

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-SERVICE-PRIVATE"
  })
}
