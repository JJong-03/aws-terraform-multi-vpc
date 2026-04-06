variable "main_vpc_id" {
  description = "MAIN VPC ID (ALB, WEB, EKS-NODE, DB SG 생성 위치)"
  type        = string
}

variable "mgmt_vpc_id" {
  description = "MGMT VPC ID (OPENVPN SG 생성 위치)"
  type        = string
}

variable "service_vpc_id" {
  description = "SERVICE VPC ID (ECS SG 생성 위치)"
  type        = string
}

variable "openvpn_client_cidr" {
  description = "EC2 Web SSH 허용 소스. OpenVPN NAT 방식에 따라 MGMT VPC CIDR 또는 OpenVPN EC2 IP로 조정"
  type        = string
}

variable "mgmt_vpc_cidr" {
  description = "MGMT VPC CIDR. SG-DB에서 Aurora 직접 접속 허용 소스로 사용"
  type        = string
}

variable "nginx_to_eks_port" {
  description = "EC2 Nginx → EKS NodePort 허용 포트 (최소 권한 원칙)"
  type        = number
  default     = 30080
}

variable "openvpn_admin_cidr" {
  description = "OpenVPN Admin Web UI(TCP 943) 허용 소스 CIDR. 운영 환경에서는 관리자 IP로 제한 권장"
  type        = string
  default     = "0.0.0.0/0"
}
