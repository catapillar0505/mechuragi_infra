variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "admin_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into Nginx bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # 프로덕션에서는 관리자 IP만 허용
}
