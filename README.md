# Mechuragi Infrastructure

메추라기 프로젝트의 **통합 마이크로서비스 아키텍처**를 구현하는 AWS 인프라 저장소입니다. Terraform과 Ansible을 사용하여 React 프론트엔드와 Spring Boot 백엔드의 최적화된 배포 환경을 제공합니다.

## 🏗️ 아키텍처 개요

### 통합 서비스 구조 (3개 인스턴스 + React CDN + CI/CD)
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
            ┌──────────▼──┐  ┌──▼─────┐  ┌▼────────────────┐
            │  S3 (React) │  │S3 (Img)│  │ Nginx Gateway   │
            │  정적 파일   │  │이미지   │  │ Public Subnet   │
            └─────────────┘  └────────┘  │ :80, :443       │
                                          │ Reverse Proxy   │
                                          │ + Bastion + NAT │
                                          └─┬──────────┬────┘
                                            │          │
                         ┌──────────────────┘          └──────────────────┐
                         │ Private Subnet (VPC 내부)                      │
              ┌──────────▼──────────┐                  ┌─────────▼────────┐
              │  통합 메인 서버      │                  │  AI 추천 서버    │
              │  t3.medium          │◄─────MySQL───────│  t3.small        │
              │  ┌────────────────┐ │                  │  :8082           │
              │  │ MySQL :3306    │ │                  │  + Bedrock       │
              │  │ Redis :6379    │ │                  │  AI Gateway      │
              │  │ API   :8080    │ │                  └──────────────────┘
              │  └────────────────┘ │
              │  Docker Compose     │
              └─────────────────────┘
```

### 네트워크 보안 설계
- **Public Subnet** : Nginx Gateway만 배치 (외부 접근 가능)
- **Private Subnet** : 통합 메인 서버, AI 서버 배치 (외부 접근 불가)
- **보안 그룹 3계층**: 최소 권한 원칙
  - **Level 1**: Nginx Gateway → 인터넷 전체 허용 (80, 443, SSH)
  - **Level 2**: 통합 메인 서버 → Nginx에서만 허용, AI 서버에서 MySQL 접근
  - **Level 3**: AI 서버 → Nginx에서만 허용

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
│       ├── vpc/                        # Public + Private 서브넷 네트워크
│       ├── security/                   # 3계층 보안 그룹
│       ├── compute/                    # 3개 통합 인스턴스
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
    │   └── hosts.yml                   # 3개 서버 인벤토리
    └── playbooks/                      # 🎮 실행 플레이북 (단순화)
        ├── site.yml                    # 🚀 메인 오케스트레이션 (전체 실행)
        ├── common.yml                  # 🔧 공통 시스템 설정
        ├── docker.yml                  # 🐳 Docker 설치
        └── nginx-gateway.yml           # 🌐 Nginx Gateway + NAT 설정
```

## 🏛️ 인프라 구성

### AWS 핵심 리소스

#### 🌐 네트워크 (VPC 모듈)
- **VPC**: CIDR 블록
- **Public Subnet**:  (Nginx Gateway 배치)
- **Private Subnet**:  (통합 메인 서버, AI 서버 배치)
- **Internet Gateway**: Public Subnet 인터넷 연결
- **NAT Instance**: Nginx가 NAT 역할 (Private Subnet 아웃바운드)
- **🔥 NAT Gateway 제거**: 월 $40-50 비용 절감

#### 💻 컴퓨팅 (Compute 모듈)
- **통합 메인 서버**: t3.medium (Private Subnet, MySQL+Redis+API 통합)
  - Docker Compose로 통합 관리
  - 동일 호스트 내 localhost 통신
  - Private IP만 할당 (Public IP 없음)
- **AI 서버**: t3.small (Private Subnet, Bedrock IAM Profile)
  - AI 게이트웨이 역할
  - MySQL 직접 접근 (사용자 정보 조회)
  - Private IP만 할당 (Public IP 없음)
- **Nginx Gateway**: t3.micro (Public Subnet, Public IP + Elastic IP)
  - 리버스 프록시 + Bastion + NAT
  - CloudFront → Nginx → Backend 라우팅
  - SSH 게이트웨이 (모든 서버 접근)
- **🔥 90% 비용 절감**: Elastic IP 1개, 리소스 통합, NAT Gateway 제거

#### 🛡️ 보안 (Security 모듈)
- **Nginx Gateway SG**:
  - HTTP(80), HTTPS(443): 인터넷 전체 허용 (CloudFront)
  - SSH(22): 관리자 IP만 허용
  - 아웃바운드: VPC 내부 + 인터넷 (NAT 기능)
- **통합 메인 서버 SG**:
  - HTTP(80), HTTPS(443): Nginx에서만 허용 (VPC 내부)
  - SSH(22): Nginx에서만 허용 (Bastion)
  - Spring(8080): Nginx에서만 허용
  - MySQL(3306): AI 서버에서 허용 (VPC 내부)
  - Redis(6379): 컨테이너 간 localhost 통신
- **AI 서버 SG**:
  - Spring(8082): Nginx에서만 허용 (VPC 내부)
  - SSH(22): Nginx에서만 허용 (Bastion)
  - 아웃바운드: MySQL 접근, Bedrock API 호출

#### 🗄️ 스토리지 (S3 모듈)
- **Frontend Bucket**: `mechuragi-dev-frontend` (React SPA)
- **Images Bucket**: `mechuragi-dev-images` (이미지 저장)
- **암호화**: AES-256 서버 측 암호화
- **보안**: CloudFront OAC를 통해서만 접근 허용

#### 🌍 CDN (CloudFront 모듈)
- **3-Origin 구조**:
  - Frontend Origin: React 정적 파일 (S3 + OAC)
  - Images Origin: 이미지 파일 (S3 + OAC)
  - API Origin: Nginx Gateway (Public IP)
    - `/api/*` → 통합 메인 서버 :8080
    - `/recommend/*` → AI 서버 :8082
- **커스텀 도메인**: `mechuragi.kro.kr` (ACM SSL 인증서)
- **캐시 정책**: 용도별 차별화된 TTL 설정
  - React 파일: 1일 (최대 1년)
  - 이미지: 1주일 (최대 1년)
  - API: 캐싱 비활성화 (실시간 데이터)
  - AI 추천: 캐싱 비활성화 (개인화된 응답)
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

#### 🐳 통합 메인 서버 (Docker Compose)
- **Docker Compose**: MySQL + Redis + API 통합 관리
- **MySQL 8.0 컨테이너**: 데이터베이스 서비스
  - 볼륨 마운트로 데이터 영속성 확보
  - VPC 내부 통신 (AI 서버 접근 허용)
- **Redis 6 컨테이너**: 캐싱 레이어
  - localhost 통신으로 네트워크 레이턴시 최소화
- **API 컨테이너**: Spring Boot 메인 서비스
  - localhost로 MySQL/Redis 접근
  - Blue-Green 배포 지원
- **Multi-platform 빌드**: ARM64/AMD64 지원

#### 🌐 Nginx Gateway 설정
- **포트 80/443**: CloudFront에서 들어오는 요청 처리
- **리버스 프록시 라우팅**:
  - `/api/*` → 통합 메인 서버 (Private IP:8080)
  - `/ai/*` 또는 `/recommend/*` → AI 서버 (Private IP:8082)
  - `/actuator/*` → 헬스체크 (VPC 내부만)
  - `/` → 404 (프론트엔드는 CloudFront/S3에서 제공)
- **Bastion Host**: 모든 Private 서버로의 SSH 터널링
- **NAT Instance**: Private Subnet 아웃바운드 트래픽 중계
  - IP forwarding 활성화 (sysctl net.ipv4.ip_forward=1)
  - iptables MASQUERADE 규칙
- **Blue-Green 지원**: 동적 업스트림 전환 (8080 ↔ 8081)

#### ⚙️ 시스템 도구
- **개발 도구**: git, curl, wget, vim, htop
- **모니터링**: htop, docker stats
- **네트워크**: UFW 방화벽 (기본 비활성화)

## 🚀 배포 가이드

### 🔄 CI/CD 파이프라인

#### GitHub Actions 자동 배포

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


### ⚙️ 2단계: Ansible 서버 설정

```bash
cd ansible

# 1. 인벤토리 파일 설정
vi inventory/hosts.yml
# Terraform 출력의 IP 주소들을 입력

# 2. 변수 파일 설정
vi group_vars/all/main.yml
# 필요한 변수들 설정 (MySQL, Redis, Docker 이미지 등)

# 3. 전체 인프라 배포 (한 번에 실행)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# site.yml 실행 내용:
# - common.yml: 모든 서버에 기본 패키지, AWS CLI, 디렉토리 생성
# - docker.yml: 모든 서버에 Docker 설치
# - nginx-gateway.yml: Nginx Gateway에 Nginx + NAT 설정

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

### 🌐 서비스 URL
- **React 앱**: `https://mechuragi.kro.kr/` (CloudFront 커스텀 도메인)
- **API 엔드포인트**: `https://mechuragi.kro.kr/api/` (CloudFront → Nginx → 통합 메인 서버)
- **AI 추천 엔드포인트**:  `https://mechuragi.kro.kr/recommend/` (CloudFront → Nginx → AI 서버)
- **이미지 CDN**: `https://mechuragi.kro.kr/images/`
- **CloudFront 기본 도메인**: `https://XXXXXX.cloudfront.net/`
- **Nginx Gateway 직접**: `http://XXX.XXX.XXX.XXX/`

### 📈 성능 & 비용
- **EC2 비용**: 월 $35-40 (1개 t3.medium + 1개 t3.small + 1개 t3.micro)
- **네트워크 비용**:
  - NAT Gateway 제거: 월 $40-50 절감
  - Elastic IP 감축: 월 $9 절감 (4개 → 1개)
- **총 비용 절감**: 월 $50-60 절감 (기존 대비 약 60% 감소)
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
- **Private Subnet 격리**: 통합 메인 서버, AI 서버는 외부 직접 접근 불가
- **Public IP 최소화**: Nginx Gateway만 Public IP 보유 (Elastic IP 1개)
- **Bastion Host**: Nginx Gateway를 통해서만 Private 서버 SSH 접근
- **보안 그룹 3계층**: 최소 권한 원칙
  - Nginx Gateway: 인터넷 허용 (80, 443, SSH)
  - 통합 메인 서버: Nginx에서만 허용 + AI에서 MySQL 접근
  - AI 서버: Nginx에서만 허용
- **Nginx Reverse Proxy**: CloudFront → Nginx → Private Backend
- **NAT Instance**: Private Subnet 아웃바운드만 허용 (인바운드 차단)
- **HTTPS 강제**: CloudFront 자동 리디렉션 + ACM SSL 인증서

### 🔐 데이터 보안
- **EBS 암호화**: 모든 볼륨 AES-256 암호화
- **S3 암호화**: 서버 측 암호화 + 버전 관리
- **CloudFront OAC**: S3 직접 접근 차단
- **TLS 1.2**: CloudFront 최소 프로토콜 버전
- **MySQL 컨테이너**: 볼륨 마운트로 데이터 영속성 + 백업

### 🔑 접근 보안
- **SSH 키 인증**: 모든 서버 키 페어 기반
- **SSH 터널링**: Private 서버는 Nginx를 통해서만 접근 (ProxyCommand)
- **IAM 최소 권한**: 서비스별 필요 권한만
  - 통합 메인 서버: SES 전송 권한
  - AI Service: Bedrock 접근 권한
  - Nginx Gateway: NAT 기능
- **민감 정보 분리**: Git에서 완전 제외 (.gitignore)
- **Actuator 보안**: VPC 내부에서만 접근
- **단일 진입점**: 모든 외부 트래픽은 Nginx Gateway를 통해서만 유입

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
┌─────────────────────────────────────────────────────┐
│         AWS VPC                    │
│                                                     │
│  ┌────────────────────────┐ Public Subnet          │
│  │  Nginx Gateway         │        │
│  │  - Public IP ✓         │ ◄─── SSH 게이트웨이    │
│  │  - Elastic IP ✓        │ ◄─── NAT Instance     │
│  │  - Bastion Host        │ ◄─── Reverse Proxy    │
│  └────────┬───────────────┘                        │
│           │ SSH Tunnel (ProxyCommand)              │
│           │                                         │
│  ┌────────┴─────────────────────────────────────┐  │
│  │     Private Subnet          │  │
│  │                                              │  │
│  │  ┌──────────────────┐  ┌──────────────────┐ │  │
│  │  │ 통합 메인 서버    │  │  AI 서버         │ │  │
│  │  │ - Private IP ✓   │  │ - Private IP ✓   │ │  │
│  │  │ ┌──────────────┐ │  │ :8082            │ │  │
│  │  │ │ MySQL :3306  │◄┼──┤ + Bedrock        │ │  │
│  │  │ │ Redis :6379  │ │  └──────────────────┘ │  │
│  │  │ │ API   :8080  │ │                       │  │
│  │  │ └──────────────┘ │  외부 직접 접근 불가   │  │
│  │  │ Docker Compose   │                       │  │
│  │  └──────────────────┘                       │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 📊 연결 흐름

#### SSH 터널링
```
개발자 PC
    ↓ SSH (22)
Nginx Gateway (Public IP)
    ↓ ProxyCommand (%h:%p)
통합 메인 서버 또는 AI 서버 
    ↓
✅ Private 서버 작업 가능
```

#### MySQL Workbench 연결
```
MySQL Workbench
    ↓
[SSH 터널] 개발자 PC → Nginx Gateway (Public IP:22)
    ↓
[ProxyCommand] Nginx → 통합 메인 서버 
    ↓
[MySQL 연결] 통합 메인 서버 내부 → MySQL Container (localhost:3306)
    ↓
✅ DB 작업 가능
```

### 🔐 보안 계층 구조

#### Level 1 Public Subnet - 
- **Nginx Gateway**: 외부 접근 가능 (Elastic IP)
- 역할: Bastion Host + NAT Instance + Reverse Proxy

#### Level 2 Private Subnet - 
- **통합 메인 서버**: Private IP만 
  - MySQL, Redis, API 통합
  - Docker Compose 관리
- **AI 서버**: Private IP만 
  - Bedrock + AI Gateway
- 외부 직접 접근 불가
- Nginx Gateway 경유만 가능

### 🎯 핵심 포인트
```
✅ DB/Redis는 외부 노출 안 됨 (Private Subnet + 컨테이너)
✅ Nginx Gateway가 단일 진입점 (Bastion Host)
✅ 관리자 IP만 SSH 접근 가능 (보안 그룹)
✅ Private 서버는 Public IP 없음 (비용 절감)
✅ NAT Instance로 아웃바운드만 허용 (보안 강화)
```

### 🛠️ MySQL Workbench 설정
**SSH 터널 설정:**
```
SSH Hostname: Nginx Gateway Public IP 
SSH Username: ubuntu
SSH Key: /path/to/mechuragi-dev-key.pem
MySQL Hostname: 통합 메인 서버 Private IP 
MySQL Port: 3306
MySQL Username: mechuragi_user
```

**Security Group:**
```
Nginx Gateway Inbound: 관리자IP → 22
통합 메인 서버 Inbound:
  - Nginx에서만 → 22, 80, 443, 8080
  - AI 서버에서만 → 3306
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

- ✅ **통합 마이크로서비스**: 3개 인스턴스 통합 구조 (비용 최적화)
- ✅ **React + Spring Boot**: 현대적 풀스택 아키텍처
- ✅ **CloudFront CDN**: 커스텀 도메인 + HTTPS (mechuragi.kro.kr)
- ✅ **Nginx Gateway**: 리버스 프록시 + Bastion + NAT (3-in-1)
- ✅ **Private Subnet 격리**: 통합 메인 서버, AI 서버 외부 접근 차단
- ✅ **Docker Compose 통합**: MySQL + Redis + API 동일 호스트 관리
- ✅ **Blue-Green 배포**: 무중단 서비스 업데이트
- ✅ **CI/CD 파이프라인**: GitHub Actions 자동 배포
- ✅ **AI 통신 개선**: AI 서버가 메인 서버 우회 (30-40% 속도 향상)
- ✅ **실시간 알림**: Discord 배포 상태 모니터링
- ✅ **비용 최적화**: 60% 인프라 비용 절감 (NAT Gateway 제거 + Elastic IP 1개)
- ✅ **보안 강화**: 3계층 보안 + Bastion Host + Public IP 최소화
- ✅ **CDN 최적화**: 3-Origin CloudFront (React/Images/API/AI)
- ✅ **AI 통합**: AWS Bedrock 연동 + AI Gateway
- ✅ **자동화**: IaC + Configuration Management
- ✅ **검증 강화**: Ansible 자동 검증 (MySQL/Redis/Nginx)
- ✅ **확장 가능**: 모듈화된 아키텍처

---

## 🆕 최신 업데이트

### ✨ v3.0 - 통합 인프라 리팩토링 (현재)

**🏗️ 아키텍처 대개편: 4개 → 3개 인스턴스**

- **통합 메인 서버** (신규): MySQL + Redis + API를 Docker Compose로 통합
  - 인스턴스 타입: t3.medium
  - Private Subnet 배치 (외부 직접 접근 불가)
  - 동일 호스트 내 localhost 통신으로 네트워크 레이턴시 최소화

- **Nginx Gateway** (신규): 리버스 프록시 + Bastion + NAT 3-in-1
  - 인스턴스 타입: t3.micro
  - Public Subnet 배치 (유일한 Public IP)
  - CloudFront → Nginx → Private Backend 라우팅
  - SSH 게이트웨이 (모든 Private 서버 접근)
  - NAT Instance (Private Subnet 아웃바운드)

- **AI 서버 통신 개선**: 메인 서버 우회로 30-40% 속도 향상
  - Before: Frontend → Main → AI → Main → Frontend (5단계)
  - After: Frontend → Nginx → AI → Frontend (4단계)
  - AI 서버가 MySQL에 직접 접근하여 사용자 정보 조회

**💰 비용 절감 (60% 감소)**
- NAT Gateway 제거: 월 $40-50 절감
- Elastic IP 감축: 월 $9 절감 (4개 → 1개)
- 리소스 통합: MySQL/Redis 독립 인스턴스 제거

**🔒 보안 강화**
- Private Subnet 격리: 통합 메인 서버, AI 서버 외부 접근 차단
- Bastion Host: Nginx를 통해서만 Private 서버 SSH 접근
- Public IP 최소화: Elastic IP 1개만 사용
- 보안 그룹 3계층: 최소 권한 원칙

**📈 성능 향상**
- 네트워크 레이턴시 감소: MySQL/Redis와 API가 localhost 통신
- 캐시 효율성 증가: Redis와 API 간 네트워크 홉 제거
- AI 추천 속도 개선: 메인 서버 중계 단계 제거

---

### ✨ v2.2 - Ansible 구조 개편

- **📁 Playbook 분리**: Setup/Test Playbook 관심사 분리
- **✅ 독립적인 테스트**: test-db.yml, test-redis.yml, test-docker.yml
- **🔧 Setup 단순화**: 설치/구성에만 집중
- **📊 상세 검증**: 4단계 MySQL 검증, 6단계 Redis 검증
- **🔐 SSH 터널링 가이드**: MySQL Workbench 설정 문서화

---

### ✨ v2.1 - CloudFront 커스텀 도메인

- **🌐 커스텀 도메인**: `mechuragi.kro.kr` HTTPS 지원
- **🔒 ACM SSL 인증서**: TLS 1.2 암호화 통신
- **🔄 Nginx Reverse Proxy**: CloudFront → Nginx → Spring Boot
- **📊 Ansible 검증 강화**: MySQL/Redis 설치 후 자동 검증

---

### ✨ v2.0 - CI/CD 및 Blue-Green 배포

- **🔄 Blue-Green 배포**: 무중단 서비스 업데이트
- **🤖 GitHub Actions CI/CD**: 자동 빌드, 테스트, 배포
- **🐳 Docker 컨테이너화**: 멀티플랫폼 이미지 빌드
- **💬 Discord 알림**: 실시간 배포 상태 모니터링
- **🎯 AI 서비스 분리**: 독립적인 추천 서비스

---
