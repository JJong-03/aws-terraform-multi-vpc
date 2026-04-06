variable "repository_name" {
  description = "ECR 리포지토리 이름 (소문자만 허용, 대문자 금지)"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
