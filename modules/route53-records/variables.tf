variable "zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "domain_name" {
  description = "루트 도메인 (예: kjw-cloud.site)"
  type        = string
}

variable "cf_domain_name" {
  description = "CloudFront 배포 도메인 (Alias 레코드 대상)"
  type        = string
}

variable "cf_hosted_zone_id" {
  description = "CloudFront Hosted Zone ID (Alias 레코드 구성에 필수)"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS 이름 (테스트용 서브도메인 레코드에 사용)"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB Hosted Zone ID (Alias 레코드 구성에 필수)"
  type        = string
}
