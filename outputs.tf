# ─── VPC ─────────────────────────────────────────────────────────────────────

output "main_vpc_id" {
  description = "MAIN VPC ID"
  value       = module.vpc_main.vpc_id
}

output "mgmt_vpc_id" {
  description = "MGMT VPC ID"
  value       = module.vpc_mgmt.vpc_id
}

output "service_vpc_id" {
  description = "SERVICE VPC ID"
  value       = module.vpc_service.vpc_id
}

# ─── ALB ─────────────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "Public ALB DNS 이름"
  value       = module.alb.alb_dns_name
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS 클러스터 API 엔드포인트"
  value       = module.eks.cluster_endpoint
}

# ─── Aurora ──────────────────────────────────────────────────────────────────

output "aurora_writer_endpoint" {
  description = "Aurora Writer 엔드포인트"
  value       = module.aurora.cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora Reader 엔드포인트"
  value       = module.aurora.reader_endpoint
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

output "ecr_repository_url" {
  description = "ECR 리포지토리 URL"
  value       = module.ecr.repository_url
}

# ─── CloudFront / Route53 ─────────────────────────────────────────────────────

output "cloudfront_domain_name" {
  description = "CloudFront 배포 도메인"
  value       = module.cloudfront.cf_domain_name
}

output "route53_name_servers" {
  description = "Route53 NS 레코드 (도메인 등록 기관에 설정 필요)"
  value       = module.route53_zone.name_servers
}

# ─── OpenVPN ─────────────────────────────────────────────────────────────────

output "openvpn_public_ip" {
  description = "OpenVPN EC2 퍼블릭 IP"
  value       = module.ec2_openvpn.public_ip
}
