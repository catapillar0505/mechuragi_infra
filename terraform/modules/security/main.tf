# 통합 메인 서비스 보안 그룹 (Private Subnet, Nginx를 통해서만 접근)
# MySQL, Redis, API 서버를 모두 포함하는 통합 서버
# Private Subnet에 위치하므로 Nginx 게이트웨이를 통해서만 접근 가능
resource "aws_security_group" "main_service" {
  name_prefix = "${var.project_name}-${var.environment}-main-service-"
  vpc_id      = var.vpc_id
  description = "Integrated main service security group (API + MySQL + Redis in private subnet)"

  # HTTP 포트 - Nginx 게이트웨이에서만 허용
  ingress {
    description     = "HTTP from Nginx gateway"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # HTTPS 포트 - Nginx 게이트웨이에서만 허용
  ingress {
    description     = "HTTPS from Nginx gateway"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # SSH 포트 - Bastion(Nginx)을 통해서만 접근
  ingress {
    description     = "SSH from Nginx bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # Spring Boot 메인 애플리케이션 포트 - Nginx에서만 허용
  ingress {
    description     = "Spring Boot Main App from Nginx"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # MySQL 포트 - AI 서버에서 직접 접근 허용
  ingress {
    description     = "MySQL from AI service"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ai_service.id]
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (Nginx NAT를 통해 인터넷 접근)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-main-service-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# AI 추천 서비스 보안 그룹 (Private Subnet, Nginx를 통해서만 접근)
# Private Subnet에 위치하며 Nginx 게이트웨이를 통해 프론트엔드 요청 수신
# 메인 서버 MySQL에 직접 접근하여 사용자 정보 조회
resource "aws_security_group" "ai_service" {
  name_prefix = "${var.project_name}-${var.environment}-ai-service-"
  vpc_id      = var.vpc_id
  description = "AI service security group in private subnet (Nginx gateway access only)"

  # SSH 포트 - Bastion(Nginx)을 통해서만 접근
  ingress {
    description     = "SSH from Nginx bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # Spring Boot AI 애플리케이션 포트 - Nginx에서만 허용
  ingress {
    description     = "Spring Boot AI App from Nginx"
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (Nginx NAT를 통한 Bedrock API 호출, MySQL 접근)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-service-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Nginx 게이트웨이 보안 그룹 (Public 접근 허용)
# 리버스 프록시, Bastion Host, NAT 인스턴스 역할
resource "aws_security_group" "nginx_gateway" {
  name_prefix = "${var.project_name}-${var.environment}-nginx-gateway-"
  vpc_id      = var.vpc_id
  description = "Nginx gateway security group (public-facing reverse proxy, bastion, and NAT)"

  # HTTP 포트 - CloudFront에서 API 요청
  ingress {
    description = "HTTP from internet (CloudFront)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS 포트 - CloudFront에서 보안 API 요청
  ingress {
    description = "HTTPS from internet (CloudFront)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH 포트 - 관리자만 접근 (Bastion Host)
  ingress {
    description = "SSH from admin IPs only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ssh_cidrs
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (NAT 기능, 프록시)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-gateway-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
