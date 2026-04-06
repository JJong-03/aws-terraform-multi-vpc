variable "subnet_mgmt_public_id" {
  description = "MGMT VPC MGMT-PUBLIC 서브넷 ID"
  type        = string
}

variable "sg_openvpn_id" {
  description = "OpenVPN Security Group ID"
  type        = string
}

variable "key_name" {
  description = "EC2 Key Pair 이름"
  type        = string
}

variable "ami_id" {
  description = "EC2 AMI ID (Ubuntu 22.04 LTS). 비워두면 data.aws_ami로 동적 조회 (ec2:DescribeImages 권한 필요)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
