variable "s3_bucket_id" {
  description = "정적 콘텐츠 S3 버킷 이름 (OAC bucket policy 생성에 사용)"
  type        = string
}

variable "s3_bucket_regional_domain" {
  description = "S3 버킷 리전 도메인 (CloudFront S3 Origin 주소)"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS 이름 (CloudFront ALB Origin 주소)"
  type        = string
}

variable "acm_arn_cf" {
  description = "CloudFront용 ACM 인증서 ARN (반드시 us-east-1 발급본)"
  type        = string
}

variable "domain_name" {
  description = "CloudFront Alternate Domain (예: kjw-cloud.site)"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
