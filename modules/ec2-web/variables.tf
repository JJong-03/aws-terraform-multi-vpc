variable "subnet_app_a_id" {
  description = "MAIN VPC APP-Azone 서브넷 ID"
  type        = string
}

variable "subnet_app_c_id" {
  description = "MAIN VPC APP-Czone 서브넷 ID"
  type        = string
}

variable "sg_web_id" {
  description = "EC2 Nginx Security Group ID"
  type        = string
}

variable "alb_tg_ec2_arn" {
  description = "ALB EC2 Target Group ARN (ASG attachment에 사용)"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair 이름"
  type        = string
}

variable "eks_service_endpoint" {
  description = <<-EOT
    Nginx proxy_pass 대상 주소 (EKS 내부 Service ClusterIP 또는 내부 DNS).
    초기 apply 시 "placeholder" 사용 → EKS Service 생성 후 실제 값으로 교체 → terraform apply -target=module.ec2_web
  EOT
  type        = string
}

variable "eks_nodeport" {
  description = "Nginx proxy_pass 대상 포트 (EKS NodePort 또는 ClusterIP 포트)"
  type        = number
  default     = 30080
}

variable "ami_id" {
  description = "EC2 AMI ID (Ubuntu 24.04 LTS). 비워두면 data.aws_ami로 동적 조회 (ec2:DescribeImages 권한 필요)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
