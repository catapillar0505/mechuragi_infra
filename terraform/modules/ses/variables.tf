variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Domain name for SES (optional)"
  type        = string
  default     = ""
}

variable "from_email" {
  description = "Email address to send from"
  type        = string
}