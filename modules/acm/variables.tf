variable "domain_name" {
  description = "ACM 인증서 도메인 (예: kjw-cloud.site)"
  type        = string
}

variable "zone_id" {
  description = "DNS Validation 레코드를 생성할 Route53 Hosted Zone ID"
  type        = string
}
