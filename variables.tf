# ─── 리전 / AZ ───────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS 기본 리전"
  type        = string
  default     = "us-east-2"
}

variable "az_a" {
  description = "가용 영역 A (us-east-2a 고정)"
  type        = string
  default     = "us-east-2a"
}

variable "az_c" {
  description = "가용 영역 C (us-east-2c 고정)"
  type        = string
  default     = "us-east-2c"
}

# ─── 프로젝트 공통 ────────────────────────────────────────────────────────────

variable "project_prefix" {
  description = "모든 리소스 Name 태그에 붙는 접두사"
  type        = string
  default     = "KJW"
}

variable "domain_name" {
  description = "Route53 Hosted Zone 도메인 (terraform.tfvars에 직접 입력)"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair 이름 (terraform.tfvars에 직접 입력)"
  type        = string
}

variable "common_tags" {
  description = "모든 리소스에 공통 적용할 태그"
  type        = map(string)
  default = {
    Project   = "KJW-Phase5"
    ManagedBy = "Terraform"
  }
}

# ─── VPC CIDR ────────────────────────────────────────────────────────────────

variable "main_vpc_cidr" {
  description = "MAIN VPC CIDR (KJW-VPC-0323)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "mgmt_vpc_cidr" {
  description = "MGMT VPC CIDR (KJW-VPC-MGMT)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "service_vpc_cidr" {
  description = "SERVICE VPC CIDR (KJW-VPC-SERVICE)"
  type        = string
  default     = "10.2.0.0/16"
}

# ─── 보안 그룹 변수 ───────────────────────────────────────────────────────────

variable "openvpn_client_cidr" {
  description = "OpenVPN 클라이언트 대역 (SSH 허용 소스). MGMT VPC CIDR 또는 OpenVPN NAT 대역"
  type        = string
  default     = "10.1.0.0/16"
}

variable "nginx_to_eks_port" {
  description = "EC2 Nginx → EKS NodePort 허용 포트 (최소 권한)"
  type        = number
  default     = 30080
}

variable "openvpn_admin_cidr" {
  description = "OpenVPN Admin Web UI(TCP 943) 허용 소스 CIDR. 운영 환경에서는 관리자 IP/32로 제한 권장"
  type        = string
  default     = "0.0.0.0/0"
}

variable "eks_public_access_cidrs" {
  description = "EKS API 퍼블릭 엔드포인트 허용 CIDR 목록. 운영 환경에서는 관리자 IP/32로 제한 권장"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ─── Aurora DB ────────────────────────────────────────────────────────────────

variable "db_password" {
  description = "Aurora MySQL admin 패스워드 (terraform.tfvars에 평문 입력, .gitignore 처리 필수)"
  type        = string
  sensitive   = true
}

# ─── EC2 AMI ID (ec2:DescribeImages 권한 없을 때 직접 지정) ─────────────────────

variable "ami_id_ubuntu_24" {
  description = "Ubuntu 24.04 LTS AMI ID (us-east-2). 비워두면 data.aws_ami 동적 조회 (ec2:DescribeImages 필요)"
  type        = string
  default     = ""
}

variable "ami_id_ubuntu_22" {
  description = "Ubuntu 22.04 LTS AMI ID (us-east-2). 비워두면 data.aws_ami 동적 조회 (ec2:DescribeImages 필요)"
  type        = string
  default     = ""
}

# ─── EC2 Nginx reverse proxy ──────────────────────────────────────────────────

variable "eks_service_endpoint" {
  description = <<-EOT
    EC2 Nginx가 proxy_pass할 EKS 내부 Service 주소.
    초기 apply 시 "placeholder" 입력 후, EKS 배포 완료 후 실제 ClusterIP 또는 내부 DNS로 업데이트.
    업데이트 후: terraform apply -target=module.ec2_web
  EOT
  type        = string
}

variable "eks_nodeport" {
  description = "Nginx proxy_pass 대상 포트 (EKS NodePort 또는 ClusterIP 포트)"
  type        = number
  default     = 30080
}
