variable "vpc_cidr" {
  description = "SERVICE VPC CIDR"
  type        = string
}

variable "az_a" {
  description = "가용 영역 A (us-east-2a)"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
