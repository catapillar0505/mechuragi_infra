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

# 메인 서비스용 EC2 인스턴스 (Docker)
resource "aws_instance" "main_service" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.main_service_instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [var.main_service_sg_id]
  subnet_id              = var.public_subnet_id

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

# AI 추천 서비스용 EC2 인스턴스 (Docker)
resource "aws_instance" "ai_service" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ai_service_instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [var.ai_service_sg_id]
  subnet_id              = var.public_subnet_id
  iam_instance_profile   = var.bedrock_instance_profile_name  # Bedrock 권한 필요

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

# MySQL 데이터베이스용 EC2 인스턴스 (네이티브)
resource "aws_instance" "mysql" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.mysql_instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [var.mysql_sg_id]
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true

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

# Redis 캐시 서버용 EC2 인스턴스 (네이티브)
resource "aws_instance" "redis" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.redis_instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [var.redis_sg_id]
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true

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

# 메인 서비스용 Elastic IP
resource "aws_eip" "main_service" {
  instance = aws_instance.main_service.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-main-service-eip"
  }
}

