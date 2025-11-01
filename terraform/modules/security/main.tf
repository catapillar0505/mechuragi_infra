# 메인 서비스 보안 그룹 (Public 접근 허용)
# 웹 서비스이므로 인터넷에서 직접 접근 가능
# 보안 설계 - Level 1: Main Service - 완전 공개 (웹 서비스) - Level 2: AI/MySQL/Redis - VPC 내부만 (10.0.0.0/16)

resource "aws_security_group" "main_service" {
  name_prefix = "${var.project_name}-${var.environment}-main-service-"
  vpc_id      = var.vpc_id
  description = "Public-facing main service security group (HTTP/HTTPS/SSH access from internet)"

  # HTTP 포트 - 웹 트래픽 (전체 인터넷 허용)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS 포트 - 보안 웹 트래픽 (전체 인터넷 허용)
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH 포트 - 서버 관리용 (전체 인터넷 허용)
  ingress {
    description = "SSH for server management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Spring Boot 메인 애플리케이션 포트 (전체 인터넷 허용)
  ingress {
    description = "Spring Boot Main App from internet"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (인터넷 접근, API 호출 등)
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

# AI 추천 서비스 보안 그룹 (VPC 내부 접근만 허용)
# 보안상 인터넷에서 직접 접근 차단, 메인 서비스를 통해서만 접근
resource "aws_security_group" "ai_service" {
  name_prefix = "${var.project_name}-${var.environment}-ai-service-"
  vpc_id      = var.vpc_id
  description = "VPC-internal AI service security group (access restricted to VPC only)"

  # SSH 포트 - 서버 관리용 (Public subnet 구조로 인터넷 접근 허용)
  ingress {
    description = "SSH for server management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public subnet이므로 인터넷 접근 허용
  }

  # Spring Boot AI 애플리케이션 포트 (VPC 내부에서만 접근)
  ingress {
    description = "Spring Boot AI App from VPC only"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # 메인 서비스에서만 호출 가능
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (Bedrock API 호출, 패키지 설치 등)
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

# MySQL 데이터베이스 보안 그룹 (VPC 내부 접근만 허용)
# 데이터베이스 보안을 위해 인터넷에서 직접 접근 완전 차단
resource "aws_security_group" "mysql" {
  name_prefix = "${var.project_name}-${var.environment}-mysql-"
  vpc_id      = var.vpc_id
  description = "VPC-internal MySQL database security group (port 3306 restricted to VPC only)"

  # SSH 포트 - 서버 관리용 (Public subnet 구조로 인터넷 접근 허용)
  ingress {
    description = "SSH for server management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public subnet이므로 인터넷 접근 허용
  }

  # MySQL 데이터베이스 포트 (VPC 내부에서만 접근)
  ingress {
    description = "MySQL from VPC only"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # 메인/AI 서비스에서만 연결 가능
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (패키지 업데이트, 백업 등)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Redis 캐시 서버 보안 그룹 (VPC 내부 접근만 허용)
# 캐시 데이터 보안을 위해 인터넷에서 직접 접근 완전 차단
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  vpc_id      = var.vpc_id
  description = "VPC-internal Redis cache security group (port 6379 restricted to VPC only)"

  # SSH 포트 - 서버 관리용 (Public subnet 구조로 인터넷 접근 허용)
  ingress {
    description = "SSH for server management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public subnet이므로 인터넷 접근 허용
  }

  # Redis 캐시 서버 포트 (VPC 내부에서만 접근)
  ingress {
    description = "Redis from VPC only"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # 메인/AI 서비스에서만 연결 가능
  }

  # ICMP (ping) - VPC 내부 통신 확인용
  ingress {
    description = "ICMP from VPC for connectivity testing"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용 (패키지 업데이트, 모니터링 등)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
