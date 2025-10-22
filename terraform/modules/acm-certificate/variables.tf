variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for ACM certificate (e.g., mechuragi.kro.kr)"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names for the certificate (e.g., www.mechuragi.kro.kr)"
  type        = list(string)
  default     = []
}

variable "wait_for_validation" {
  description = "Wait for ACM certificate validation (only after DNS CNAME records are added to kro.kr)"
  type        = bool
  default     = false
}
