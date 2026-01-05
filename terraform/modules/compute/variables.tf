variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "main_service_instance_type" {
  description = "EC2 instance type for integrated main service"
  type        = string
  default     = "t3.medium"
}

variable "ai_service_instance_type" {
  description = "EC2 instance type for AI service"
  type        = string
  default     = "t3.small"
}

variable "nginx_gateway_instance_type" {
  description = "EC2 instance type for Nginx gateway"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "main_service_sg_id" {
  description = "ID of the integrated main service security group"
  type        = string
}

variable "ai_service_sg_id" {
  description = "ID of the AI service security group"
  type        = string
}

variable "nginx_gateway_sg_id" {
  description = "ID of the Nginx gateway security group"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet"
  type        = string
}

variable "private_subnet_id" {
  description = "ID of the private subnet"
  type        = string
}

variable "private_route_table_id" {
  description = "ID of the private route table"
  type        = string
}

variable "main_instance_profile_name" {
  description = "Name of the main service IAM instance profile"
  type        = string
}

variable "ai_instance_profile_name" {
  description = "Name of the AI service IAM instance profile"
  type        = string
}

variable "nginx_instance_profile_name" {
  description = "Name of the nginx gateway IAM instance profile"
  type        = string
}
