# Mechuragi Infrastructure

메추라기 프로젝트의 **분산 마이크로서비스 아키텍처**를 구현하는 AWS 인프라 저장소입니다. Terraform과 Ansible을 사용하여 React 프론트엔드와 Spring Boot 백엔드의 최적화된 배포 환경을 제공합니다.

## 🏗️ 아키텍처 개요

### 분산 서비스 구조 (4개 인스턴스 + React CDN + CI/CD)
```
                    ┌──────────────────────────────┐
                    │  사용자 (Browser/Mobile)      │
                    └──────────────┬───────────────┘
                                   │ HTTPS
                    ┌──────────────▼───────────────┐
                    │   CloudFront (CDN)           │
                    │   - CNAME: mechuragi.kro.kr  │
                    │   - SSL: ACM Certificate     │
                    └──┬─────────┬─────────┬───────┘
                       │         │         │
            ┌──────────▼──┐  ┌──▼─────┐  ┌▼───────────┐
            │  S3 (React) │  │S3 (Img)│  │EC2 (Nginx) │
            │  정적 파일   │  │이미지   │  │  :80       │
            └─────────────┘  └────────┘  └─┬──────────┘
                                            │ reverse proxy
                    ┌───────────────────────▼─────────┐
                    │  메인 서비스 (Spring Boot)      │
                    │  :8080 + SES                    │
                    │  Blue-Green 배포                │
                    └──────────────┬──────────────────┘
                                   │ VPC 내부 통신
                    ┌──────────────▼──────────────────┐
                    │  AI 추천 서비스 (Spring Boot)   │
                    │  :8082 + Bedrock                │
                    │  Docker 배포                    │
                    └──────────────┬──────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
    ┌───────▼──────┐      ┌───────▼──────┐      ┌───────▼──────┐
    │  MySQL DB    │      │ Redis Cache  │      │ GitHub CI/CD │
    │  :3306       │      │ :6379        │      │ + Discord    │
    │  VPC 내부만  │      │ VPC 내부만   │      │ 알림         │
    └──────────────┘      └──────────────┘      └──────────────┘
```

### 네트워크 보안 설계
- **Public Subnet** (10.0.2.0/24): 모든 서비스 배치 (비용 최적화)
- **보안 그룹 4계층**: 서비스별 차별화된 접근 제어
  - **Level 1**: Main Service → 인터넷 전체 허용
  - **Level 2**: AI/DB/Cache → VPC 내부만 허용 (10.0.0.0/16)

## 📁 프로젝트 구조

```
mechuragi-infra/
├── terraform/                          # 🏗️ AWS 인프라 프로비저닝
│   ├── README.md                       # Terraform 상세 가이드
│   ├── environments/
│   │   └── dev/                        # 개발 환경 (통합 구조)
│   │       ├── main.tf                 # 메인 설정
│   │       ├── variables.tf            # 변수 정의
│   │       ├── outputs.tf              # 출력 값
│   │       └── terraform.tfvars        # 실제 변수 값
│   └── modules/                        # 📦 재사용 가능한 모듈
│       ├── vpc/                        # Public 서브넷 네트워크
│       ├── security/                   # 4계층 보안 그룹
│       ├── compute/                    # 4개 분산 인스턴스
│       ├── s3/                         # Frontend + Images 버킷
│       ├── cloudfront/                 # 3-Origin CDN
│       ├── ses/                        # 이메일 서비스 + 템플릿
│       └── bedrock/                    # AI 서비스 연동
└── ansible/                            # ⚙️ 서버 구성 관리
    ├── README.md                       # Ansible 실행 가이드
    ├── ansible.cfg                     # Ansible 설정
    ├── group_vars/
    │   └── all/
    │       └── main.yml                # 통합 변수 설정
    ├── inventory/
    │   └── hosts.yml                   # 4개 서버 인벤토리
    ├── roles/                          # 🔧 Ansible 역할
    │   ├── common/                     # 기본 시스템 설정
    │   ├── docker/                     # Docker 환경
    │   ├── mysql/                      # MySQL 데이터베이스
    │   ├── redis/                      # Redis 캐시
    │   └── nginx/                      # Nginx 템플릿
    └── playbooks/                      # 🎮 실행 플레이북
        ├── setup/                      # 🔧 설치 및 구성
        │   ├── deploy-all-services.yml    # 전체 인프라 배포
        │   ├── setup-basic-system.yml     # 기본 시스템 설정
        │   ├── setup-database.yml         # MySQL 설치
        │   ├── setup-cache.yml            # Redis 설치
        │   ├── setup-docker-only.yml      # Docker 설치
        │   └── setup-nginx.yml            # Nginx 설치
        └── test/                       # ✅ 검증 및 테스트
            ├── test-connectivity.yml       # AI/Main 서비스 헬스체크
            ├── test-db.yml                 # MySQL 연결성 테스트
            ├── test-redis.yml              # Redis 연결성 테스트
            ├── test-docker.yml             # Docker 설치 검증
            └── test-front.yml              # 프론트엔드 테스트
```

## 🏛️ 인프라 구성

### AWS 핵심 리소스

#### 🌐 네트워크 (VPC 모듈)
- **VPC**: 10.0.0.0/16 CIDR 블록
- **Public Subnet**: 10.0.2.0/24 (모든 인스턴스 배치)
- **Internet Gateway**: 직접 인터넷 연결
- **🔥 NAT Gateway 제거**: 월 $45 비용 절감

#### 💻 컴퓨팅 (Compute 모듈)
- **메인 서비스**: t3.micro (Public IP + Elastic IP)
- **AI 서비스**: t3.small (Bedrock IAM Profile)
- **MySQL 서버**: t3.micro (30GB gp3 볼륨)
- **Redis 서버**: t3.micro (캐시 전용)
- **🔥 75% 비용 절감**: 3개 서비스를 t3.micro로 최적화

#### 🛡️ 보안 (Security 모듈)
- **Main Service SG**:
  - HTTP(80), HTTPS(443): 전체 인터넷 허용 (CloudFront 포함)
  - SSH(22): 관리용
  - Spring(8080): 내부 통신
- **AI Service SG**:
  - Spring(8082): VPC 내부만 (10.0.0.0/16)
  - SSH(22): 관리용
- **MySQL SG**:
  - MySQL(3306): VPC 내부만 (10.0.%에서만 접근)
  - SSH(22): 관리용
- **Redis SG**:
  - Redis(6379): VPC 내부만 (10.0.0.0/16)
  - SSH(22): 관리용

#### 🗄️ 스토리지 (S3 모듈)
- **Frontend Bucket**: `mechuragi-dev-frontend` (React SPA)
- **Images Bucket**: `mechuragi-dev-images` (이미지 저장)
- **암호화**: AES-256 서버 측 암호화
- **보안**: CloudFront OAC를 통해서만 접근 허용

#### 🌍 CDN (CloudFront 모듈)
- **3-Origin 구조**:
  - Frontend Origin: React 정적 파일 (S3 + OAC)
  - Images Origin: 이미지 파일 (S3 + OAC)
  - API Origin: Spring Boot API (EC2:80 Nginx → 8080)
- **커스텀 도메인**: `mechuragi.kro.kr` (ACM SSL 인증서)
- **캐시 정책**: 용도별 차별화된 TTL 설정
  - React 파일: 1일 (최대 1년)
  - 이미지: 1주일 (최대 1년)
  - API: 캐싱 비활성화 (실시간 데이터)
- **SPA 지원**: 404/403 → index.html 리디렉션
- **보안**: HTTPS 강제, S3 직접 접근 차단 (OAC)

#### 📧 이메일 (SES 모듈)
- **도메인 검증**: mechuragi.kro.kr
- **이메일 템플릿**: 환영 메일, 비밀번호 재설정
- **DKIM 설정**: 이메일 인증 강화
- **모니터링**: Configuration Set

#### 🧠 AI 서비스 (Bedrock 모듈)
- **Claude 3 Haiku**: 빠르고 비용 효율적인 대화형 AI
  - Chat Model: `anthropic.claude-3-haiku-20240307-v1:0`
  - Smart Model: `anthropic.claude-3-haiku-20240307-v1:0`
- **Titan Text Embeddings**: 벡터 임베딩 (`amazon.titan-embed-text-v1`)
- **IAM 권한**: Bedrock 전체 접근
- **로깅**: CloudWatch (14일 보존)

### 서버 소프트웨어 스택

#### 🐳 컨테이너 환경
- **Docker & Docker Compose**: 컨테이너 오케스트레이션
- **Blue-Green 배포**: 무중단 서비스 업데이트
- **MySQL 8.0**: 네이티브 설치 (VPC 내부 bind-address: 0.0.0.0)
- **Redis 6**: 네이티브 설치 (VPC 내부 통신)
- **Nginx**: Reverse Proxy (CloudFront → API 라우팅)
- **Multi-platform 빌드**: ARM64/AMD64 지원

#### 🌐 Nginx 설정 (역방향 프록시)
- **포트 80**: CloudFront에서 들어오는 요청 처리
- **라우팅**:
  - `/api/*` → Spring Boot (8080)
  - `/actuator/*` → Spring Boot 헬스체크 (VPC 내부만)
  - `/` → 404 (프론트엔드는 CloudFront/S3에서 제공)
- **Blue-Green 지원**: 동적 업스트림 전환 (8080 ↔ 8081)

#### ⚙️ 시스템 도구
- **개발 도구**: git, curl, wget, vim, htop
- **모니터링**: htop, docker stats
- **네트워크**: UFW 방화벽 (기본 비활성화)

## 🚀 배포 가이드

### 🔄 CI/CD 파이프라인 (추천)

#### GitHub Actions 자동 배포
```bash
# 1. GitHub Secrets 설정
DOCKERHUB_USERNAME     # Docker Hub 사용자명
DOCKERHUB_TOKEN        # Docker Hub 토큰
EC2_SSH_KEY            # EC2 SSH 개인키
MAIN_SERVER_HOST       # 메인 서버 IP
AI_SERVER_HOST         # AI 서버 IP
DB_HOST                # MySQL 서버 IP
DB_PASSWORD            # MySQL 비밀번호
REDIS_HOST             # Redis 서버 IP
MAIN_SERVICE_URL       # 메인 서비스 URL
DISCORD_WEBHOOK        # Discord 알림 웹훅

# 2. 자동 배포 실행
git push origin main    # main 브랜치 푸시로 자동 배포
```

#### Blue-Green 배포 프로세스
1. **빌드 단계**: Spring Boot 애플리케이션 빌드
2. **테스트 단계**: 자동화된 테스트 실행
3. **이미지 빌드**: Docker 멀티플랫폼 이미지 생성
4. **배포 단계**:
   - 새 컨테이너(Green) 시작
   - 헬스체크 수행
   - Nginx 트래픽 전환
   - 이전 컨테이너(Blue) 제거
5. **알림**: Discord로 배포 결과 전송

### 📋 수동 배포 (개발/테스트용)

### 📝 사전 준비

1. **AWS 설정**
   ```bash
   aws configure
   # AdministratorAccess 권한 필요
   ```

2. **도구 설치**
   ```bash
   # Terraform 1.0+
   terraform version

   # Ansible 2.9+
   ansible --version
   ```

3. **SSH 키 준비**
   ```bash
   # AWS 콘솔에서 mechuragi-dev-key 생성
   chmod 400 ~/.ssh/mechuragi-dev-key.pem
   ```

### 🎯 1단계: Terraform 인프라 배포

```bash
# 1. 환경 설정
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars

# 2. 인프라 배포 (약 5-10분)
terraform init
terraform plan
terraform apply

# 3. 출력 정보 확인
terraform output
```

**terraform.tfvars 설정 예시:**
```hcl
# AWS 설정
aws_region   = "ap-northeast-2"
project_name = "mechuragi"
environment  = "dev"

# 네트워크
vpc_cidr = "10.0.0.0/16"

# EC2 인스턴스
key_pair_name              = "mechuragi-dev-key"
main_service_instance_type = "t3.micro"
ai_service_instance_type   = "t3.small"
mysql_instance_type        = "t3.micro"
redis_instance_type        = "t3.micro"
mysql_volume_size          = 30

# SES 이메일
ses_domain     = "mechuragi.kro.kr"
ses_from_email = "noreply@mechuragi.kro.kr"

# Bedrock AI (Claude 3 Haiku - 빠르고 비용 효율적)
bedrock_chat_model      = "anthropic.claude-3-haiku-20240307-v1:0"
bedrock_smart_model     = "anthropic.claude-3-haiku-20240307-v1:0"
bedrock_embedding_model = "amazon.titan-embed-text-v1"

# CloudFront 커스텀 도메인 (ACM 인증서 발급 후 활성화)
domain_name             = "mechuragi.kro.kr"
use_custom_domain       = true   # ACM 검증 완료 후 true로 설정
wait_for_acm_validation = true
```

### ⚙️ 2단계: Ansible 서버 설정

```bash
cd ansible

# 1. 인벤토리 파일 설정
cp inventory/hosts.yml.template inventory/hosts.yml
# Terraform 출력의 IP 주소들을 입력

# 2. 변수 파일 설정
vi group_vars/all/main.yml
# 필요한 변수들 설정

# 3. 전체 인프라 배포 (권장)
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml

# 또는 개별 설정 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-basic-system.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-cache.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-nginx.yml

# 4. 배포 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
ansible-playbook -i inventory/hosts.yml playbooks/test/test-connectivity.yml
```

### 🎨 3단계: React 프론트엔드 배포

```bash
# 1. React 앱 빌드
npm run build

# 2. S3에 업로드
aws s3 sync ./build s3://mechuragi-dev-frontend --delete

# 3. 이미지 파일 업로드
aws s3 sync ./images s3://mechuragi-dev-images/images/

# 4. CloudFront 접근
# https://XXXXXX.cloudfront.net/
```

## 📊 배포 결과

### 🖥️ 접속 정보
```bash
# 메인 서비스 (Elastic IP)
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@XXX.XXX.XXX.XXX

# AI 서비스 (VPC 내부)
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@10.0.2.XXX

# MySQL 서버 (VPC 내부)
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@10.0.2.XXX

# Redis 서버 (VPC 내부)
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@10.0.2.XXX
```

### 🌐 서비스 URL
- **React 앱**: `https://mechuragi.kro.kr/` (CloudFront 커스텀 도메인)
- **API 엔드포인트**: `https://mechuragi.kro.kr/api/`
- **이미지 CDN**: `https://mechuragi.kro.kr/images/`
- **CloudFront 기본 도메인**: `https://XXXXXX.cloudfront.net/`
- **메인 서비스 직접 (Nginx)**: `http://XXX.XXX.XXX.XXX/api/`
- **AI 서비스 직접**: `http://10.0.2.XXX:8082` (VPC 내부만)
- **헬스체크**:
  - 메인 (외부): `http://XXX.XXX.XXX.XXX/actuator/health`
  - 메인 (내부): `http://localhost:8080/actuator/health`
  - AI (VPC): `http://10.0.2.XXX:8082/actuator/health`

### 📈 성능 & 비용
- **EC2 비용**: 월 $25 (3개 t3.micro + 1개 t3.small)
- **네트워크 비용**: NAT Gateway 제거로 월 $45 절감
- **스토리지**: S3 Standard + CloudFront PriceClass_100
- **AI 서비스**: Bedrock 사용량 기반 과금

## 🔧 운영 가이드

### 📊 모니터링
```bash
# 전체 서비스 상태 확인
ansible all -m ping -i inventory/hosts.yml

# 서비스 상태 확인
ansible all -m command -a "systemctl status docker mysql redis" -i inventory/hosts.yml

# Docker 컨테이너 상태 확인
ansible main_service -m command -a "docker ps" -i inventory/hosts.yml
ansible ai_service -m command -a "docker ps" -i inventory/hosts.yml

# Blue-Green 배포 상태 확인
ansible main_service -m command -a "curl -s http://localhost:8080/actuator/health" -i inventory/hosts.yml
ansible main_service -m command -a "curl -s http://localhost:8081/actuator/health" -i inventory/hosts.yml

# 리소스 사용량 확인
ansible all -m command -a "htop -n 1" -i inventory/hosts.yml

# Discord 알림 확인
# GitHub Actions 로그에서 배포 상태 모니터링
```

### 🔄 업데이트
```bash
# CI/CD 파이프라인을 통한 업데이트 (추천)
git push origin main  # 자동 배포 트리거

# 수동 Blue-Green 배포
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@XXX.XXX.XXX.XXX
cd /home/ubuntu/app
./scripts/blue-green-deploy.sh

# 특정 모듈만 재배포
terraform apply -target=module.cloudfront

# 특정 서버만 재설정
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-cache.yml --limit cache

# 특정 서비스 재배포
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml --limit database

# 배포 롤백 (Blue-Green)
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@XXX.XXX.XXX.XXX
cd /home/ubuntu/app
./scripts/blue-green-deploy.sh rollback
```

### 🚨 문제 해결
```bash
# Blue-Green 배포 로그 확인
ansible main_service -m command -a "docker logs mechuragi-main-blue" -i inventory/hosts.yml
ansible main_service -m command -a "docker logs mechuragi-main-green" -i inventory/hosts.yml
ansible ai_service -m command -a "docker logs mechuragi-ai-service" -i inventory/hosts.yml

# 네트워크 연결 테스트
ansible-playbook -i inventory/hosts.yml playbooks/test/test-connectivity.yml

# MySQL 연결 테스트
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml

# Redis 연결 테스트
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml

# 서비스 헬스체크
curl -f http://XXX.XXX.XXX.XXX:8080/actuator/health
curl -f http://10.0.2.XXX:8082/actuator/health

# Nginx 설정 확인
ansible main_service -m command -a "nginx -t" -i inventory/hosts.yml
ansible main_service -m command -a "systemctl status nginx" -i inventory/hosts.yml

# Nginx 로그 확인
ansible main_service -m command -a "tail -n 50 /var/log/nginx/main_service_error.log" -i inventory/hosts.yml
ansible main_service -m command -a "tail -n 50 /var/log/nginx/main_service_access.log" -i inventory/hosts.yml

# GitHub Actions 로그 확인
# https://github.com/USERNAME/REPO/actions

# Discord 알림 테스트
# GitHub Actions에서 수동 트리거로 알림 테스트

# CloudFront 캐시 무효화
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"

# CloudFront 배포 상태 확인
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID --query 'Distribution.Status'

# CloudFront 커스텀 도메인 설정 확인
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID --query 'Distribution.DistributionConfig.Aliases'

# Docker 네트워크 문제 해결
ansible all -m command -a "docker network ls" -i inventory/hosts.yml
ansible all -m command -a "docker network create app_mechuragi-network" -i inventory/hosts.yml
```

## 🛡️ 보안 특징

### 🔒 네트워크 보안
- **VPC 내부 통신**: DB/캐시는 10.0.0.0/16에서만 접근
- **MySQL 접근 제어**: VPC 내부 10.0.% 호스트만 허용
- **Redis bind 설정**: 0.0.0.0으로 VPC 내부 통신, 보안 그룹으로 제어
- **Nginx Reverse Proxy**: CloudFront → Nginx(80) → Spring Boot(8080)
- **Elastic IP**: 메인 서비스 고정 IP
- **HTTPS 강제**: CloudFront 자동 리디렉션 + ACM SSL 인증서

### 🔐 데이터 보안
- **EBS 암호화**: 모든 볼륨 AES-256 암호화
- **S3 암호화**: 서버 측 암호화 + 버전 관리
- **CloudFront OAC**: S3 직접 접근 차단
- **TLS 1.2**: CloudFront 최소 프로토콜 버전

### 🔑 접근 보안
- **SSH 키 인증**: 모든 서버 키 페어 기반
- **IAM 최소 권한**: 서비스별 필요 권한만
  - Main Service: SES 전송 권한
  - AI Service: Bedrock 접근 권한
  - MySQL/Redis: EC2 메타데이터 조회 권한
- **민감 정보 분리**: Git에서 완전 제외 (.gitignore)
- **Actuator 보안**: VPC 내부(10.0.0.0/16)에서만 접근

## 🔐 SSH 터널링 및 접근 구조

### 🏗️ 터널링 구조
```
┌─────────────────┐
│   개발자 PC     │
│  (로컬 환경)    │
└────────┬────────┘
         │ SSH (22)
         │ 공인 인터넷
         ▼
┌─────────────────────────────────────────┐
│         AWS VPC (10.0.0.0/16)          │
│                                         │
│  ┌──────────────────┐ Level 1 (Public) │
│  │  Main Service    │                  │
│  │  - Public IP ✓   │ ◄─── SSH 게이트웨이
│  │  - Private IP ✓  │                  │
│  └────────┬─────────┘                  │
│           │ VPC Private Network        │
│           │ (10.0.x.x)                 │
│  ┌────────┴─────────────────────────┐  │
│  │     Level 2 (Private Only)       │  │
│  │                                  │  │
│  │  ┌──────────┐  ┌──────────┐    │  │
│  │  │  MySQL   │  │  Redis   │    │  │
│  │  │ Private  │  │ Private  │    │  │
│  │  └──────────┘  └──────────┘    │  │
│  │  ┌──────────┐                  │  │
│  │  │AI Server │                  │  │
│  │  │ Private  │                  │  │
│  │  └──────────┘                  │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### 📊 연결 흐름
```
MySQL Workbench
    ↓
[SSH 터널] 개발자 PC → Main Service (Public IP:22)
    ↓
[MySQL 연결] Main Service → MySQL (Private IP:3306)
    ↓
✅ DB 작업 가능
```

### 🔐 보안 계층 구조

#### Level 1 (Public)
- **Main Service**: 외부 접근 가능
- 역할: SSH 게이트웨이 + 웹 서비스

#### Level 2 (Private)
- **MySQL, Redis, AI Server**: Private IP만
- 외부 직접 접근 불가
- Main Service 경유만 가능

### 🎯 핵심 포인트
```
✅ DB는 외부 노출 안 됨 (Private IP만)
✅ Main Service가 단일 진입점
✅ 개발자 IP만 SSH 접근 가능
✅ 2단계 보안 구조 유지
```

### 🛠️ MySQL Workbench 설정
**SSH 터널 설정:**
```
SSH Hostname: Main Service Public IP
SSH Username: ubuntu
SSH Key: /path/to/key.pem
MySQL Hostname: MySQL Private IP (10.0.x.x)
```

**Security Group:**
```
Main Service Inbound: 개발자IP → 22
MySQL Inbound: VPC 내부(10.0.0.0/16) → 3306
```

## 📚 문서 링크

### 인프라 가이드
- **[Terraform 상세 가이드](terraform/README.md)**: 인프라 모듈별 설정
- **[Ansible 실행 가이드](ansible/README.md)**: 서버 설정 단계별 실행

### 트러블슈팅
- **[CloudFront 403 오류 해결](docs/cloudfront-403-troubleshooting.md)**: 커스텀 도메인 설정 문제 해결
- **[VPC 내부 연결성 가이드](docs/vpc-internal-connectivity.md)**: MySQL/Redis 연결 문제 진단
- **[일반 트러블슈팅](docs/troubleshooting-guide.md)**: 자주 발생하는 문제 해결

### AWS 서비스 설정
- CloudFront 커스텀 도메인 및 ACM 인증서
- SES 이메일 서비스 연동
- Bedrock AI 서비스 연동

## 💡 주요 특징

- ✅ **분산 마이크로서비스**: 4개 독립 서비스
- ✅ **React + Spring Boot**: 현대적 풀스택 아키텍처
- ✅ **CloudFront CDN**: 커스텀 도메인 + HTTPS (mechuragi.kro.kr)
- ✅ **Nginx Reverse Proxy**: CloudFront → Nginx → Spring Boot
- ✅ **Blue-Green 배포**: 무중단 서비스 업데이트
- ✅ **CI/CD 파이프라인**: GitHub Actions 자동 배포
- ✅ **Docker 컨테이너화**: 멀티플랫폼 지원
- ✅ **실시간 알림**: Discord 배포 상태 모니터링
- ✅ **비용 최적화**: 75% EC2 비용 절감
- ✅ **보안 중심**: 4계층 네트워크 보안 + VPC 격리
- ✅ **CDN 최적화**: 3-Origin CloudFront (React/Images/API)
- ✅ **AI 통합**: AWS Bedrock 연동
- ✅ **자동화**: IaC + Configuration Management
- ✅ **검증 강화**: Ansible 자동 검증 (MySQL/Redis/Nginx)
- ✅ **확장 가능**: 모듈화된 아키텍처

---

## 🆕 최신 업데이트 (v2.2)

### ✨ 새로운 기능 (v2.2)
- **📁 Ansible 구조 개편**: Setup/Test Playbook 분리
- **✅ 독립적인 테스트**: test-db.yml, test-redis.yml, test-docker.yml
- **🔧 Setup Playbook 단순화**: 설치/구성에만 집중
- **📊 상세 검증 시스템**: 4단계 MySQL 검증, 6단계 Redis 검증
- **🔐 SSH 터널링 가이드**: MySQL Workbench 설정 문서화

### 🔧 주요 개선사항 (v2.2)
- **Playbook 관심사 분리**: `playbooks/setup/`과 `playbooks/test/` 디렉토리 구조
- **setup-nginx.yml 추가**: Nginx 설치를 독립 playbook으로 분리
- **테스트 자동화**: 각 서비스 설치 후 독립적인 검증 가능
- **클라이언트 자동 설치**: MySQL/Redis 클라이언트 자동 설치 및 검증
- **에러 메시지 개선**: 더 깔끔한 테스트 출력 (failed_when/changed_when)

### ✨ 이전 업데이트 (v2.1)
- **🌐 CloudFront 커스텀 도메인**: `mechuragi.kro.kr` HTTPS 지원
- **🔒 ACM SSL 인증서**: TLS 1.2 암호화 통신
- **🔄 Nginx Reverse Proxy**: CloudFront → Nginx → Spring Boot 아키텍처
- **📊 Ansible 검증 강화**: MySQL/Redis 설치 후 자동 검증
- **🔑 IAM 권한 최적화**: EC2 메타데이터 조회 권한 추가
- **📝 트러블슈팅 문서**: CloudFront 403, VPC 연결성 가이드
- **CloudFront Origin**: EC2:8080 → Nginx:80 → Spring:8080 (프록시 구조)
- **Nginx 역할 명확화**: `/api/*`만 처리, 프론트엔드는 S3/CloudFront
- **MySQL 사용자 권한**: VPC 내부(10.0.%)만 접근 허용 (보안 강화)
- **Redis bind 설정**: 0.0.0.0으로 VPC 내부 통신 지원

### 📦 이전 업데이트 (v2.0)
- **🔄 Blue-Green 배포**: 메인 서비스 무중단 업데이트
- **🤖 GitHub Actions CI/CD**: 자동 빌드, 테스트, 배포
- **🐳 Docker 컨테이너화**: 멀티플랫폼 이미지 빌드 (ARM64/AMD64)
- **💬 Discord 알림**: 실시간 배포 상태 모니터링
- **🎯 AI 서비스 분리**: 독립적인 추천 서비스 (Port 8082)

---

**🎯 이 인프라는 메추라기 프로젝트의 완전한 분산 마이크로서비스 환경을 제공하며, 개발부터 운영까지 모든 단계를 지원합니다.**