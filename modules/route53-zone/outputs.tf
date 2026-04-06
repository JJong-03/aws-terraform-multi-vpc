output "zone_id" {
  description = "Hosted Zone ID (acm 모듈 DNS validation에 사용)"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "NS 레코드 목록 (도메인 등록 기관에 설정 필요)"
  value       = aws_route53_zone.this.name_servers
}
