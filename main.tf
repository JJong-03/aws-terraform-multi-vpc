# =============================================================================
# Phase 5 — 멀티 VPC 아키텍처 루트 모듈
# 모듈 생성 순서: 단계별로 주석 해제하여 apply
# =============================================================================

# ─── 단계 1: 독립 리소스 (병렬 생성 가능) ────────────────────────────────────

module "ecr" {
  source          = "./modules/ecr"
  repository_name = "kjw-ecr-wp"
  common_tags     = var.common_tags
}

module "s3" {
  source      = "./modules/s3"
  bucket_name = "${lower(var.project_prefix)}-static-${var.aws_region}"
  common_tags = var.common_tags
}

module "waf" {
  source      = "./modules/waf"
  name        = "${var.project_prefix}-WAF-ACL"
  common_tags = var.common_tags
}

module "route53_zone" {
  source      = "./modules/route53-zone"
  domain_name = var.domain_name
}

# ─── 단계 2: VPC 3개 (병렬 생성 가능) ───────────────────────────────────────

module "vpc_main" {
  source      = "./modules/vpc-main"
  vpc_cidr    = var.main_vpc_cidr
  az_a        = var.az_a
  az_c        = var.az_c
  common_tags = var.common_tags
}

module "vpc_mgmt" {
  source      = "./modules/vpc-mgmt"
  vpc_cidr    = var.mgmt_vpc_cidr
  az_a        = var.az_a
  common_tags = var.common_tags
}

module "vpc_service" {
  source      = "./modules/vpc-service"
  vpc_cidr    = var.service_vpc_cidr
  az_a        = var.az_a
  common_tags = var.common_tags
}

# ─── 단계 3: VPC Peering ─────────────────────────────────────────────────────

module "peering" {
  source         = "./modules/peering"
  main_vpc_id    = module.vpc_main.vpc_id
  mgmt_vpc_id    = module.vpc_mgmt.vpc_id
  main_vpc_cidr  = var.main_vpc_cidr
  mgmt_vpc_cidr  = var.mgmt_vpc_cidr
  main_rt_app_a_id = module.vpc_main.rt_app_a_id
  main_rt_app_c_id = module.vpc_main.rt_app_c_id
  main_rt_db_id    = module.vpc_main.rt_db_id
  mgmt_rt_id       = module.vpc_mgmt.rt_mgmt_id
}

# ─── 단계 4: 보안 그룹 ───────────────────────────────────────────────────────

module "security_groups" {
  source              = "./modules/security-groups"
  main_vpc_id         = module.vpc_main.vpc_id
  mgmt_vpc_id         = module.vpc_mgmt.vpc_id
  service_vpc_id      = module.vpc_service.vpc_id
  openvpn_client_cidr = var.openvpn_client_cidr
  mgmt_vpc_cidr       = var.mgmt_vpc_cidr
  nginx_to_eks_port   = var.nginx_to_eks_port
  openvpn_admin_cidr  = var.openvpn_admin_cidr
}

# ─── 단계 5: ACM 인증서 ──────────────────────────────────────────────────────

module "acm" {
  source      = "./modules/acm"
  domain_name = var.domain_name
  zone_id     = module.route53_zone.zone_id

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# ─── 단계 6: ALB ─────────────────────────────────────────────────────────────

module "alb" {
  source              = "./modules/alb"
  subnet_public_a_id  = module.vpc_main.subnet_public_a_id
  subnet_public_c_id  = module.vpc_main.subnet_public_c_id
  sg_alb_id           = module.security_groups.sg_alb_id
  acm_arn_alb         = module.acm.acm_arn_alb
  waf_arn             = module.waf.waf_arn
  vpc_id              = module.vpc_main.vpc_id
  common_tags         = var.common_tags
}

# ─── 단계 7: 컴퓨팅 (병렬 생성 가능) ────────────────────────────────────────

module "eks" {
  source                  = "./modules/eks"
  cluster_name            = "${var.project_prefix}-EKS-CLUSTER"
  subnet_app_a_id         = module.vpc_main.subnet_app_a_id
  subnet_app_c_id         = module.vpc_main.subnet_app_c_id
  sg_eks_node_id          = module.security_groups.sg_eks_node_id
  eks_public_access_cidrs = var.eks_public_access_cidrs
  common_tags             = var.common_tags
}

module "aurora" {
  source          = "./modules/aurora"
  subnet_db_a_id  = module.vpc_main.subnet_db_a_id
  subnet_db_c_id  = module.vpc_main.subnet_db_c_id
  sg_db_id        = module.security_groups.sg_db_id
  db_name         = "kjwdb"
  db_username     = "admin"
  db_password     = var.db_password
  common_tags     = var.common_tags
}

module "ec2_openvpn" {
  source                  = "./modules/ec2-openvpn"
  subnet_mgmt_public_id   = module.vpc_mgmt.subnet_mgmt_public_id
  sg_openvpn_id           = module.security_groups.sg_openvpn_id
  key_name                = var.key_name
  ami_id                  = var.ami_id_ubuntu_22
  common_tags             = var.common_tags
}

module "ecs" {
  source                      = "./modules/ecs"
  subnet_service_private_id   = module.vpc_service.subnet_service_private_id
  sg_ecs_id                   = module.security_groups.sg_ecs_id
  ecr_repository_url          = module.ecr.repository_url
  common_tags                 = var.common_tags
}

# ─── 단계 8: EC2 Web ASG ─────────────────────────────────────────────────────

module "ec2_web" {
  source               = "./modules/ec2-web"
  subnet_app_a_id      = module.vpc_main.subnet_app_a_id
  subnet_app_c_id      = module.vpc_main.subnet_app_c_id
  sg_web_id            = module.security_groups.sg_web_id
  alb_tg_ec2_arn       = module.alb.tg_arn_ec2
  key_name             = var.key_name
  ami_id               = var.ami_id_ubuntu_24
  eks_service_endpoint = var.eks_service_endpoint
  eks_nodeport         = var.eks_nodeport
  common_tags          = var.common_tags
}

# ─── 단계 9: CloudFront ──────────────────────────────────────────────────────

module "cloudfront" {
  source                       = "./modules/cloudfront"
  s3_bucket_id                 = module.s3.bucket_id
  s3_bucket_regional_domain    = module.s3.bucket_regional_domain_name
  alb_dns_name                 = module.alb.alb_dns_name
  acm_arn_cf                   = module.acm.acm_arn_cf
  domain_name                  = var.domain_name
  common_tags                  = var.common_tags
}

# ─── 단계 10: Route53 레코드 ─────────────────────────────────────────────────

module "route53_records" {
  source              = "./modules/route53-records"
  zone_id             = module.route53_zone.zone_id
  domain_name         = var.domain_name
  cf_domain_name      = module.cloudfront.cf_domain_name
  cf_hosted_zone_id   = module.cloudfront.cf_hosted_zone_id
  alb_dns_name        = module.alb.alb_dns_name
  alb_zone_id         = module.alb.alb_zone_id
}
