variable "subnet_service_private_id" {
  description = "SERVICE VPC PRIVATE 서브넷 ID (ECS Task 배치)"
  type        = string
}

variable "sg_ecs_id" {
  description = "ECS Task Security Group ID"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR 리포지토리 URL (Task Definition image 주소)"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
