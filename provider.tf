# 기본 provider: us-east-2 (Ohio)
provider "aws" {
  region = var.aws_region
}

# alias provider: us-east-1 (Virginia)
# CloudFront용 ACM 인증서는 반드시 us-east-1에서 발급해야 함
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
