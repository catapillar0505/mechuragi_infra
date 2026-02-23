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
  iam_instance_profile = var.main_instance_profile_name

  network_interface {
    network_interface_id = aws_network_interface.main_service_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30  # MySQL 데이터 포함하므로 용량 증가
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami, network_interface]
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
  iam_instance_profile = var.ai_instance_profile_name

  network_interface {
    network_interface_id = aws_network_interface.ai_service_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami, network_interface]
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
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.nginx_gateway_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.nginx_instance_profile_name

  network_interface {
    network_interface_id = aws_network_interface.nginx_gateway_eni.id
    device_index         = 0
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami, network_interface]
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


