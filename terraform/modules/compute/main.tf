# Ubuntu 22.04 LTS AMI 조회
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 현재 AWS 계정 및 리전 정보
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# EC2 메타데이터 조회용 IAM Role (MySQL, Redis용)
resource "aws_iam_role" "ec2_describe_role" {
  name = "${var.project_name}-${var.environment}-ec2-describe-role"

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
    Name        = "${var.project_name}-${var.environment}-ec2-describe-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# EC2 메타데이터 및 Security Group 조회 권한
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
  role   = aws_iam_role.ec2_describe_role.id
  policy = data.aws_iam_policy_document.ec2_describe_policy.json
}

resource "aws_iam_instance_profile" "ec2_describe_profile" {
  name = "${var.project_name}-${var.environment}-ec2-describe-profile"
  role = aws_iam_role.ec2_describe_role.name
}

# 메인 서비스용 ENI (사설 IP 고정)
resource "aws_network_interface" "main_service_eni" {
  subnet_id       = var.public_subnet_id
  private_ips     = ["10.0.1.76"]  # 현재 IP 고정
  security_groups = [var.main_service_sg_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-main-service-eni"
  }
}

# 메인 서비스용 EC2 인스턴스 (Docker)
resource "aws_instance" "main_service" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.main_service_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.ses_instance_profile_name  # SES 권한 필요

  network_interface {
    network_interface_id = aws_network_interface.main_service_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-main-service"
    Type = "main-service"
  }
}

# AI 서비스용 ENI (사설 IP 고정)
resource "aws_network_interface" "ai_service_eni" {
  subnet_id       = var.public_subnet_id
  private_ips     = ["10.0.1.184"]  # 현재 IP 고정
  security_groups = [var.ai_service_sg_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-service-eni"
  }
}

# AI 서비스용 Elastic IP (퍼블릭 액세스용)
resource "aws_eip" "ai_service" {
  network_interface = aws_network_interface.ai_service_eni.id
  domain            = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-service-eip"
  }

  depends_on = [aws_instance.ai_service]
}

# AI 추천 서비스용 EC2 인스턴스 (Docker)
resource "aws_instance" "ai_service" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.ai_service_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.bedrock_instance_profile_name  # Bedrock 권한 필요

  network_interface {
    network_interface_id = aws_network_interface.ai_service_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-service"
    Type = "ai-service"
  }
}

# MySQL 서비스용 ENI (사설 IP 고정)
resource "aws_network_interface" "mysql_eni" {
  subnet_id       = var.public_subnet_id
  private_ips     = ["10.0.1.214"]  # 현재 IP 고정
  security_groups = [var.mysql_sg_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql-eni"
  }
}

# MySQL용 Elastic IP (퍼블릭 액세스용)
resource "aws_eip" "mysql" {
  network_interface = aws_network_interface.mysql_eni.id
  domain            = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql-eip"
  }

  depends_on = [aws_instance.mysql]
}

# MySQL 데이터베이스용 EC2 인스턴스 (네이티브)
resource "aws_instance" "mysql" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.mysql_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = aws_iam_instance_profile.ec2_describe_profile.name

  network_interface {
    network_interface_id = aws_network_interface.mysql_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.mysql_volume_size
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
    Type = "mysql"
  }
}

# Redis 서비스용 ENI (사설 IP 고정)
resource "aws_network_interface" "redis_eni" {
  subnet_id       = var.public_subnet_id
  private_ips     = ["10.0.1.185"]  # 현재 IP 고정
  security_groups = [var.redis_sg_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-eni"
  }
}

# Redis용 Elastic IP (퍼블릭 액세스용)
resource "aws_eip" "redis" {
  network_interface = aws_network_interface.redis_eni.id
  domain            = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-eip"
  }

  depends_on = [aws_instance.redis]
}

# Redis 캐시 서버용 EC2 인스턴스 (네이티브)
resource "aws_instance" "redis" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.redis_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = aws_iam_instance_profile.ec2_describe_profile.name

  network_interface {
    network_interface_id = aws_network_interface.redis_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
    Type = "redis"
  }
}

# 메인 서비스용 Elastic IP (ENI에 연결)
resource "aws_eip" "main_service" {
  network_interface = aws_network_interface.main_service_eni.id
  domain            = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-main-service-eip"
  }

  depends_on = [aws_instance.main_service]
}

