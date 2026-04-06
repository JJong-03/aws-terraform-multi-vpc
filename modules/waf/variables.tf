variable "name" {
  description = "WAF ACL 이름"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
