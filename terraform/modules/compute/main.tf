# Amazon Linux AMI 조회 (더 안정적)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
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

# EC2 인스턴스 생성
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [var.security_group_id]
  subnet_id              = var.public_subnet_id

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-server"
  }
} 

# Elastic IP 할당
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}

