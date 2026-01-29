# SES Domain Identity
resource "aws_ses_domain_identity" "domain" {
  count  = var.domain_name != "" ? 1 : 0
  domain = var.domain_name
}

# SES Email Identity
resource "aws_ses_email_identity" "email" {
  email = var.from_email
}

# SES Domain DKIM
resource "aws_ses_domain_dkim" "domain_dkim" {
  count  = var.domain_name != "" ? 1 : 0
  domain = aws_ses_domain_identity.domain[0].domain
}

# SES Configuration Set
resource "aws_ses_configuration_set" "main" {
  name = "${var.project_name}-${var.environment}"

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
}

# SES Event Destination for bounces and complaints
resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "${var.project_name}-${var.environment}-cloudwatch"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["bounce", "complaint", "delivery", "send", "reject"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "MessageTag"
    value_source   = "messageTag"
  }
}

data "aws_caller_identity" "current" {}