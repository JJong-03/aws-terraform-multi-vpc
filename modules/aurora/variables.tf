variable "subnet_db_a_id" {
  description = "MAIN VPC DB-Azone 서브넷 ID (Writer 배치)"
  type        = string
}

variable "subnet_db_c_id" {
  description = "MAIN VPC DB-Czone 서브넷 ID (Reader 배치)"
  type        = string
}

variable "sg_db_id" {
  description = "Aurora Security Group ID"
  type        = string
}

variable "db_name" {
  description = "초기 데이터베이스 이름"
  type        = string
  default     = "kjwdb"
}

variable "db_username" {
  description = "Aurora master 사용자 이름"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Aurora master 패스워드"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
