resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # EC2/RDS 등에 퍼블릭 DNS 호스트명 부여
  enable_dns_support   = true  # VPC 내부 DNS 확인자(Route53 Resolver) 활성화 — EKS, Aurora 내부 DNS 이름 해석에 필수

  tags = merge(var.common_tags, {
    Name = "KJW-VPC-0323"
  })
}
