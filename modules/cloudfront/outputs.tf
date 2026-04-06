output "cf_domain_name" {
  description = "CloudFront 배포 도메인 (Route53 Alias 레코드 대상)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cf_distribution_id" {
  description = "CloudFront Distribution ID (캐시 무효화 시 사용)"
  value       = aws_cloudfront_distribution.this.id
}

output "cf_hosted_zone_id" {
  description = "CloudFront Hosted Zone ID (Route53 Alias 레코드의 alias.zone_id에 사용)"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}
