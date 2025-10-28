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

# SES Email Template - Welcome Email
resource "aws_ses_template" "welcome_email" {
  name    = "${var.project_name}-welcome-email"
  subject = "{{project_name}}에 오신 것을 환영합니다! 🎉"
  
  html = templatefile("${path.module}/templates/welcome_email.html", {
    project_name = var.project_name
  })
  
  text = templatefile("${path.module}/templates/welcome_email.txt", {
    project_name = var.project_name
  })
}

# SES Email Template - Password Reset
resource "aws_ses_template" "password_reset" {
  name    = "${var.project_name}-password-reset"
  subject = "{{project_name}} 비밀번호 재설정 요청"
  
  html = templatefile("${path.module}/templates/password_reset.html", {
    project_name = var.project_name
  })
  
  text = templatefile("${path.module}/templates/password_reset.txt", {
    project_name = var.project_name
  })
}

# IAM policy for SES sending
data "aws_iam_policy_document" "ses_sending_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
      "ses:SendTemplatedEmail"
    ]
    resources = [
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/${var.from_email}",
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:template/*",
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:configuration-set/${aws_ses_configuration_set.main.name}"
    ]
  }
}

data "aws_caller_identity" "current" {}

# IAM role for EC2 to send emails
resource "aws_iam_role" "ses_sending_role" {
  name = "${var.project_name}-${var.environment}-ses-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ses-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "ses_sending_policy" {
  name   = "${var.project_name}-${var.environment}-ses-policy"
  role   = aws_iam_role.ses_sending_role.id
  policy = data.aws_iam_policy_document.ses_sending_policy.json
}

resource "aws_iam_instance_profile" "ses_profile" {
  name = "${var.project_name}-${var.environment}-ses-profile"
  role = aws_iam_role.ses_sending_role.name
}

# EC2 메타데이터 및 Security Group 조회 권한 (Ansible 테스트용)
data "aws_iam_policy_document" "ec2_describe_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_describe_policy" {
  name   = "${var.project_name}-${var.environment}-ec2-describe-policy"
  role   = aws_iam_role.ses_sending_role.id
  policy = data.aws_iam_policy_document.ec2_describe_policy.json
}