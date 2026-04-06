variable "main_vpc_id" {
  description = "MAIN VPC ID (Peering 수락 측)"
  type        = string
}

variable "mgmt_vpc_id" {
  description = "MGMT VPC ID (Peering 요청 측)"
  type        = string
}

variable "main_vpc_cidr" {
  description = "MAIN VPC CIDR (MGMT RT에 추가할 목적지)"
  type        = string
}

variable "mgmt_vpc_cidr" {
  description = "MGMT VPC CIDR (MAIN RT에 추가할 목적지)"
  type        = string
}

# ─── MAIN VPC RT ID (경로 추가 대상) ─────────────────────────────────────────

variable "main_rt_app_a_id" {
  description = "MAIN RT-APP-Azone ID"
  type        = string
}

variable "main_rt_app_c_id" {
  description = "MAIN RT-APP-Czone ID"
  type        = string
}

variable "main_rt_db_id" {
  description = "MAIN RT-DB ID (MGMT → Aurora 직접 접속 경로)"
  type        = string
}

# ─── MGMT VPC RT ID (경로 추가 대상) ─────────────────────────────────────────

variable "mgmt_rt_id" {
  description = "MGMT RT-MGMT ID"
  type        = string
}
