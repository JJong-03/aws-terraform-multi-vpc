terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend는 local 기준 (추후 S3 remote state로 전환 가능)
  # backend "s3" {}
}
