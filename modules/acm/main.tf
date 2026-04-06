# =============================================================================
# ACM 모듈 — provider alias 선언 필수
# 루트 main.tf의 providers = { aws = aws, aws.us_east_1 = aws.us_east_1 } 블록으로
# 이 모듈에 두 provider가 전달됨
# =============================================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 이 모듈이 aws (us-east-2) 와 aws.us_east_1 두 provider를 모두 사용함을 선언
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ─── ALB용 인증서 (us-east-2) ─────────────────────────────────────────────────
# ALB는 us-east-2 리전에 있으므로 동일 리전 인증서 사용

resource "aws_acm_certificate" "alb" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    # 인증서 교체 시 새 인증서를 먼저 만든 뒤 이전 것을 삭제 (ALB 무중단)
    create_before_destroy = true
  }

  tags = {
    Name   = "KJW-ACM-ALB"
    Region = "us-east-2"
  }
}

# ─── CloudFront용 인증서 (us-east-1) ──────────────────────────────────────────
# CloudFront는 us-east-1 리전 ACM 인증서만 사용 가능 (AWS 제약)

resource "aws_acm_certificate" "cf" {
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name   = "KJW-ACM-CF"
    Region = "us-east-1"
  }
}

# ─── DNS Validation 레코드 ────────────────────────────────────────────────────
# Route53은 글로벌 서비스 → 기본 provider(us-east-2) 사용
# allow_overwrite = true: 두 인증서가 동일 도메인이면 같은 CNAME 레코드를 공유

resource "aws_route53_record" "alb_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 300
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_route53_record" "cf_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cf.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 300
  records         = [each.value.record]
  allow_overwrite = true
}

# ─── 인증서 발급 완료 대기 ────────────────────────────────────────────────────
# apply 시 DNS 전파 + CA 검증까지 수분 소요 (최대 30분)
# 이 리소스가 완료돼야 alb, cloudfront 모듈이 ARN을 사용할 수 있음

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for r in aws_route53_record.alb_validation : r.fqdn]
}

resource "aws_acm_certificate_validation" "cf" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cf.arn
  validation_record_fqdns = [for r in aws_route53_record.cf_validation : r.fqdn]
}
