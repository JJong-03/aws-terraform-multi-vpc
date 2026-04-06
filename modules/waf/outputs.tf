output "waf_arn" {
  description = "WAF ACL ARN (ALB association에 사용)"
  value       = aws_wafv2_web_acl.this.arn
}
