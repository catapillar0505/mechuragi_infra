variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "main_service_instance_type" {
  description = "EC2 instance type for main service"
  type        = string
  default     = "t3.micro"
}

variable "ai_service_instance_type" {
  description = "EC2 instance type for AI service"
  type        = string
  default     = "t3.small"
}

variable "mysql_instance_type" {
  description = "EC2 instance type for MySQL"
  type        = string
  default     = "t3.micro"
}

variable "redis_instance_type" {
  description = "EC2 instance type for Redis"
  type        = string
  default     = "t3.micro"
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

variable "bedrock_instance_profile_name" {
  description = "Name of the Bedrock IAM instance profile for AI service"
  type        = string
}

variable "ses_instance_profile_name" {
  description = "Name of the SES IAM instance profile for main service"
  type        = string
}

variable "mysql_volume_size" {
  description = "Size of the MySQL EBS volume in GB"
  type        = number
  default     = 30
}
