output "acm_arn_alb" {
  description = "ALB용 ACM 인증서 ARN (us-east-2). aws_acm_certificate_validation 완료 후 유효"
  value       = aws_acm_certificate_validation.alb.certificate_arn
}

output "acm_arn_cf" {
  description = "CloudFront용 ACM 인증서 ARN (us-east-1). aws_acm_certificate_validation 완료 후 유효"
  value       = aws_acm_certificate_validation.cf.certificate_arn
}
