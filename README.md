# Mechuragi Infrastructure

메추라기 프로젝트의 **분산 마이크로서비스 아키텍처**를 구현하는 AWS 인프라 저장소입니다. Terraform과 Ansible을 사용하여 React 프론트엔드와 Spring Boot 백엔드의 최적화된 배포 환경을 제공합니다.

## 🏗️ 아키텍처 개요

### 분산 서비스 구조 (4개 인스턴스 + React CDN + CI/CD)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React 앱      │    │  메인 서비스      │    │  AI 추천 서비스   │
│  (S3+CloudFront)│ ←→ │ (Spring Boot)   │ ←→ │ (Spring Boot)   │
│                 │    │ :8080 + SES     │    │ :8082 + Bedrock │
│                 │    │ Blue-Green 배포  │    │ Docker 배포     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ↕                      ↕                      ↕
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   이미지 CDN    │    │   MySQL DB      │    │   Redis Cache   │
│   (CloudFront)   │    │   (Database)    │    │   (Cache)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              ↕                      ↕
                    ┌─────────────────┐    ┌─────────────────┐
                    │ GitHub Actions  │    │ Discord 알림     │
                    │ CI/CD Pipeline  │    │ 배포 상태 모니터링│
                    └─────────────────┘    └─────────────────┘
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
    │       └── common.yml              # 통합 변수 설정
    ├── inventory/
    │   └── hosts.yml                   # 4개 서버 인벤토리
    ├── roles/                          # 🔧 Ansible 역할
    │   ├── common/                     # 기본 시스템 설정
    │   ├── docker/                     # Docker 환경
    │   ├── mysql/                      # MySQL 데이터베이스
    │   ├── redis/                      # Redis 캐시
    │   ├── nginx/                      # 웹 서버 (역방향 프록시)
    │   └── application/                # Spring Boot 애플리케이션
    └── playbooks/                      # 🎮 실행 플레이북
        ├── setup-system.yml           # 시스템 기본 설정
        ├── setup-docker.yml           # Docker 환경
        ├── setup-services.yml         # MySQL + Redis
        ├── setup-applications.yml     # Spring Boot 앱들
        └── verify-setup.yml           # 전체 검증
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
- **Main Service SG**: HTTP(80), HTTPS(443), SSH(22), Spring(8080), Blue-Green(8081)
- **AI Service SG**: Spring(8082), SSH(22) - VPC 내부만
- **MySQL SG**: MySQL(3306), SSH(22) - VPC 내부만
- **Redis SG**: Redis(6379), SSH(22) - VPC 내부만

#### 🗄️ 스토리지 (S3 모듈)
- **Frontend Bucket**: `mechuragi-dev-frontend` (React SPA)
- **Images Bucket**: `mechuragi-dev-images` (이미지 저장)
- **암호화**: AES-256 서버 측 암호화
- **보안**: CloudFront OAC를 통해서만 접근 허용

#### 🌍 CDN (CloudFront 모듈)
- **3-Origin 구조**:
  - Frontend Origin: React 정적 파일 (S3)
  - Images Origin: 이미지 파일 (S3)
  - API Origin: Spring Boot API (EC2:8080)
- **캐시 정책**: 용도별 차별화된 TTL 설정
- **SPA 지원**: 404 → index.html 리디렉션

#### 📧 이메일 (SES 모듈)
- **도메인 검증**: mechuragi.kro.kr
- **이메일 템플릿**: 환영 메일, 비밀번호 재설정
- **DKIM 설정**: 이메일 인증 강화
- **모니터링**: Configuration Set

#### 🧠 AI 서비스 (Bedrock 모듈)
- **Claude 3 Sonnet**: 대화형 AI
- **Titan Text Embeddings**: 벡터 임베딩
- **IAM 권한**: Bedrock 전체 접근
- **로깅**: CloudWatch (14일 보존)

### 서버 소프트웨어 스택

#### 🐳 컨테이너 환경
- **Docker & Docker Compose**: 컨테이너 오케스트레이션
- **Blue-Green 배포**: 무중단 서비스 업데이트
- **MySQL 8.0**: Docker 컨테이너로 실행
- **Redis 6**: 시스템 서비스로 경량 실행
- **Multi-platform 빌드**: ARM64/AMD64 지원

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
aws_region                  = "ap-northeast-2"
project_name               = "mechuragi"
environment                = "dev"
vpc_cidr                   = "10.0.0.0/16"
key_pair_name              = "mechuragi-dev-key"
main_service_instance_type = "t3.micro"
ai_service_instance_type   = "t3.small"
mysql_instance_type        = "t3.micro"
redis_instance_type        = "t3.micro"
mysql_volume_size          = 30
ses_domain                 = "mechuragi.kro.kr"
ses_from_email            = "noreply@mechuragi.kro.kr"
bedrock_chat_model         = "anthropic.claude-3-sonnet-20240229-v1:0"
bedrock_smart_model        = "anthropic.claude-3-sonnet-20240229-v1:0"
bedrock_embedding_model    = "amazon.titan-embed-text-v1"
```

### ⚙️ 2단계: Ansible 서버 설정

```bash
cd ansible

# 1. 인벤토리 파일 설정
cp inventory/hosts.yml.template inventory/hosts.yml
# Terraform 출력의 IP 주소들을 입력

# 2. 변수 파일 설정
vi group_vars/all/common.yml
# 필요한 변수들 설정

# 3. 순차적 설정 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-docker.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-services.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-applications.yml

# 4. 전체 검증
ansible-playbook -i inventory/hosts.yml playbooks/verify-setup.yml
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
- **React 앱**: `https://XXXXXX.cloudfront.net/`
- **API 엔드포인트**: `https://XXXXXX.cloudfront.net/api/`
- **이미지 CDN**: `https://XXXXXX.cloudfront.net/images/`
- **메인 서비스 직접**: `http://XXX.XXX.XXX.XXX:8080`
- **AI 서비스 직접**: `http://10.0.2.XXX:8082` (VPC 내부만)
- **헬스체크**:
  - 메인: `http://XXX.XXX.XXX.XXX:8080/actuator/health`
  - AI: `http://10.0.2.XXX:8082/actuator/health`

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
ansible-playbook -i inventory/hosts.yml playbooks/setup-services.yml --limit ai_service

# 애플리케이션 배포 업데이트
ansible-playbook -i inventory/hosts.yml playbooks/setup-applications.yml --tags deploy

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
ansible-playbook -i inventory/hosts.yml playbooks/test-connectivity.yml

# 서비스 헬스체크
curl -f http://XXX.XXX.XXX.XXX:8080/actuator/health
curl -f http://10.0.2.XXX:8082/actuator/health

# Nginx 설정 확인
ansible main_service -m command -a "nginx -t" -i inventory/hosts.yml
ansible main_service -m command -a "systemctl status nginx" -i inventory/hosts.yml

# GitHub Actions 로그 확인
# https://github.com/USERNAME/REPO/actions

# Discord 알림 테스트
# GitHub Actions에서 수동 트리거로 알림 테스트

# CloudFront 캐시 무효화
aws cloudfront create-invalidation --distribution-id XXXXXX --paths "/*"

# Docker 네트워크 문제 해결
ansible all -m command -a "docker network ls" -i inventory/hosts.yml
ansible all -m command -a "docker network create app_mechuragi-network" -i inventory/hosts.yml
```

## 🛡️ 보안 특징

### 🔒 네트워크 보안
- **VPC 내부 통신**: DB/캐시는 10.0.0.0/16에서만 접근
- **Elastic IP**: 메인 서비스 고정 IP
- **HTTPS 강제**: CloudFront 자동 리디렉션

### 🔐 데이터 보안
- **EBS 암호화**: 모든 볼륨 AES-256 암호화
- **S3 암호화**: 서버 측 암호화 + 버전 관리
- **CloudFront OAC**: S3 직접 접근 차단

### 🔑 접근 보안
- **SSH 키 인증**: 모든 서버 키 페어 기반
- **IAM 최소 권한**: 서비스별 필요 권한만
- **민감 정보 분리**: Git에서 완전 제외

## 📚 문서 링크

- **[Terraform 상세 가이드](terraform/README.md)**: 인프라 모듈별 설정
- **[Ansible 실행 가이드](ansible/README.md)**: 서버 설정 단계별 실행
- **AWS 서비스 설정**: CloudFront, SES, Bedrock 연동 방법

## 💡 주요 특징

- ✅ **분산 마이크로서비스**: 4개 독립 서비스
- ✅ **React + Spring Boot**: 현대적 풀스택 아키텍처
- ✅ **Blue-Green 배포**: 무중단 서비스 업데이트
- ✅ **CI/CD 파이프라인**: GitHub Actions 자동 배포
- ✅ **Docker 컨테이너화**: 멀티플랫폼 지원
- ✅ **실시간 알림**: Discord 배포 상태 모니터링
- ✅ **비용 최적화**: 75% EC2 비용 절감
- ✅ **보안 중심**: 4계층 네트워크 보안
- ✅ **CDN 최적화**: 3-Origin CloudFront
- ✅ **AI 통합**: AWS Bedrock 연동
- ✅ **자동화**: IaC + Configuration Management
- ✅ **확장 가능**: 모듈화된 아키텍처

---

## 🆕 최신 업데이트 (v2.0)

### ✨ 새로운 기능
- **🔄 Blue-Green 배포**: 메인 서비스 무중단 업데이트
- **🤖 GitHub Actions CI/CD**: 자동 빌드, 테스트, 배포
- **🐳 Docker 컨테이너화**: 멀티플랫폼 이미지 빌드 (ARM64/AMD64)
- **💬 Discord 알림**: 실시간 배포 상태 모니터링
- **🎯 AI 서비스 분리**: 독립적인 추천 서비스 (Port 8082)
- **🔀 포트 최적화**: 서비스 간 포트 충돌 해결

### 🔧 주요 개선사항
- **메인 서비스**: Blue-Green 배포로 무중단 서비스
- **AI 서비스**: 8081 → 8082 포트 변경으로 충돌 해결
- **Nginx 설정**: Blue-Green 전환을 위한 동적 업스트림 구성
- **Docker 네트워크**: `app_mechuragi-network`로 서비스 간 통신
- **멀티플랫폼 빌드**: GitHub Actions에서 ARM64/AMD64 동시 지원

---

**🎯 이 인프라는 메추라기 프로젝트의 완전한 분산 마이크로서비스 환경을 제공하며, 개발부터 운영까지 모든 단계를 지원합니다.**