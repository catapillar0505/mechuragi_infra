# Terraform 리팩토링 실행 계획

> **목표**: 4개 EC2 인스턴스 구조를 3개 통합 인스턴스 구조로 변경
> **기준 문서**: [refactoring.md](./refactoring.md)

## Phase 1: VPC 및 네트워크 설정

### 2.1 라우트 테이블 수정 (NAT 설정)

**파일**: `terraform/modules/vpc/main.tf`

**변경 사항**:

1. **Private 서브넷 생성 및 public 서브넷(기존 서브넷)과 분리**
   - 현재 모든 인스턴스가 Public Subnet (10.0.1.0/24)에 위치
   - 새로운 Private Subnet 생성하고(메인 서버, 추천 서버용), Nginx NAT 인스턴스는 Public Subnet에 있도록 하기!

2. **Private 라우트 테이블 추가**
   ```hcl
   # terraform/modules/vpc/main.tf에 추가

   # Private Subnet 생성 (메인/AI 서버용)
   resource "aws_subnet" "private" {
     vpc_id            = aws_vpc.main.id
     cidr_block        = "10.0.2.0/24"  # Private Subnet CIDR
     availability_zone = var.availability_zone

     map_public_ip_on_launch = false  # Public IP 자동 할당 비활성화

     tags = {
       Name = "${var.project_name}-${var.environment}-private-subnet"
       Type = "private"
     }
   }

   # Private 라우트 테이블 생성 (NAT 라우트는 나중에 추가)
   resource "aws_route_table" "private" {
     vpc_id = aws_vpc.main.id

     tags = {
       Name = "${var.project_name}-${var.environment}-private-rt"
     }
   }

   # Private Subnet에 Private 라우트 테이블 연결
   resource "aws_route_table_association" "private" {
     subnet_id      = aws_subnet.private.id
     route_table_id = aws_route_table.private.id
   }

   # VPC 모듈 출력에 추가
   output "private_subnet_id" {
     value = aws_subnet.private.id
   }

   output "private_route_table_id" {
     value = aws_route_table.private.id
   }
   ```

   **중요**: NAT 라우트는 Compute 모듈에서 Nginx 인스턴스 생성 후 추가합니다 (순환 참조 방지)

3. **Compute 모듈에서 NAT 라우트 추가**
   ```hcl
   # terraform/modules/compute/main.tf에 추가

   # Nginx 게이트웨이 인스턴스 생성
   resource "aws_instance" "nginx_gateway" {
     # ... Nginx 인스턴스 설정 ...

     subnet_id              = var.public_subnet_id  # Public Subnet에 배치
     associate_public_ip_address = true

     # NAT 동작을 위해 Source/Destination Check 비활성화
     source_dest_check = false

     tags = {
       Name = "${var.project_name}-${var.environment}-nginx-gateway"
     }
   }

   # Elastic IP를 Nginx에 할당
   resource "aws_eip" "nginx" {
     instance = aws_instance.nginx_gateway.id
     domain   = "vpc"
   }

   # Private Subnet의 라우트 테이블에 NAT 라우트 추가
   resource "aws_route" "private_nat" {
     route_table_id         = var.private_route_table_id  # VPC 모듈에서 출력받음
     destination_cidr_block = "0.0.0.0/0"
     network_interface_id   = aws_instance.nginx_gateway.primary_network_interface_id

     # Nginx 인스턴스가 먼저 생성되어야 함
     depends_on = [aws_instance.nginx_gateway]
   }
   ```

   **핵심**:
   - VPC 모듈은 Private 라우트 테이블만 생성 (NAT 라우트 없이)
   - Compute 모듈에서 Nginx 인스턴스 생성 후 `aws_route` 리소스로 NAT 라우트 추가
   - 이렇게 하면 순환 참조 문제 해결

**참고**: 현재는 모든 인스턴스가 Public Subnet에 있으므로, 메인/AI 서버를 Private Subnet으로 이동하는 것이 명확한 분리를 제공합니다.

---

## 3. Phase 2: Security 모듈 재설계

### 3.1 보안 그룹 제거 및 추가

**파일**: `terraform/modules/security/main.tf`

**제거할 보안 그룹**:
1. `mysql_sg` - MySQL 인스턴스 제거로 불필요
2. `redis_sg` - Redis 인스턴스 제거로 불필요

**수정할 보안 그룹**:

#### 3.1.1 통합 메인 서버 보안 그룹 (기존 `main_service_sg` 수정)

```hcl
# terraform/modules/security/main.tf 수정

resource "aws_security_group" "main_service" {
  name        = "${var.project_name}-${var.environment}-main-service-sg"
  description = "Security group for integrated main server (API + MySQL + Redis)"
  vpc_id      = var.vpc_id

  # HTTP - Nginx에서만 허용
  ingress {
    description     = "HTTP from Nginx Gateway"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # HTTPS - Nginx에서만 허용
  ingress {
    description     = "HTTPS from Nginx Gateway"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # Spring Boot API - Nginx에서만 허용
  ingress {
    description     = "Spring Boot from Nginx Gateway"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # MySQL - AI 서버에서 직접 접근
  ingress {
    description     = "MySQL from AI Server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ai_service.id]
  }

  # SSH - Nginx Bastion에서만 허용
  ingress {
    description     = "SSH from Nginx Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # ICMP - VPC 내부 ping
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound - 모두 허용 (Docker Hub, AWS APIs 등)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-main-service-sg"
  }
}
```

**주요 변경점**:
- HTTP/HTTPS: `0.0.0.0/0` → Nginx 보안 그룹만
- SSH: `0.0.0.0/0` → Nginx 보안 그룹만 (Bastion 역할)
- MySQL 포트(3306) 추가: AI 서버에서만 접근

#### 3.1.2 AI 서비스 보안 그룹 수정

```hcl
# terraform/modules/security/main.tf 수정

resource "aws_security_group" "ai_service" {
  name        = "${var.project_name}-${var.environment}-ai-service-sg"
  description = "Security group for AI recommendation server"
  vpc_id      = var.vpc_id

  # Spring Boot AI - Nginx에서만 허용
  ingress {
    description     = "Spring Boot AI from Nginx Gateway"
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # SSH - Nginx Bastion에서만 허용
  ingress {
    description     = "SSH from Nginx Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_gateway.id]
  }

  # ICMP - VPC 내부 ping
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound - Bedrock API, MySQL, Docker Hub 등
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ai-service-sg"
  }
}
```

**주요 변경점**:
- SSH: `0.0.0.0/0` → Nginx 보안 그룹만
- 8082 포트: VPC CIDR → Nginx 보안 그룹만

#### 3.1.3 Nginx 게이트웨이 보안 그룹 (신규 추가)

```hcl
# terraform/modules/security/main.tf에 추가

resource "aws_security_group" "nginx_gateway" {
  name        = "${var.project_name}-${var.environment}-nginx-gateway-sg"
  description = "Security group for Nginx reverse proxy, NAT, and Bastion host"
  vpc_id      = var.vpc_id

  # HTTP - CloudFront 및 인터넷에서 허용
  ingress {
    description = "HTTP from Internet (CloudFront)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS - CloudFront 및 인터넷에서 허용
  ingress {
    description = "HTTPS from Internet (CloudFront)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - 관리자 IP만 허용 (변수로 받기)
  ingress {
    description = "SSH from Admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ssh_cidrs  # ["YOUR_IP/32"] 형태로 제공
  }

  # ICMP - VPC 내부 ping
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound - VPC 내부 프록시 + 인터넷 NAT
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-gateway-sg"
  }
}
```

**주요 특징**:
- HTTP/HTTPS: 인터넷 전체 허용 (CloudFront Origin으로 사용)
- SSH: 관리자 IP만 화이트리스트 (보안 강화)
- Outbound: VPC 내부 프록시 및 NAT 역할

### 3.2 Security 모듈 변수 추가

**파일**: `terraform/modules/security/variables.tf`

```hcl
# terraform/modules/security/variables.tf에 추가

variable "admin_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into Nginx Bastion"
  type        = list(string)
  default     = []  # 빈 리스트면 SSH 완전 차단 (안전)
}
```

### 3.3 Security 모듈 출력 업데이트

**파일**: `terraform/modules/security/outputs.tf`

```hcl
# terraform/modules/security/outputs.tf 수정

# 제거할 출력
# output "mysql_sg_id" { ... }  # 삭제
# output "redis_sg_id" { ... }  # 삭제

# 추가할 출력
output "nginx_gateway_sg_id" {
  description = "ID of the Nginx Gateway security group"
  value       = aws_security_group.nginx_gateway.id
}
```

---

## 4. Phase 3: Compute 모듈 재구성

### 4.1 제거할 리소스

**파일**: `terraform/modules/compute/main.tf`

**제거 대상** (라인 155-247):
1. MySQL 인스턴스 관련 리소스:
   - `aws_network_interface.mysql_eni`
   - `aws_eip.mysql_eip`
   - `aws_instance.mysql`
   - `aws_eip_association.mysql_eip_assoc`

2. Redis 인스턴스 관련 리소스:
   - `aws_network_interface.redis_eni`
   - `aws_eip.redis_eip`
   - `aws_instance.redis`
   - `aws_eip_association.redis_eip_assoc`

**작업**:
```bash
# 해당 라인 범위 삭제:
# - Lines 155-200 (MySQL)
# - Lines 202-247 (Redis)
```

### 4.2 수정할 리소스: 통합 메인 서버

**파일**: `terraform/modules/compute/main.tf` (라인 74-106)

**변경 사항**:

1. **인스턴스 타입 상향**
   ```hcl
   # Before
   instance_type = "t3.small"

   # After
   instance_type = var.main_server_instance_type  # t3.medium으로 상향
   ```

2. **Elastic IP 제거 (Private IP만 사용)**
   ```hcl
   # 제거: aws_eip.main_eip 리소스
   # 제거: aws_eip_association.main_eip_assoc 리소스

   # ENI 설정 유지 (Private IP 고정)
   resource "aws_network_interface" "main_eni" {
     subnet_id       = var.subnet_id
     private_ips     = ["10.0.1.76"]  # 유지
     security_groups = [var.main_service_sg_id]

     tags = {
       Name = "${var.project_name}-${var.environment}-main-eni"
     }
   }
   ```

3. **User Data 스크립트 업데이트** (docker-compose 준비)
   ```hcl
   user_data = <<-EOF
               #!/bin/bash
               # Docker 설치
               yum update -y
               yum install -y docker
               systemctl start docker
               systemctl enable docker

               # Docker Compose 설치
               curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
               chmod +x /usr/local/bin/docker-compose

               # 애플리케이션 디렉토리 준비
               mkdir -p /app/mysql-data
               mkdir -p /app/redis-data

               # docker-compose.yml은 애플리케이션 레포지토리에서 관리
               EOF
   ```

### 4.3 수정할 리소스: AI 서비스 서버

**파일**: `terraform/modules/compute/main.tf` (라인 109-153)

**변경 사항**:

1. **Elastic IP 제거**
   ```hcl
   # 제거: aws_eip.ai_eip 리소스
   # 제거: aws_eip_association.ai_eip_assoc 리소스
   ```

2. **ENI 설정 유지** (Private IP 고정)
   ```hcl
   resource "aws_network_interface" "ai_eni" {
     subnet_id       = var.subnet_id
     private_ips     = ["10.0.1.184"]  # 유지
     security_groups = [var.ai_service_sg_id]

     tags = {
       Name = "${var.project_name}-${var.environment}-ai-eni"
     }
   }
   ```

3. **User Data 업데이트** (MySQL 클라이언트 설치)
   ```hcl
   user_data = <<-EOF
               #!/bin/bash
               yum update -y
               yum install -y docker mysql  # MySQL 클라이언트 추가
               systemctl start docker
               systemctl enable docker

               # MySQL 연결 테스트 스크립트
               cat > /home/ec2-user/test-mysql.sh <<'SCRIPT'
               #!/bin/bash
               mysql -h 10.0.1.76 -u ai_user -p<password> -e "SELECT 1"
               SCRIPT
               chmod +x /home/ec2-user/test-mysql.sh
               EOF
   ```

### 4.4 신규 리소스: Nginx 게이트웨이 서버

**파일**: `terraform/modules/compute/main.tf` (새로 추가)

**위치**: 파일 끝에 추가 (라인 248 이후)

```hcl
# =====================================
# Nginx Gateway Server (Reverse Proxy, NAT, Bastion)
# =====================================

# Nginx ENI (Public IP 할당용)
resource "aws_network_interface" "nginx_eni" {
  subnet_id       = var.subnet_id  # Public Subnet
  private_ips     = ["10.0.1.50"]  # 새 Private IP
  security_groups = [var.nginx_gateway_sg_id]
  source_dest_check = false  # NAT 기능을 위해 필수!

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-eni"
  }
}

# Nginx Elastic IP (유일한 Public IP)
resource "aws_eip" "nginx_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-eip"
  }

  depends_on = [var.internet_gateway_id]
}

# Nginx 인스턴스
resource "aws_instance" "nginx_gateway" {
  ami           = var.ami_id
  instance_type = var.nginx_instance_type  # t3.micro

  network_interface {
    network_interface_id = aws_network_interface.nginx_eni.id
    device_index         = 0
  }

  key_name = var.key_name

  # NAT 및 Nginx 설정 User Data
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 시스템 업데이트
              yum update -y

              # Nginx 설치
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx

              # Docker 설치 (Nginx 컨테이너 옵션)
              yum install -y docker
              systemctl start docker
              systemctl enable docker

              # ===== NAT 설정 (중요!) =====
              # IP Forwarding 활성화
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
              sysctl -p

              # iptables NAT 규칙 추가
              iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
              iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT

              # iptables 규칙 영구 저장
              yum install -y iptables-services
              systemctl enable iptables
              service iptables save

              # ===== Nginx 기본 설정 =====
              cat > /etc/nginx/conf.d/proxy.conf <<'NGINX'
              # Main API Server Upstream
              upstream main_api {
                  server 10.0.1.76:8080;  # 메인 서버 Private IP
                  keepalive 32;
              }

              # AI Service Upstream
              upstream ai_api {
                  server 10.0.1.184:8082;  # AI 서버 Private IP
                  keepalive 16;
              }

              server {
                  listen 80;
                  server_name _;

                  # Health Check 엔드포인트
                  location /health {
                      access_log off;
                      return 200 "healthy\n";
                      add_header Content-Type text/plain;
                  }

                  # API 요청 → 메인 서버
                  location /api/ {
                      proxy_pass http://main_api;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      # 타임아웃 설정
                      proxy_connect_timeout 60s;
                      proxy_send_timeout 60s;
                      proxy_read_timeout 60s;
                  }

                  # AI 추천 요청 → AI 서버
                  location /recommend/ {
                      proxy_pass http://ai_api;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      # AI 응답은 느릴 수 있으므로 타임아웃 증가
                      proxy_connect_timeout 90s;
                      proxy_send_timeout 90s;
                      proxy_read_timeout 90s;
                  }
              }
              NGINX

              # Nginx 설정 테스트 및 재시작
              nginx -t && systemctl restart nginx

              # 로그 로테이션 설정
              cat > /etc/logrotate.d/nginx <<'LOGROTATE'
              /var/log/nginx/*.log {
                  daily
                  missingok
                  rotate 14
                  compress
                  delaycompress
                  notifempty
                  create 0640 nginx adm
                  sharedscripts
                  postrotate
                      [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
                  endscript
              }
              LOGROTATE

              # 완료 로그
              echo "Nginx Gateway setup completed at $(date)" >> /var/log/user-data.log
              EOF

  iam_instance_profile = aws_iam_instance_profile.nginx_profile.name

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-gateway"
    Role = "Gateway"
  }
}

# Nginx EIP 연결
resource "aws_eip_association" "nginx_eip_assoc" {
  network_interface_id = aws_network_interface.nginx_eni.id
  allocation_id        = aws_eip.nginx_eip.id
}

# Nginx IAM Role (CloudWatch Logs 등)
resource "aws_iam_role" "nginx_role" {
  name = "${var.project_name}-${var.environment}-nginx-role"

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
    Name = "${var.project_name}-${var.environment}-nginx-role"
  }
}

# CloudWatch Logs 정책 연결
resource "aws_iam_role_policy_attachment" "nginx_cloudwatch" {
  role       = aws_iam_role.nginx_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# EC2 Describe 정책 (자체 메타데이터 조회)
resource "aws_iam_role_policy_attachment" "nginx_ec2_describe" {
  role       = aws_iam_role.nginx_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "nginx_profile" {
  name = "${var.project_name}-${var.environment}-nginx-profile"
  role = aws_iam_role.nginx_role.name
}
```

**주요 특징**:
- **source_dest_check = false**: NAT 동작 필수 설정
- **IP Forwarding**: 커널 레벨에서 패킷 포워딩 활성화
- **iptables MASQUERADE**: 메인/AI 서버의 아웃바운드 트래픽을 Nginx의 Public IP로 위장
- **Nginx 리버스 프록시**: /api/ → 메인 서버, /recommend/ → AI 서버
- **Health Check**: CloudFront Origin Health Check용 엔드포인트

### 4.5 Compute 모듈 변수 업데이트

**파일**: `terraform/modules/compute/variables.tf`

**추가할 변수**:
```hcl
# Nginx 게이트웨이 관련
variable "nginx_instance_type" {
  description = "Instance type for Nginx Gateway server"
  type        = string
  default     = "t3.micro"
}

variable "nginx_gateway_sg_id" {
  description = "Security group ID for Nginx Gateway"
  type        = string
}

# 메인 서버 인스턴스 타입 변경
variable "main_server_instance_type" {
  description = "Instance type for integrated main server"
  type        = string
  default     = "t3.medium"
}
```

**제거할 변수**:
```hcl
# 제거: mysql_sg_id
# 제거: redis_sg_id
```

### 4.6 Compute 모듈 출력 업데이트

**파일**: `terraform/modules/compute/outputs.tf`

**제거할 출력**:
```hcl
# 제거
output "mysql_private_ip" { ... }
output "mysql_public_ip" { ... }
output "redis_private_ip" { ... }
output "redis_public_ip" { ... }
```

**추가할 출력**:
```hcl
output "nginx_gateway_public_ip" {
  description = "Public IP of Nginx Gateway"
  value       = aws_eip.nginx_eip.public_ip
}

output "nginx_gateway_private_ip" {
  description = "Private IP of Nginx Gateway"
  value       = aws_network_interface.nginx_eni.private_ip
}

output "nginx_gateway_public_dns" {
  description = "Public DNS of Nginx Gateway"
  value       = aws_instance.nginx_gateway.public_dns
}

output "nginx_eni_id" {
  description = "ENI ID of Nginx Gateway (for VPC routing)"
  value       = aws_network_interface.nginx_eni.id
}
```

**수정할 출력** (EIP 제거 반영): 출력 자체를 제거하기
```hcl
# 메인 서버는 이제 Public IP 없음
output "main_service_public_ip" {
  description = "Public IP of main service (removed - now private only)"
  value       = null  # 또는 출력 자체를 제거
}

# AI 서버도 Public IP 없음
output "ai_service_public_ip" {
  description = "Public IP of AI service (removed - now private only)"
  value       = null  # 또는 출력 자체를 제거
}
```

---

## 5. Phase 4: CloudFront 모듈 재구성

### 5.1 Origin 변경

**파일**: `terraform/modules/cloudfront/main.tf`

**변경 사항**:

1. **API Origin을 Nginx로 변경** (기존 라인 55-73)
   ```hcl
   # Before
   origin {
     domain_name = var.main_service_public_dns
     origin_id   = "MainServiceOrigin"
     ...
   }

   # After
   origin {
     domain_name = var.nginx_gateway_public_dns  # Nginx로 변경!
     origin_id   = "NginxAPIOrigin"

     custom_origin_config {
       http_port              = 80
       https_port             = 443
       origin_protocol_policy = "http-only"  # Nginx는 HTTP로 받음
       origin_ssl_protocols   = ["TLSv1.2"]
     }

     custom_header {
       name  = "X-Origin-Verify"
       value = "CloudFront-to-Nginx"  # 보안 검증용
     }
   }
   ```

2. **AI 전용 Origin 추가** (새로 추가)
   ```hcl
   # AI 추천 요청용 Origin (Nginx와 동일한 도메인, 경로만 다름)
   # 실제로는 동일한 Nginx 서버이므로 별도 Origin 불필요
   # 대신 Cache Behavior로 경로 구분
   ```

### 5.2 Cache Behavior 추가 (AI 경로)

**파일**: `terraform/modules/cloudfront/main.tf`

**추가 위치**: 기존 ordered_cache_behavior 블록 뒤에 추가

```hcl
# AI 추천 요청 경로
ordered_cache_behavior {
  path_pattern     = "/recommend/*"
  target_origin_id = "NginxAPIOrigin"  # API와 동일한 Origin

  allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  cached_methods   = ["GET", "HEAD"]
  compress         = false

  forwarded_values {
    query_string = true
    headers      = ["Authorization", "Accept", "Content-Type", "X-User-ID"]

    cookies {
      forward = "all"
    }
  }

  viewer_protocol_policy = "redirect-to-https"

  # 캐싱 비활성화 (개인화된 AI 응답)
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 0
}
```

**주요 설정**:
- **캐싱 비활성화**: AI 응답은 사용자별로 다르므로 캐싱 불가
- **쿠키 전달**: 인증 정보 필요
- **헤더 전달**: 사용자 ID 등 컨텍스트 정보

### 5.3 CloudFront 변수 업데이트

**파일**: `terraform/modules/cloudfront/variables.tf`

**변경**:
```hcl
# Before
variable "main_service_public_dns" {
  description = "Public DNS of main service EC2"
  type        = string
}

# After
variable "nginx_gateway_public_dns" {
  description = "Public DNS of Nginx Gateway server"
  type        = string
}
```

---

## 6. Phase 5: Environment 설정 (dev/main.tf)

### 6.1 모듈 호출 파라미터 변경

**파일**: `terraform/environments/dev/main.tf`

**변경 사항**:

```hcl
# ===== VPC 모듈 =====
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr

  # 추가: Nginx ENI를 NAT로 사용
  nginx_eni_id = module.compute.nginx_eni_id  # compute 모듈 출력 참조
}

# ===== Security 모듈 =====
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr

  # 추가: 관리자 SSH IP 화이트리스트
  admin_ssh_cidrs = var.admin_ssh_cidrs  # variables.tf에 정의 필요
}

# ===== Compute 모듈 =====
module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  ami_id       = var.ami_id
  key_name     = var.key_name

  # 인스턴스 타입 변경
  main_server_instance_type = "t3.medium"  # 상향
  ai_instance_type          = "t3.small"   # 유지
  nginx_instance_type       = "t3.micro"   # 신규

  # 네트워크 설정
  subnet_id            = module.vpc.public_subnet_id
  internet_gateway_id  = module.vpc.internet_gateway_id

  # 보안 그룹 (3개로 축소)
  main_service_sg_id   = module.security.main_service_sg_id
  ai_service_sg_id     = module.security.ai_service_sg_id
  nginx_gateway_sg_id  = module.security.nginx_gateway_sg_id  # 신규

  # 제거: mysql_sg_id, redis_sg_id

  # IAM 역할
  ses_role_arn     = module.ses.ses_role_arn
  bedrock_role_arn = module.bedrock.bedrock_role_arn
}

# ===== CloudFront 모듈 =====
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name = var.project_name
  environment  = var.environment

  # Origin 변경: Nginx Gateway로 변경
  nginx_gateway_public_dns = module.compute.nginx_gateway_public_dns

  # 제거: main_service_public_dns

  # S3 버킷 (변경 없음)
  frontend_bucket_regional_domain_name = module.s3.frontend_bucket_regional_domain_name
  images_bucket_regional_domain_name   = module.s3.images_bucket_regional_domain_name

  # OAC
  frontend_oac_id = module.s3.frontend_oac_id
  images_oac_id   = module.s3.images_oac_id

  # ACM
  acm_certificate_arn = module.acm_certificate.certificate_arn

  depends_on = [
    module.compute,  # Nginx 인스턴스가 먼저 생성되어야 함
  ]
}

# 나머지 모듈은 변경 없음 (S3, SES, Bedrock, ACM)
```

### 6.2 Environment 변수 추가

**파일**: `terraform/environments/dev/variables.tf`

**추가**:
```hcl
variable "admin_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into Nginx Bastion"
  type        = list(string)
  default     = []  # terraform.tfvars에서 실제 IP 지정

  # 예시:
  # default = ["203.0.113.0/32", "198.51.100.0/32"]
}
```

**terraform.tfvars 예시**:
```hcl
# terraform/environments/dev/terraform.tfvars
project_name = "mechuragi"
environment  = "dev"
vpc_cidr     = "10.0.0.0/16"
domain_name  = "mechuragi.kro.kr"

# 관리자 SSH 접근 IP (실제 IP로 교체!)
admin_ssh_cidrs = [
  "YOUR_OFFICE_IP/32",
  "YOUR_HOME_IP/32"
]

# 나머지 변수...
```

### 6.3 Environment 출력 업데이트

**파일**: `terraform/environments/dev/outputs.tf`

**제거**:
```hcl
# 제거
output "mysql_private_ip" { ... }
output "mysql_public_ip" { ... }
output "redis_private_ip" { ... }
output "redis_public_ip" { ... }
```

**추가**:
```hcl
output "nginx_gateway_public_ip" {
  description = "Public IP of Nginx Gateway (single entry point)"
  value       = module.compute.nginx_gateway_public_ip
}

output "nginx_gateway_private_ip" {
  description = "Private IP of Nginx Gateway"
  value       = module.compute.nginx_gateway_private_ip
}

output "nginx_gateway_ssh_command" {
  description = "SSH command to access Nginx Bastion"
  value       = "ssh -i YOUR_KEY.pem ec2-user@${module.compute.nginx_gateway_public_ip}"
}
```

---

## 7. 마이그레이션 실행 계획

### 7.1 단계별 실행 순서


#### Step 2: Terraform 코드 변경 (Day 1)
```bash
# 1. Security 모듈 수정
# - mysql_sg, redis_sg 제거
# - nginx_gateway_sg 추가
# - main_service_sg, ai_service_sg 규칙 변경

# 2. Compute 모듈 수정
# - MySQL, Redis 인스턴스 제거
# - 메인 서버 인스턴스 타입 변경, EIP 제거
# - AI 서버 EIP 제거
# - Nginx 게이트웨이 인스턴스 추가

# 3. CloudFront 모듈 수정
# - API Origin을 Nginx로 변경
# - AI Cache Behavior 추가

# 4. VPC 모듈 수정 (선택적)
# - Private 라우트 테이블 추가 (Nginx를 NAT로)

# 5. Environment 설정 변경
# - 모듈 호출 파라미터 업데이트
# - 변수 추가 (admin_ssh_cidrs)
```

#### Step 3: Terraform Plan 검증 (Day 1)
```bash
cd terraform/environments/dev

# Terraform 초기화 (모듈 변경 반영)
terraform init -upgrade

# Plan 실행 및 검토
terraform plan -out=refactoring.tfplan | tee plan-output.txt

# 예상 변경사항 확인:
# - 제거될 리소스: MySQL EC2, Redis EC2, EIP 3개
# - 추가될 리소스: Nginx EC2, Nginx EIP, Nginx SG
# - 수정될 리소스: 메인 서버, AI 서버, CloudFront, 보안 그룹 규칙
```

**주요 확인 포인트**:
- [ ] MySQL, Redis 인스턴스가 destroy 예정인지 확인
- [ ] Nginx 인스턴스가 create 예정인지 확인
- [ ] 메인/AI 서버가 in-place update인지 확인 (replace면 문제!)
- [ ] CloudFront가 update-in-place인지 확인 (recreate면 다운타임 발생)
- [ ] 보안 그룹 규칙 변경이 올바른지 확인
```

#### Step 5: Production 적용 (Day 3)
```bash
cd terraform/environments/dev

# 1. 사용자에게 점검 공지 (다운타임 예상 시간 공지)

# 2. Apply 실행
terraform apply refactoring.tfplan

# 예상 소요 시간: 10-15분
# - MySQL, Redis 인스턴스 종료: 2분
# - Nginx 인스턴스 생성 및 부팅: 3-5분
# - CloudFront 설정 전파: 5-10분
```

**적용 중 모니터링**:
```bash
# 다른 터미널에서 모니터링
watch -n 5 'aws ec2 describe-instances --filters "Name=tag:Name,Values=*mechuragi*" --query "Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]" --output table'
```

#### Step 6: 검증 및 테스트 (Day 3)
```bash
# 1. SSH 접속 테스트 (Nginx Bastion)
NGINX_IP=$(terraform output -raw nginx_gateway_public_ip)
ssh -i YOUR_KEY.pem ec2-user@$NGINX_IP

# 2. Nginx에서 메인/AI 서버로 점프 테스트
ssh -i YOUR_KEY.pem ec2-user@10.0.1.76   # 메인 서버
ssh -i YOUR_KEY.pem ec2-user@10.0.1.184  # AI 서버

# 3. Nginx 프록시 동작 확인
curl -H "Host: mechuragi.kro.kr" http://localhost/health
curl -H "Host: mechuragi.kro.kr" http://localhost/api/health
curl -H "Host: mechuragi.kro.kr" http://localhost/recommend/health

# 4. NAT 기능 테스트 (메인 서버에서)
ssh ec2-user@10.0.1.76
curl -I https://www.google.com  # Nginx NAT를 통해 외부 접속되어야 함

# 5. CloudFront 엔드투엔드 테스트
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl https://$CLOUDFRONT_URL/api/health
curl https://$CLOUDFRONT_URL/recommend/health

# 6. 프론트엔드 테스트 (브라우저)
# - React 앱 로드 확인
# - API 호출 정상 동작 확인
# - AI 추천 기능 정상 동작 확인
```

#### Step 7: 애플리케이션 배포 (Day 4)
```bash
# 1. 메인 서버에 docker-compose 배포 (애플리케이션 팀)
# - MySQL 컨테이너 실행
# - Redis 컨테이너 실행
# - API 서버 컨테이너 실행
# - 데이터 마이그레이션

# 2. AI 서버에 MySQL 연결 설정 추가
# - application.yml에 메인 서버 MySQL 연결 정보 추가

# 3. Nginx 설정 최종 조정
# - 애플리케이션 포트 확인 및 upstream 수정
# - SSL 인증서 설정 (Let's Encrypt)
```

### 7.2 롤백 계획

**롤백 시나리오 1: Terraform Apply 중 실패**
```bash
# Terraform은 자동으로 이전 상태로 롤백 시도
# 만약 중간 상태로 멈췄다면:
terraform refresh
terraform plan  # 현재 상태 확인
terraform apply  # 다시 시도 또는 수동 정리
```

**롤백 시나리오 2: Apply는 성공했으나 서비스 장애**
```bash
# 1. Git으로 이전 코드 복원
git checkout main
cd terraform/environments/dev

# 2. State 파일 백업본 확인
terraform state pull  # 현재 상태 확인

# 3. 이전 상태로 복원
terraform apply  # 이전 코드로 인프라 복원
# 주의: 새로 생성된 리소스는 삭제되고, 제거된 리소스는 재생성됨

# 4. 예상 소요 시간: 15-20분
```

**롤백 시나리오 3: 데이터 손실 발생**
```bash
# 1. MySQL 백업본 복원
# 2. 기존 MySQL 인스턴스 재시작 (AMI 스냅샷에서)
# 3. CloudFront Origin을 임시로 기존 메인 서버로 변경
```

---

## 8. 검증 체크리스트

### 8.1 인프라 검증

- [ ] **Nginx 게이트웨이**
  - [ ] Public IP 접근 가능
  - [ ] SSH 접속 가능 (관리자 IP에서만)
  - [ ] Nginx 서비스 실행 중
  - [ ] NAT 기능 동작 (메인 서버에서 외부 접속)
  - [ ] Health check 엔드포인트 응답 (curl http://NGINX_IP/health)

- [ ] **통합 메인 서버**
  - [ ] Private IP만 할당됨 (Public IP 없음)
  - [ ] Nginx에서 SSH 접속 가능
  - [ ] docker-compose 실행 중
  - [ ] MySQL 컨테이너 정상 동작
  - [ ] Redis 컨테이너 정상 동작
  - [ ] API 서버 컨테이너 정상 동작

- [ ] **AI 서버**
  - [ ] Private IP만 할당됨 (Public IP 없음)
  - [ ] Nginx에서 SSH 접속 가능
  - [ ] 메인 서버 MySQL 접속 가능
  - [ ] Bedrock API 호출 가능 (Nginx NAT 통해)
  - [ ] AI 서비스 정상 응답

- [ ] **보안 그룹**
  - [ ] 메인 서버: 8080 포트 Nginx에서만 접근 가능
  - [ ] 메인 서버: 3306 포트 AI 서버에서만 접근 가능
  - [ ] AI 서버: 8082 포트 Nginx에서만 접근 가능
  - [ ] Nginx: 80/443 포트 인터넷에서 접근 가능
  - [ ] Nginx: 22 포트 관리자 IP에서만 접근 가능

- [ ] **CloudFront**
  - [ ] /api/* 요청이 Nginx를 거쳐 메인 서버로 전달
  - [ ] /recommend/* 요청이 Nginx를 거쳐 AI 서버로 전달
  - [ ] /images/* 요청이 S3로 전달
  - [ ] / 요청이 프론트엔드 S3로 전달
  - [ ] HTTPS 정상 동작

### 8.2 성능 검증

- [ ] **응답 시간 측정**
  ```bash
  # API 응답 시간
  time curl https://CLOUDFRONT_URL/api/health

  # AI 추천 응답 시간
  time curl https://CLOUDFRONT_URL/recommend/test

  # 이전 구조와 비교하여 30-40% 개선 확인
  ```

- [ ] **네트워크 레이턴시**
  ```bash
  # 메인 서버 내부 (localhost 통신)
  ssh 10.0.1.76
  time redis-cli ping  # < 1ms 예상
  time mysql -h localhost -e "SELECT 1"  # < 5ms 예상
  ```

### 8.3 비용 검증

- [ ] **EC2 인스턴스 개수**: 4개 → 3개 감소 확인
- [ ] **Elastic IP 개수**: 4개 → 1개 감소 확인
- [ ] **NAT Gateway**: 제거 확인 (없어야 함)
- [ ] **예상 월 비용**: AWS Cost Explorer에서 확인

---

## 9. 주의사항 및 알려진 이슈

### 9.1 Terraform 의존성 순환 문제

**문제**: VPC 모듈에서 Nginx ENI를 참조하려면 Compute 모듈이 먼저 실행되어야 하지만, Compute 모듈은 VPC 출력(subnet_id 등)이 필요합니다.

**해결책**:
1. **옵션 A (권장)**: 2단계 배포
   ```bash
   # 1단계: Nginx 인스턴스만 먼저 생성 (VPC는 NAT 라우팅 없이)
   terraform apply -target=module.compute.aws_instance.nginx_gateway

   # 2단계: VPC 라우트 테이블 업데이트 (Nginx ENI 참조)
   terraform apply
   ```

2. **옵션 B**: VPC 모듈에서 nginx_eni_id를 선택적으로 처리
   ```hcl
   # VPC 라우트 테이블에서 조건부 라우팅
   dynamic "route" {
     for_each = var.nginx_eni_id != "" ? [1] : []
     content {
       cidr_block           = "0.0.0.0/0"
       network_interface_id = var.nginx_eni_id
     }
   }
   ```

### 9.2 CloudFront 캐시 무효화

**문제**: CloudFront Origin 변경 후 캐시가 남아있어 이전 Origin으로 요청이 갈 수 있음

**해결책**:
```bash
# CloudFront Distribution ID 확인
DIST_ID=$(terraform output -raw cloudfront_distribution_id)

# 캐시 무효화 생성
aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/api/*" "/recommend/*"

# 전체 캐시 무효화 (필요시)
aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"
```

### 9.3 NAT 설정 영구화

**문제**: Nginx 인스턴스 재부팅 시 iptables NAT 규칙이 초기화될 수 있음

**해결책**: User Data에 iptables-services 설치 및 저장 포함 (이미 포함됨)
```bash
# 수동으로 확인 및 재적용 (필요시)
ssh nginx_server
sudo service iptables save
sudo systemctl enable iptables
```

### 9.4 MySQL 데이터 마이그레이션 다운타임

**예상 다운타임**: 15-30분 (데이터 크기에 따라)

**최소화 방법**:
1. 읽기 전용 모드로 전환 후 마이그레이션
2. 증분 백업 사용 (binlog replication)
3. 블루-그린 배포 시 이전 MySQL 인스턴스 유지하며 데이터 동기화

---

## 10. 다음 단계 (Post-Refactoring)

### 10.1 모니터링 및 알림 설정

- [ ] CloudWatch 대시보드 생성
  - Nginx 인스턴스 메트릭 (CPU, 네트워크, 디스크)
  - 메인 서버 메트릭 (메모리 사용률 중요 - MySQL/Redis 포함)
  - AI 서버 메트릭 (Bedrock API 호출 횟수)

- [ ] CloudWatch 알람 설정
  - Nginx CPU > 80% (5분 이상)
  - 메인 서버 메모리 > 85%
  - CloudFront 5xx 에러율 > 1%
  - Bedrock 스로틀링 발생

### 10.2 고가용성 개선 (Phase 2)

- [ ] Nginx Auto Scaling Group 전환 (SPOF 제거)
- [ ] Application Load Balancer 도입
- [ ] RDS for MySQL 마이그레이션 (관리형 서비스)
- [ ] ElastiCache for Redis 마이그레이션

### 10.3 보안 강화

- [ ] AWS Systems Manager Session Manager로 SSH 대체
- [ ] GuardDuty 활성화 (위협 탐지)
- [ ] VPC Flow Logs 활성화 (네트워크 트래픽 감사)
- [ ] Secrets Manager로 데이터베이스 자격 증명 관리

### 10.4 백업 및 재해 복구

- [ ] MySQL 자동 백업 스크립트 (S3 업로드)
- [ ] AMI 자동 생성 스케줄 (AWS Backup)
- [ ] 재해 복구 절차 문서화
- [ ] 정기적인 복구 훈련 (DR Drill)

---

## 11. 참고 자료

- **원본 문서**: [docs/refactoring.md](./refactoring.md)
- **Terraform 공식 문서**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Nginx 리버스 프록시 가이드**: https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- **AWS NAT Instance 가이드**: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html
- **CloudFront Origin Groups**: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html

---

## 12. 작업 현황 추적

| Phase | 작업 내용 | 담당자 | 상태 | 완료일 |
|-------|----------|--------|------|--------|
| Phase 1 | VPC 및 네트워크 설정 | 진아 | ⬜ 미착수 | - |
| Phase 2 | Security 모듈 재설계 | 진아 | ⬜ 미착수 | - |
| Phase 3 | Compute 모듈 재구성 | 진아 | ⬜ 미착수 | - |
| Phase 4 | CloudFront 모듈 재구성 | 진아 | ⬜ 미착수 | - |
| Phase 5 | Environment 설정 변경 | 진아 | ⬜ 미착수 | - |
| Phase 6 | Terraform Plan 검증 | 진아 | ⬜ 미착수 | - |
| Phase 7 | Production 적용 | 진아 | ⬜ 미착수 | - |
| Phase 8 | 검증 및 테스트 | 진아 | ⬜ 미착수 | - |
| App 1 | 메인 서버 docker-compose | 희주 | ⬜ 미착수 | - |
| App 2 | AI 서버 MySQL 연결 | 진아 | ⬜ 미착수 | - |
| App 3 | Nginx 최종 설정 | 희주 | ⬜ 미착수 | - |
| App 4 | 데이터 마이그레이션 | 희주 | ⬜ 미착수 | - |

**범례**:
- ⬜ 미착수
- 🔄 진행 중
- ✅ 완료
- ⚠️ 블로킹 이슈

---

**마지막 업데이트**: 2025-12-12
**문서 버전**: 1.0
**작성자**: Claude Code (AI Assistant)
