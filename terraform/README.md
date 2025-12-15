# Terraform 인프라 구성 가이드

## 📋 개요

메추라기 프로젝트의 AWS 인프라를 Terraform으로 관리하는 IaC(Infrastructure as Code) 구성입니다. **통합 마이크로서비스 아키텍처**로 설계되어 비용 최적화와 보안 강화를 동시에 달성합니다.

## 🏗️ 아키텍처 개요

### 통합 서비스 구조 (3개 인스턴스)
- **통합 메인 서버** (Private): MySQL + Redis + API를 Docker Compose로 통합
  - Private Subnet 배치 (외부 직접 접근 불가)
  - 동일 호스트 내 localhost 통신
- **AI 서버** (Private): Spring Boot + Bedrock → AI 게이트웨이 역할
  - MySQL 직접 접근 (사용자 정보 조회)
  - 메인 서버 우회로 응답 속도 30-40% 향상
- **Nginx Gateway** (Public): 리버스 프록시 + Bastion + NAT
  - Public Subnet 배치 (유일한 Public IP)
  - CloudFront → Nginx → Private Backend 라우팅

### React 프론트엔드 배포 환경
- **프론트엔드 S3**: React SPA 호스팅
- **이미지 S3**: 이미지 파일 저장
- **CloudFront CDN**: 3-Origin 구조 (Frontend + Images + API/AI)

## 📁 디렉토리 구조

```
terraform/
├── README.md                    # 이 가이드 파일
├── environments/                # 🌍 환경별 설정 (통합 구조)
│   └── dev/                     # 🛠️ 개발 환경
│       ├── main.tf              # 메인 구성 파일
│       ├── variables.tf         # 입력 변수 정의
│       ├── outputs.tf           # 출력 값 정의
│       └── terraform.tfvars     # 실제 변수 값
└── modules/                     # 📦 재사용 가능한 모듈들
    ├── vpc/                     # VPC 및 네트워킹 (Public + Private 서브넷)
    ├── security/                # 보안 그룹 (3계층 보안 설계)
    ├── compute/                 # EC2 인스턴스 (3개 통합 인스턴스)
    ├── s3/                      # S3 스토리지 (Frontend + Images)
    ├── cloudfront/              # CloudFront CDN (3-Origin)
    ├── acm-certificate/         # ACM SSL/TLS 인증서 (us-east-1)
    ├── ses/                     # 이메일 서비스
    │   └── templates/           # 이메일 템플릿
    └── bedrock/                 # AI 서비스 (Bedrock 연동)
```

## 🏗️ 인프라 구성 요소

### 1. **VPC 모듈** - Public + Private 서브넷
- **목적**: 보안 강화 및 비용 최적화
- **포함 리소스**:
  - VPC (10.0.0.0/16)
  - Public Subnet (10.0.1.0/24) - Nginx Gateway 배치
  - Private Subnet (10.0.2.0/24) - 통합 메인 서버, AI 서버 배치
  - Internet Gateway - Public Subnet 인터넷 연결
  - Route Tables
    - Public: 0.0.0.0/0 → Internet Gateway
    - Private: 0.0.0.0/0 → Nginx ENI (NAT Instance)
- **🔥 변경사항**: NAT Gateway 제거 → Nginx가 NAT 역할 (월 $40-50 절감)

### 2. **Security 모듈** - 3계층 보안 설계
- **목적**: 최소 권한 원칙 기반 보안 그룹 관리
- **보안 계층**:
  - **Level 1**: Nginx Gateway (Public) - 인터넷 전체 허용
  - **Level 2**: 통합 메인 서버 (Private) - Nginx + AI에서만 허용
  - **Level 3**: AI 서버 (Private) - Nginx에서만 허용
- **포함 리소스**:
  - Nginx Gateway 보안 그룹
    - Inbound: HTTP(80), HTTPS(443), SSH(22) - 인터넷 허용
    - Outbound: 모든 트래픽 허용 (NAT 기능)
  - 통합 메인 서버 보안 그룹
    - Inbound: HTTP(80), HTTPS(443), SSH(22), Spring(8080) - Nginx에서만
    - Inbound: MySQL(3306) - AI 서버에서만
    - Outbound: 모든 트래픽 허용
  - AI 서버 보안 그룹
    - Inbound: Spring(8082), SSH(22) - Nginx에서만
    - Outbound: 모든 트래픽 허용 (MySQL 접근, Bedrock API)

### 3. **Compute 모듈** - 통합 마이크로서비스
- **목적**: 리소스 통합으로 비용 절감 및 성능 향상
- **포함 리소스**:
  - **통합 메인 서버** (Private Subnet, t3.medium)
    - MySQL + Redis + API를 Docker Compose로 통합
    - Private IP만 할당 (Public IP 없음)
    - SES IAM Profile 연결
  - **AI 서버** (Private Subnet, t3.small)
    - Bedrock IAM Profile 연결
    - MySQL 직접 접근 (사용자 정보 조회)
    - Private IP만 할당 (Public IP 없음)
  - **Nginx Gateway** (Public Subnet, t3.micro)
    - Public IP + Elastic IP 할당 (유일한 외부 접근점)
    - Source/Destination Check 비활성화 (NAT 동작)
    - 리버스 프록시 + Bastion Host + NAT Instance
- **🔥 변경사항**: 4개 → 3개 인스턴스, Elastic IP 4개 → 1개 (월 $50-60 절감)

### 4. **S3 모듈** - 프론트엔드 + 이미지 분리
- **목적**: React 프론트엔드 배포와 이미지 저장 분리
- **포함 리소스**:
  - **Frontend Bucket**: `mechuragi-dev-frontend` (React SPA 호스팅)
  - **Images Bucket**: `mechuragi-dev-images` (이미지 파일 저장)
  - 버킷별 개별 암호화, 버전 관리, CORS 설정
  - 퍼블릭 액세스 완전 차단 (CloudFront OAC만 허용)

### 5. **CloudFront 모듈** - 3-Origin CDN
- **목적**: React SPA + 이미지 CDN + API/AI 프록시
- **3-Origin 구조**:
  - **Frontend Origin**: React 정적 파일 (S3)
  - **Images Origin**: 이미지 파일 (S3)
  - **API Origin**: Nginx Gateway (Public IP)
    - `/api/*` → 통합 메인 서버 :8080
    - `/recommend/*` → AI 서버 :8082
    - `/login/*`, `/swagger-ui/*` → 통합 메인 서버 :8080
- **캐시 정책**:
  - React 파일: 1일~1년 캐시
  - 이미지 파일: 1일~1년 장기 캐시
  - API 응답: 캐시 비활성화
  - AI 추천: 캐시 비활성화 (개인화된 응답)
- **보안**: 각 S3 버킷별 개별 OAC 설정

### 6. **ACM Certificate 모듈** - SSL/TLS 인증서
- **목적**: CloudFront용 HTTPS 인증서 제공
- **포함 리소스**:
  - ACM 인증서 (us-east-1 리전 - CloudFront 필수)
  - DNS 검증 레코드 (Route53 또는 외부 DNS)
  - 도메인 검증 대기 옵션
- **도메인**: 커스텀 도메인 설정 가능
- **자동 갱신**: AWS ACM 자동 갱신 지원

### 7. **SES 모듈** - 이메일 서비스
- **목적**: 다국어 이메일 발송 시스템
- **포함 리소스**:
  - SES 도메인 검증 (`mechuragi.kro.kr`)
  - DKIM 설정 (이메일 인증)
  - **이메일 템플릿**:
    - 환영 이메일 (이모지 + HTML 템플릿)
    - 비밀번호 재설정 (보안 가이드 포함)
  - Configuration Set (모니터링)
  - IAM 역할 및 Instance Profile

### 8. **Bedrock 모듈** - AI 서비스 연동
- **목적**: AWS Bedrock을 통한 AI 추천 시스템
- **포함 리소스**:
  - IAM 역할 및 정책 (Bedrock 전체 권한)
  - CloudWatch 로그 그룹 (14일 보존)
  - SSM Parameter Store (모델 ID 관리)
  - Instance Profile (AI 서비스 연결)

## 🚀 사용 방법

### 📝 사전 준비

1. **AWS CLI 설정 + 관리자 권한**
   ```bash
   aws configure
   # AdministratorAccess 권한 필요 (모든 AWS 서비스 접근)
   ```

2. **Terraform 설치 확인**
   ```bash
   terraform version
   # Terraform v1.0 이상 필요
   ```

3. **SSH 키 페어 생성**
   ```bash
   # AWS 콘솔에서 mechuragi-dev-key 키페어 생성
   # ~/.ssh/mechuragi-dev-key.pem 저장 및 권한 설정
   chmod 400 ~/.ssh/mechuragi-dev-key.pem
   ```

### 🎯 배포 단계

#### 1단계: 환경 설정
```bash
cd terraform/environments/dev
```

#### 2단계: Terraform 초기화
```bash
terraform init
```

#### 3단계: 배포 계획 확인
```bash
terraform plan
```

#### 4단계: 전체 인프라 배포
```bash
terraform apply
```

### 📋 모듈 실행 순서 (자동)

1. **VPC 모듈** → Public + Private 서브넷 네트워크
2. **Security 모듈** → 3계층 보안 그룹
3. **Bedrock 모듈** → AI 서비스 IAM 설정
4. **Compute 모듈** → 3개 통합 인스턴스
   - Nginx Gateway (Public Subnet, t3.micro)
   - 통합 메인 서버 (Private Subnet, t3.medium)
   - AI 서버 (Private Subnet, t3.small)
5. **S3 모듈** → Frontend + Images 버킷 생성
6. **ACM Certificate 모듈** → CloudFront용 SSL/TLS 인증서 (us-east-1)
7. **CloudFront 모듈** → 3-Origin CDN 구성 (Nginx 포함)
8. **SES 모듈** → 이메일 서비스 설정


## 🎨 React 프론트엔드 배포

### CloudFront 3-Origin 구조 활용

```bash
# 1. React 앱 빌드
npm run build

# 2. 프론트엔드 S3에 업로드
aws s3 sync ./build s3://mechuragi-dev-frontend --delete

# 3. 이미지 파일 업로드
aws s3 sync ./images s3://mechuragi-dev-images/images/

# 4. CloudFront 캐시 무효화 (필요시)
aws cloudfront create-invalidation \
  --distribution-id XXXXXX \
  --paths "/*"
```

### 접근 경로
- **React 앱**: `https://XXXXXX.cloudfront.net/`
- **이미지**: `https://XXXXXX.cloudfront.net/images/photo.jpg`
- **API**: `https://XXXXXX.cloudfront.net/api/users`

## 🔧 고급 사용법

### 기존 리소스 Import (충돌 해결)
```bash
# IAM Role 중복 해결
terraform import module.bedrock.aws_iam_role.bedrock_role mechuragi-dev-bedrock-role

# S3 버킷 중복 해결
terraform import module.s3.aws_s3_bucket.mechuragi_images_bucket mechuragi-dev-images
```

### 인스턴스 타입 조정
```bash
# AI 서비스만 성능 향상
terraform apply -var="ai_service_instance_type=t3.medium"

# 전체 스케일업
terraform apply \
  -var="main_service_instance_type=t3.small" \
  -var="mysql_instance_type=t3.small"
```

### 특정 모듈 관리
```bash
# CloudFront만 재배포
terraform apply -target=module.cloudfront

# S3 정책만 업데이트
terraform apply -target=module.s3.aws_s3_bucket_policy
```

## 🛡️ 보안 특화 설계

### 네트워크 보안
- **Public 서브넷 + 보안 그룹**: NAT 비용 절감하면서 접근 제어
- **VPC 내부 통신**: 10.0.0.0/16 대역에서만 DB/캐시 접근
- **Elastic IP**: 메인 서비스 고정 IP로 안정성 확보

### 데이터 보안
- **S3 암호화**: AES-256 서버 측 암호화
- **CloudFront OAC**: S3 직접 접근 완전 차단
- **IAM 최소 권한**: 서비스별 필요 권한만 부여

### 접근 보안
- **SSH 키 기반**: 모든 인스턴스 키 페어 인증
- **HTTPS 강제**: CloudFront 리디렉션 정책
- **API 보안**: Authorization 헤더 전달

## 💰 비용 최적화 전략

### 현재 설정 (개발 환경)
- **EC2 인스턴스**:
  - 통합 메인 서버: t3.medium (MySQL + Redis + API 통합)
  - AI 서버: t3.small (성능 확보)
  - Nginx Gateway: t3.micro (최소 사양)
  - **월 $35-40 (기존 대비 약 60% 절감)**
- **네트워크**:
  - NAT Gateway 제거: **월 $40-50 절감**
  - Elastic IP 감축: **월 $9 절감** (4개 → 1개)
- **스토리지**: gp3 볼륨 + 버전 관리

### 총 비용 절감 효과
- **기존 비용**: 월 $90-100
- **리팩토링 후**: 월 $35-40
- **절감액**: 월 $50-60 (**약 60% 감소**)

### 운영 환경 권장사항
```bash
# 성능 확장 예시
terraform apply \
  -var="main_service_instance_type=t3.large" \
  -var="ai_service_instance_type=c5.large" \
  -var="nginx_instance_type=t3.small"
```

### 모니터링 비용
- **CloudWatch**: 14일 로그 보존
- **CloudFront**: PriceClass_100 (아시아/북미/유럽)

## 🚨 문제 해결

### 권한 오류
```bash
# AdministratorAccess 권한 확인
aws iam get-user
aws sts get-caller-identity
```

### 리소스 충돌
```bash
# 기존 리소스 확인 후 import
aws iam list-roles | grep mechuragi
terraform import module.bedrock.aws_iam_role.bedrock_role ROLE_NAME
```

### CloudFront 배포 대기
```bash
# 배포 상태 확인 (보통 10-15분 소요)
aws cloudfront get-distribution --id DISTRIBUTION_ID
```

---

**🎯 이 인프라는 메추라기 프로젝트의 통합 마이크로서비스 아키텍처를 지원하며, 비용 최적화와 보안 강화, 성능 향상을 동시에 달성합니다. React 프론트엔드와 Spring Boot 백엔드의 최적화된 배포 환경을 제공합니다.**