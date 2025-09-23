# Terraform 인프라 구성 가이드

## 📋 개요

메추라기 프로젝트의 AWS 인프라를 Terraform으로 관리하는 IaC(Infrastructure as Code) 구성입니다. 모듈화된 구조로 설계되어 재사용성과 유지보수성을 높였습니다.

## 📁 디렉토리 구조

```
terraform/
├── README.md                    # 이 가이드 파일
├── environments/                # 🌍 환경별 설정
│   └── dev/                     # 🛠️ 개발 환경
│       ├── main.tf              # 메인 구성 파일
│       ├── variables.tf         # 입력 변수 정의
│       ├── outputs.tf           # 출력 값 정의
│       └── terraform.tfvars.example  # 변수 예시 파일
└── modules/                     # 📦 재사용 가능한 모듈들
    ├── vpc/                     # VPC 및 네트워킹
    ├── security/                # 보안 그룹
    ├── compute/                 # EC2 인스턴스
    ├── s3/                      # S3 스토리지
    ├── cloudfront/              # CloudFront CDN
    ├── ses/                     # 이메일 서비스
    │   └── templates/           # 이메일 템플릿
    └── bedrock/                 # AI 서비스
```

## 🏗️ 인프라 구성 요소

### 1. **VPC 모듈** - 네트워크 기반
- **목적**: AWS VPC 및 서브넷 구성
- **포함 리소스**:
  - VPC (10.0.0.0/16)
  - Public Subnet (10.0.1.0/24)
  - Private Subnet (10.0.2.0/24)
  - Internet Gateway
  - NAT Gateway
  - Route Tables

### 2. **Security 모듈** - 보안 그룹
- **목적**: 서비스별 보안 그룹 관리
- **포함 리소스**:
  - Main Service 보안 그룹 (HTTP/HTTPS)
  - AI Service 보안 그룹 (내부 통신)
  - MySQL 보안 그룹 (3306 포트)
  - Redis 보안 그룹 (6379 포트)

### 3. **Compute 모듈** - EC2 인스턴스
- **목적**: 4개 서버 분산 구성 (비용 최적화)
- **포함 리소스**:
  - Main Service (Public, t3.micro) - 프리티어 호환
  - AI Service (Private, t3.small) - Bedrock 처리 성능 확보
  - MySQL Server (Private, t3.micro + 가변 볼륨) - 프리티어 호환
  - Redis Server (Private, t3.micro) - 프리티어 호환

### 4. **S3 모듈** - 스토리지
- **목적**: 이미지 파일 저장
- **포함 리소스**:
  - S3 버킷 (versioning 활성화)
  - 버킷 정책
  - 퍼블릭 액세스 차단

### 5. **CloudFront 모듈** - CDN
- **목적**: S3 콘텐츠 전송 가속화
- **포함 리소스**:
  - CloudFront 배포
  - Origin Access Control (OAC)
  - 캐시 정책

### 6. **SES 모듈** - 이메일 서비스
- **목적**: 이메일 발송 기능
- **포함 리소스**:
  - SES 도메인 검증
  - DKIM 설정
  - 이메일 템플릿 (환영/비밀번호 재설정)
  - Configuration Set

### 7. **Bedrock 모듈** - AI 서비스
- **목적**: AWS Bedrock 연동
- **포함 리소스**:
  - IAM 역할 및 정책
  - CloudWatch 로그 그룹
  - Instance Profile

## 🚀 사용 방법

### 📝 사전 준비

1. **AWS CLI 설정**
   ```bash
   aws configure
   # Access Key, Secret Key, Region 입력
   ```

2. **Terraform 설치 확인**
   ```bash
   terraform version
   # Terraform v1.0 이상 필요
   ```

3. **SSH 키 페어 생성 후 권한 설정**

### 🎯 배포 단계

#### 1단계: 환경 디렉토리로 이동 및 변수 파일 생성
```bash
# 프로젝트 루트에서 시작
cd terraform/environments/dev

# 변수 파일 생성
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

#### 2단계: Terraform 초기화
```bash
# terraform/environments/dev 디렉토리에서 실행
terraform init
```
- 필요한 Provider 다운로드
- 모듈 초기화 및 의존성 확인
- 백엔드 설정 초기화

#### 3단계: 배포 계획 확인
```bash
# terraform/environments/dev 디렉토리에서 실행
terraform plan
```
- 생성/수정/삭제될 리소스 미리 확인
- 모듈 의존성 자동 해결 (VPC → Security → Bedrock → Compute → S3 → CloudFront → SES)

#### 4단계: 인프라 배포
```bash
# terraform/environments/dev 디렉토리에서 실행
terraform apply
```
- 모든 모듈이 올바른 순서로 자동 실행됨
- 의존성이 있는 리소스는 자동으로 순서대로 생성

#### 5단계: 출력 정보 확인
```bash
# terraform/environments/dev 디렉토리에서 실행
terraform output
```

### 📋 모듈 실행 순서 (자동)

Terraform이 자동으로 감지하는 의존성 순서:

1. **VPC 모듈** → 네트워크 기반 구성
2. **Security 모듈** → VPC ID 참조하여 보안 그룹 생성
3. **Bedrock 모듈** → AI 서비스용 IAM 역할 생성
4. **Compute 모듈** → VPC 서브넷, 보안 그룹, Bedrock IAM 참조하여 EC2 생성
5. **S3 모듈** → 독립적으로 실행
6. **CloudFront 모듈** → S3 버킷 정보 참조
7. **SES 모듈** → 독립적으로 실행

### 📤 출력 정보

배포 완료 후 다음 정보들이 출력됩니다:

```bash
# EC2 인스턴스 정보
main_service_public_ip = "XXX.XXX.XXX.XXX"
main_service_private_ip = "10.0.1.XXX"
ai_service_private_ip = "10.0.2.XXX"
mysql_private_ip = "10.0.2.XXX"
redis_private_ip = "10.0.2.XXX"

# SSH 접속 명령어
main_service_ssh_command = "ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@XXX.XXX.XXX.XXX"

# S3 및 CloudFront
s3_bucket_name = "mechuragi-dev-images"
cloudfront_distribution_url = "https://XXXXXX.cloudfront.net"

# SES 설정 정보
ses_domain_verification_record = "TXT 레코드 값"
ses_dkim_records = ["CNAME 레코드들"]
```

## 🔧 고급 사용법

### 특정 모듈만 적용
```bash
# VPC만 생성
terraform apply -target=module.vpc

# 계산 리소스만 생성
terraform apply -target=module.compute
```

### 변수 오버라이드
```bash
# 인스턴스 타입 임시 변경
terraform apply -var="instance_type=t3.micro"

# 리전 변경
terraform apply -var="aws_region=us-west-2"
```

### 상태 확인
```bash
# 리소스 목록 확인
terraform state list

# 특정 리소스 상세 정보
terraform state show module.compute.aws_instance.main_service
```

### 인프라 정리
```bash
# 전체 리소스 삭제
terraform destroy

# 특정 리소스만 삭제
terraform destroy -target=module.s3
```

## 🔍 트러블슈팅

### 초기화 문제
```bash
# .terraform 디렉토리 삭제 후 재초기화
rm -rf .terraform
terraform init
```

### 상태 파일 문제
```bash
# 상태 파일 새로고침
terraform refresh

# 상태 파일에서 리소스 제거
terraform state rm module.vpc.aws_instance.example
```

### 버전 호환성
```bash
# Terraform 버전 업그레이드
terraform init -upgrade
```

## 🛡️ 보안 고려사항

### 상태 파일 관리
- 상태 파일에는 민감한 정보가 포함될 수 있음
- 원격 백엔드 사용 권장 (S3 + DynamoDB)
- 상태 파일 암호화 활성화

### 액세스 키 관리
- 하드코딩 금지
- AWS IAM Role 사용 권장
- 최소 권한 원칙 적용

### 리소스 태그
- 모든 리소스에 프로젝트/환경 태그 자동 적용
- 비용 추적 및 관리 용이

## 📈 확장 가이드

### 새 모듈 추가
1. `modules/` 하위에 새 디렉토리 생성
2. `main.tf`, `variables.tf`, `outputs.tf` 파일 작성
3. `environments/dev/main.tf`에서 모듈 호출

### 새 환경 추가
1. `environments/` 하위에 새 환경 디렉토리 생성
2. 기존 dev 환경 파일들 복사
3. 환경별 변수값 수정

### 모니터링 추가
- CloudWatch 모듈 생성
- 알람 및 대시보드 설정
- SNS 연동으로 알림 기능

## 💰 비용 최적화

### 개발 환경 (현재 설정)
- **EC2**:
  - Main/MySQL/Redis: t3.micro (프리티어 호환, 약 37.5% 비용 절감)
  - AI Service: t3.small (Bedrock 처리 성능 확보)
- **MySQL 볼륨**: 30GB (terraform.tfvars에서 조정 가능)
- **S3**: Standard-IA 스토리지 클래스 고려
- **CloudFront**: 필요시에만 활성화

### 운영 환경
- **Reserved Instances** 활용
- **Spot Instances** 고려 (상태가 없는 서비스)
- **Auto Scaling** 구성으로 탄력적 운영