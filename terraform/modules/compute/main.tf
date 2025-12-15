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

# 통합 메인 서비스용 ENI (Private Subnet, 사설 IP만)
resource "aws_network_interface" "main_service_eni" {
  subnet_id       = var.private_subnet_id
  private_ips     = ["10.0.2.10"]  # Private Subnet CIDR 사용
  security_groups = [var.main_service_sg_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-main-integrated-eni"
  }
}

# 통합 메인 서비스용 EC2 인스턴스 (MySQL + Redis + API)
resource "aws_instance" "main_service" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.main_service_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.ses_instance_profile_name  # SES 권한 유지

  network_interface {
    network_interface_id = aws_network_interface.main_service_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30  # MySQL 데이터 포함하므로 용량 증가
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-main-integrated"
    Type = "main-integrated"
  }
}

# AI 서비스용 ENI (Private Subnet, 사설 IP만)
resource "aws_network_interface" "ai_service_eni" {
  subnet_id       = var.private_subnet_id
  private_ips     = ["10.0.2.20"]  # Private Subnet CIDR 사용
  security_groups = [var.ai_service_sg_id]

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-service-eni"
  }
}

# AI 추천 서비스용 EC2 인스턴스 (Docker)
resource "aws_instance" "ai_service" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.ai_service_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.bedrock_instance_profile_name  # Bedrock 권한 유지

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

# Nginx 게이트웨이용 ENI (Public Subnet)
resource "aws_network_interface" "nginx_gateway_eni" {
  subnet_id       = var.public_subnet_id
  private_ips     = ["10.0.1.100"]  # Public Subnet CIDR 사용
  security_groups = [var.nginx_gateway_sg_id]
  source_dest_check = false  # NAT 동작을 위해 비활성화

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-gateway-eni"
  }
}

# Nginx 게이트웨이용 Elastic IP
resource "aws_eip" "nginx_gateway" {
  network_interface = aws_network_interface.nginx_gateway_eni.id
  domain            = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-gateway-eip"
  }

  depends_on = [aws_instance.nginx_gateway]
}

# Nginx 게이트웨이 EC2 인스턴스 (리버스 프록시, Bastion, NAT)
resource "aws_instance" "nginx_gateway" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.nginx_gateway_instance_type
  key_name      = var.key_pair_name

  network_interface {
    network_interface_id = aws_network_interface.nginx_gateway_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # IP forwarding 활성화 (NAT 기능)
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p

              # iptables MASQUERADE 규칙 (NAT)
              iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

              # 재부팅 후에도 유지
              apt-get update
              apt-get install -y iptables-persistent
              netfilter-persistent save
              EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-gateway"
    Type = "nginx-gateway"
  }
}

# Private Subnet의 NAT 라우트 추가
resource "aws_route" "private_nat" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.nginx_gateway_eni.id

  depends_on = [aws_instance.nginx_gateway]
}


