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

variable "main_service_sg_id" {
  description = "ID of the main service security group"
  type        = string
}

variable "ai_service_sg_id" {
  description = "ID of the AI service security group"
  type        = string
}

variable "mysql_sg_id" {
  description = "ID of the MySQL security group"
  type        = string
}

variable "redis_sg_id" {
  description = "ID of the Redis security group"
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
