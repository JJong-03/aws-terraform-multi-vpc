output "alb_arn" {
  description = "ALB ARN (WAF association에 사용됨)"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB DNS 이름 (CloudFront Origin, Route53 Alias 레코드에 사용)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB Hosted Zone ID (Route53 Alias 레코드의 alias.zone_id에 사용)"
  value       = aws_lb.this.zone_id
}

output "tg_arn_ec2" {
  description = "EC2 Target Group ARN (ec2-web ASG attachment에 사용)"
  value       = aws_lb_target_group.ec2.arn
}
