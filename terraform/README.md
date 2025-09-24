# Terraform 인프라 구성 가이드

## 📋 개요

메추라기 프로젝트의 AWS 인프라를 Terraform으로 관리하는 IaC(Infrastructure as Code) 구성입니다. **분산 마이크로서비스 아키텍처**로 설계되어 확장성과 유지보수성을 높였습니다.

## 🏗️ 아키텍처 개요

### 분산 서비스 구조 (4개 인스턴스)
- **메인 서비스** (Public): Spring Boot + SES + CloudFront → 사용자 인터페이스
- **AI 추천 서비스** (Private): Spring Boot + Bedrock → 머신러닝 처리
- **데이터베이스** (Private): MySQL → 데이터 영속성
- **캐시 서버** (Private): Redis → 성능 최적화

### React 프론트엔드 배포 환경
- **프론트엔드 S3**: React SPA 호스팅
- **이미지 S3**: 이미지 파일 저장
- **CloudFront CDN**: 3-Origin 구조 (Frontend + Images + API)

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
    ├── vpc/                     # VPC 및 네트워킹 (Public 서브넷 전용)
    ├── security/                # 보안 그룹 (4계층 보안 설계)
    ├── compute/                 # EC2 인스턴스 (분산 서비스)
    ├── s3/                      # S3 스토리지 (Frontend + Images)
    ├── cloudfront/              # CloudFront CDN (3-Origin)
    ├── ses/                     # 이메일 서비스
    │   └── templates/           # 이메일 템플릿
    └── bedrock/                 # AI 서비스 (Bedrock 연동)
```

## 🏗️ 인프라 구성 요소

### 1. **VPC 모듈** - 단순화된 네트워크
- **목적**: 비용 최적화된 Public 서브넷 구조
- **포함 리소스**:
  - VPC (10.0.0.0/16)
  - Public Subnet (10.0.2.0/24) - 모든 인스턴스 배치
  - Internet Gateway
  - Route Tables
- **🔥 변경사항**: NAT Gateway 제거로 비용 절감

### 2. **Security 모듈** - 4계층 보안 설계
- **목적**: 서비스별 차별화된 보안 그룹 관리
- **보안 계층**:
  - **Level 1**: Main Service (공개) - HTTP/HTTPS/SSH 전체 허용
  - **Level 2**: AI/MySQL/Redis (VPC 내부) - 10.0.0.0/16만 허용
- **포함 리소스**:
  - Main Service 보안 그룹 (80, 443, 8080, 22 포트)
  - AI Service 보안 그룹 (8081, 22 포트 - VPC 내부만)
  - MySQL 보안 그룹 (3306, 22 포트 - VPC 내부만)
  - Redis 보안 그룹 (6379, 22 포트 - VPC 내부만)

### 3. **Compute 모듈** - 분산 마이크로서비스
- **목적**: 4개 서비스 분산 구성으로 확장성 확보
- **포함 리소스**:
  - **Main Service** (Public, t3.micro) - 프리티어 + Elastic IP
  - **AI Service** (Public, t3.small) - Bedrock IAM Profile 연결
  - **MySQL Server** (Public, t3.micro) - 가변 볼륨 지원
  - **Redis Server** (Public, t3.micro) - 캐시 전용
- **🔥 변경사항**: 모든 인스턴스가 Public IP를 가지되, 보안 그룹으로 접근 제어

### 4. **S3 모듈** - 프론트엔드 + 이미지 분리
- **목적**: React 프론트엔드 배포와 이미지 저장 분리
- **포함 리소스**:
  - **Frontend Bucket**: `mechuragi-dev-frontend` (React SPA 호스팅)
  - **Images Bucket**: `mechuragi-dev-images` (이미지 파일 저장)
  - 버킷별 개별 암호화, 버전 관리, CORS 설정
  - 퍼블릭 액세스 완전 차단 (CloudFront OAC만 허용)

### 5. **CloudFront 모듈** - 3-Origin CDN
- **목적**: React SPA + 이미지 CDN + API 프록시
- **3-Origin 구조**:
  - **Frontend Origin**: React 정적 파일 (S3)
  - **Images Origin**: 이미지 파일 (S3)
  - **API Origin**: Spring Boot API (EC2:8080)
- **캐시 정책**:
  - React 파일: 1일~1년 캐시
  - 이미지 파일: 1일~1년 장기 캐시
  - API 응답: 캐시 비활성화
- **보안**: 각 S3 버킷별 개별 OAC 설정

### 6. **SES 모듈** - 이메일 서비스
- **목적**: 다국어 이메일 발송 시스템
- **포함 리소스**:
  - SES 도메인 검증 (`mechuragi.kro.kr`)
  - DKIM 설정 (이메일 인증)
  - **이메일 템플릿**:
    - 환영 이메일 (이모지 + HTML 템플릿)
    - 비밀번호 재설정 (보안 가이드 포함)
  - Configuration Set (모니터링)
  - IAM 역할 및 Instance Profile

### 7. **Bedrock 모듈** - AI 서비스 연동
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

1. **VPC 모듈** → Public 서브넷 기반 네트워크
2. **Security 모듈** → 4계층 보안 그룹
3. **Bedrock 모듈** → AI 서비스 IAM 설정
4. **Compute 모듈** → 4개 분산 서비스 인스턴스
5. **S3 모듈** → Frontend + Images 버킷 생성
6. **CloudFront 모듈** → 3-Origin CDN 구성
7. **SES 모듈** → 이메일 서비스 설정


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
  - Main/MySQL/Redis: t3.micro (프리티어, **75% 비용 절감**)
  - AI Service: t3.small (성능 확보)
- **네트워크**: NAT Gateway 제거로 **월 $45 절감**
- **스토리지**: gp3 볼륨 + 버전 관리

### 운영 환경 권장사항
```bash
# 성능 확장 예시
terraform apply \
  -var="main_service_instance_type=t3.medium" \
  -var="ai_service_instance_type=c5.large" \
  -var="mysql_volume_size=100"
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

**🎯 이 인프라는 메추라기 프로젝트의 분산 마이크로서비스 아키텍처를 완벽하게 지원하며, React 프론트엔드와 Spring Boot 백엔드의 최적화된 배포 환경을 제공합니다.**