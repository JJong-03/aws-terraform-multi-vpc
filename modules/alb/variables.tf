variable "subnet_public_a_id" {
  description = "MAIN VPC PUBLIC-Azone 서브넷 ID"
  type        = string
}

variable "subnet_public_c_id" {
  description = "MAIN VPC PUBLIC-Czone 서브넷 ID"
  type        = string
}

variable "sg_alb_id" {
  description = "ALB Security Group ID"
  type        = string
}

variable "acm_arn_alb" {
  description = "ALB HTTPS Listener에 연결할 ACM 인증서 ARN (us-east-2)"
  type        = string
}

variable "waf_arn" {
  description = "연결할 WAF ACL ARN"
  type        = string
}

variable "vpc_id" {
  description = "Target Group이 속할 VPC ID (MAIN VPC)"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
