# =============================================================================
# Route53 레코드 — 모든 upstream(CloudFront, ALB, ACM) 완료 후 마지막 단계
# ACM DNS Validation 레코드는 acm 모듈에서 처리 (이 모듈에는 없음)
# =============================================================================

# ─── 메인 도메인 → CloudFront (Alias A 레코드) ────────────────────────────────
# kjw-cloud.site → CloudFront
# 메인 도메인은 CloudFront만 바라봄. ALB direct 레코드 없음.

resource "aws_route53_record" "root" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_hosted_zone_id
    evaluate_target_health = false # CloudFront는 자체 고가용성 유지, health check 불필요
  }
}

# ─── CDN 서브도메인 → CloudFront (Alias A 레코드) ────────────────────────────
# cdn.kjw-cloud.site → CloudFront (동일 Distribution)

resource "aws_route53_record" "cdn" {
  zone_id = var.zone_id
  name    = "cdn.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cf_domain_name
    zone_id                = var.cf_hosted_zone_id
    evaluate_target_health = false
  }
}

# ─── ALB 테스트용 서브도메인 (CNAME) ─────────────────────────────────────────
# alb.kjw-cloud.site → ALB DNS
# 목적: CloudFront 우회하여 ALB 직접 접근 (디버깅/헬스체크 확인용)
# 운영 환경에서는 이 레코드를 제거하거나 액세스를 제한할 것을 권장

resource "aws_route53_record" "alb_test" {
  zone_id = var.zone_id
  name    = "alb.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true # ALB health check 연동
  }
}
