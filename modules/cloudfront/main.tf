# ─── OAC (Origin Access Control) ────────────────────────────────────────────
# CloudFront → S3 접근을 IAM 서명 방식으로 제어 (구형 OAI 대체)

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "KJW-OAC-S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ─── S3 Bucket Policy (cloudfront 모듈 책임) ──────────────────────────────────
# s3 모듈은 버킷만 생성, OAC ARN이 확정된 이 시점에 policy를 생성

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "oac" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "arn:aws:s3:::${var.s3_bucket_id}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
        }
      }
    }]
  })
}

# ─── CloudFront Distribution ──────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  aliases             = [var.domain_name, "cdn.${var.domain_name}"]
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # 북미+유럽만 사용 (학습 환경 비용 절감)

  # ─── Origin 1: S3 (정적 콘텐츠) ────────────────────────────────────────────
  origin {
    origin_id                = "S3Origin"
    domain_name              = var.s3_bucket_regional_domain
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ─── Origin 2: ALB (동적 요청) ─────────────────────────────────────────────
  origin {
    origin_id   = "ALBOrigin"
    domain_name = var.alb_dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only" # ALB는 HTTPS만 허용
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ─── Cache Behavior: 정적 콘텐츠 → S3 ──────────────────────────────────────
  ordered_cache_behavior {
    path_pattern     = "/images/*"
    target_origin_id = "S3Origin"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400   # 1일
    max_ttl                = 604800  # 7일
  }

  ordered_cache_behavior {
    path_pattern     = "/css/*"
    target_origin_id = "S3Origin"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 604800
  }

  ordered_cache_behavior {
    path_pattern     = "/js/*"
    target_origin_id = "S3Origin"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 604800
  }

  # ─── Default Cache Behavior: 동적 요청 → ALB ────────────────────────────────
  default_cache_behavior {
    target_origin_id = "ALBOrigin"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"] # WordPress 동적 요청에 필요한 헤더 전달
      cookies { forward = "all" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0    # 동적 콘텐츠는 캐싱 안 함
    max_ttl                = 0
  }

  # ─── HTTPS 인증서 ─────────────────────────────────────────────────────────
  viewer_certificate {
    acm_certificate_arn      = var.acm_arn_cf
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(var.common_tags, {
    Name = "KJW-CLOUDFRONT"
  })
}
