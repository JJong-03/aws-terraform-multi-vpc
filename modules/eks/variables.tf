variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "subnet_app_a_id" {
  description = "MAIN VPC APP-Azone 서브넷 ID"
  type        = string
}

variable "subnet_app_c_id" {
  description = "MAIN VPC APP-Czone 서브넷 ID"
  type        = string
}

variable "sg_eks_node_id" {
  description = "EKS Node Security Group ID"
  type        = string
}

variable "eks_public_access_cidrs" {
  description = "EKS API 퍼블릭 엔드포인트 허용 CIDR 목록. 운영 환경에서는 관리자 IP/32로 제한 권장"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
