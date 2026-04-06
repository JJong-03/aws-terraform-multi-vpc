# OpenVPN EC2 배치
# map_public_ip_on_launch = false: 서브넷 수준에서 자동 부여 비활성화
#   → OpenVPN EC2의 퍼블릭 IP는 ec2-openvpn 모듈에서 associate_public_ip_address = true 로 명시 지정
#   → MAIN VPC와 달리 MGMT VPC의 OpenVPN은 인터넷 진입점이므로 퍼블릭 IP 필수

resource "aws_subnet" "mgmt_public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.1.10.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "KJW-SUBNET-MGMT-PUBLIC"
  })
}
