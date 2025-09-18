variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet"
  type        = string
}
