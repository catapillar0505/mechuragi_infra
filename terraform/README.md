# Terraform 인프라 구성 가이드

## 개요

메추라기 프로젝트의 AWS 인프라를 Terraform으로 관리하는 IaC(Infrastructure as Code) 구성입니다. 통합 마이크로서비스 아키텍처로 설계되어 비용 최적화와 보안 강화를 동시에 달성합니다.

## 아키텍처 개요

### 통합 서비스 구조 (3개 인스턴스)
- **통합 메인 서버** (Private Subnet): MySQL + Redis + API를 Docker Compose로 통합
- **AI 서버** (Private Subnet): Bedrock 연동 AI 추천 서비스, 메인 서버 MySQL 직접 접근
- **Nginx Gateway** (Public Subnet): OpenResty 리버스 프록시 + Bastion Host + NAT Instance

### React 프론트엔드 배포 환경
- **Frontend S3**: React SPA 호스팅
- **Images S3**: 이미지 파일 저장
- **Logs S3**: 애플리케이션 로그 아카이빙 (Lifecycle Policy 적용)
- **CloudFront CDN**: 3-Origin 구조 (Frontend + Images + API/AI)

## 디렉토리 구조

```
terraform/
├── environments/
│   └── dev/
│       ├── main.tf              # 메인 구성 (모듈 오케스트레이션)
│       ├── variables.tf         # 입력 변수 정의
│       ├── outputs.tf           # 출력 값 정의
│       ├── terraform.tfvars     # 실제 변수 값 (gitignore 권장)
│       └── terraform.tfvars.example  # 변수 값 예시
└── modules/
    ├── vpc/                     # VPC 네트워킹 (Public + Private Subnet)
    ├── security/                # 보안 그룹 (3계층 보안 설계)
    ├── iam/                     # IAM Roles & Instance Profiles (3개 서비스별)
    ├── compute/                 # EC2 인스턴스 (3개 통합 인스턴스)
    ├── s3/                      # S3 스토리지 (Frontend + Images + Logs)
    ├── cloudfront/              # CloudFront CDN (3-Origin)
    ├── acm-certificate/         # ACM SSL/TLS 인증서 (us-east-1)
    ├── ses/                     # SES 이메일 서비스
    ├── bedrock/                 # Bedrock AI 모델 설정 (SSM Parameter Store)
    └── cloudwatch-logs/         # CloudWatch 로그 그룹 (서비스별)
```

## 인프라 구성 요소

### 1. VPC 모듈 - Public + Private Subnet

네트워크 격리를 통한 보안 강화 및 비용 최적화를 담당합니다.

- VPC (10.0.0.0/16)
- Public Subnet (10.0.1.0/24) - Nginx Gateway 배치
- Private Subnet (10.0.2.0/24) - 메인 서버, AI 서버 배치
- Internet Gateway - Public Subnet 인터넷 연결
- Route Tables
  - Public: 0.0.0.0/0 → Internet Gateway
  - Private: 0.0.0.0/0 → Nginx ENI (NAT Instance)

> NAT Gateway 대신 Nginx가 NAT 역할을 수행하여 월 $40-50 절감

---

### 2. Security 모듈 - 3계층 보안 설계

최소 권한 원칙 기반의 보안 그룹을 관리합니다.

| 계층 | 대상 | Inbound 허용 |
|------|------|-------------|
| Level 1 | Nginx Gateway (Public) | HTTP(80), HTTPS(443) - 인터넷 전체 / SSH(22) - 관리자 IP |
| Level 2 | 메인 서버 (Private) | HTTP/HTTPS/SSH/8080/8081 - Nginx에서만 / MySQL(3306) - AI에서만 |
| Level 3 | AI 서버 (Private) | SSH(22)/8082 - Nginx에서만 |

- 모든 서버: ICMP (VPC 내부 통신 확인용)
- 메인 서버: 8080/8081 포트로 Blue-Green 배포 지원

---

### 3. IAM 모듈 - 서비스별 최소 권한 IAM

각 서비스에 필요한 권한만 부여하는 IAM Role 및 Instance Profile을 관리합니다.

| 서비스 | 권한 |
|--------|------|
| 메인 서버 | SES 이메일 전송, S3 이미지 버킷 접근, EC2 메타데이터 조회, CloudWatch Logs |
| AI 서버 | Bedrock 모델 호출, SSM Parameter Store 조회, EC2 메타데이터 조회, CloudWatch Logs |
| Nginx Gateway | S3 로그 버킷 접근, CloudWatch Logs |

---

### 4. Compute 모듈 - 통합 마이크로서비스

3개 EC2 인스턴스와 네트워크 인터페이스를 관리합니다.

| 인스턴스 | 위치 | 타입 (기본값) | 볼륨 | 특이사항 |
|----------|------|--------------|------|----------|
| 메인 서버 | Private Subnet | t3.small | gp3 30GB (암호화) | MySQL 데이터 포함 |
| AI 서버 | Private Subnet | t3.small | gp3 20GB (암호화) | Bedrock IAM Profile |
| Nginx Gateway | Public Subnet | t3.micro | gp3 20GB (암호화) | EIP, Source/Dest Check 비활성화 (NAT), user_data로 NAT 초기 설정 |

- Private Subnet의 NAT 라우트가 Nginx Gateway ENI를 통해 자동 구성됨
- AMI: Ubuntu 22.04 LTS (Canonical 공식)

---

### 5. S3 모듈 - Frontend + Images + Logs

3개의 S3 버킷을 관리합니다.

| 버킷 | 용도 | 버전 관리 | CORS |
|------|------|----------|------|
| `{project}-{env}-frontend` | React SPA 호스팅 | O | CloudFront, 로컬 개발 서버 |
| `{project}-{env}-images` | 이미지 파일 저장 | O | CloudFront, 서비스 도메인, 로컬 개발 서버 |
| `{project}-{env}-logs` | 로그 아카이빙 | O | - |

**공통 보안 설정:**
- 퍼블릭 액세스 완전 차단 (CloudFront OAC만 허용)
- AES-256 서버 측 암호화

**Logs 버킷 Lifecycle Policy:**
- 30일 후 → Standard-IA (저렴한 스토리지)
- 90일 후 → Glacier (장기 보관)
- 365일 후 → 자동 삭제

---

### 6. CloudFront 모듈 - 3-Origin CDN

React SPA + 이미지 CDN + API/AI 프록시를 통합 관리합니다.

**3-Origin 구조:**
- **Frontend Origin**: React 정적 파일 (S3)
- **Images Origin**: 이미지 파일 (S3)
- **API Origin**: Nginx Gateway (Public IP)
  - `/api/*` → 메인 서버
  - `/recommend/*` → AI 서버
  - `/login/*`, `/swagger-ui/*` → 메인 서버

**캐시 정책:**
- React/이미지 파일: 장기 캐시 (1일~1년)
- API/AI 응답: 캐시 비활성화

**보안:** 각 S3 버킷별 개별 OAC(Origin Access Control) 설정

---

### 7. ACM Certificate 모듈 - SSL/TLS 인증서

CloudFront용 HTTPS 인증서를 us-east-1 리전에 생성합니다. DNS 검증 방식을 사용하며, AWS ACM 자동 갱신을 지원합니다.

---

### 8. SES 모듈 - 이메일 서비스

도메인 검증, DKIM 설정, Configuration Set(모니터링)을 관리합니다.

---

### 9. Bedrock 모듈 - AI 모델 설정

AI 서비스가 사용하는 모델 ID를 SSM Parameter Store에 저장하고, CloudWatch 로그 그룹(14일 보존)을 생성합니다.

> IAM 권한은 IAM 모듈에서 통합 관리됩니다.

---

### 10. CloudWatch Logs 모듈 - 서비스별 로그 그룹

각 서비스별 CloudWatch 로그 그룹을 생성합니다. 보존 기간은 변수로 관리 (기본 30일).

- Main Service: MySQL, Redis, API (3개 로그 그룹)
- AI Service: 1개 로그 그룹
- Nginx Gateway: 1개 로그 그룹

## 로그 수집 체계

모든 서비스 로그는 **CloudWatch Logs**로 중앙 수집되며, Nginx 로그는 추가로 **S3에 아카이빙**됩니다.

### 서비스별 로그 수집 경로

| 서버 | 로그 소스 | 수집 방식 | CloudWatch 로그 그룹 | 비고 |
|------|----------|----------|---------------------|------|
| 메인 서버 | MySQL 컨테이너 | Docker 로그 드라이버 → CloudWatch | `/{project}/{env}/main-service/mysql` | |
| 메인 서버 | Redis 컨테이너 | Docker 로그 드라이버 → CloudWatch | `/{project}/{env}/main-service/redis` | |
| 메인 서버 | API 컨테이너 | Docker 로그 드라이버 → CloudWatch | `/{project}/{env}/main-service/api` | |
| AI 서버 | AI 컨테이너 | Docker 로그 드라이버 → CloudWatch | `/{project}/{env}/ai-service` | |
| Nginx Gateway | OpenResty access/error 로그 | CloudWatch Agent → CloudWatch | `/{project}/{env}/nginx-gateway` | 30일 보존 |

### Nginx Gateway 로그 관리 (다중 계층)

Nginx Gateway는 3중 로그 관리 체계를 갖추고 있습니다:

1. **로컬 파일**: `/var/log/openresty/access.log`, `/var/log/openresty/error.log`
2. **CloudWatch Agent**: 로컬 로그를 실시간으로 CloudWatch Logs에 전송 (60초 간격)
3. **S3 아카이빙**: 매일 02:00 cron으로 압축 로그를 `{project}-{env}-logs` 버킷에 업로드

### 로그 보존 정책

| 저장소 | 보존 기간 | 관리 주체 |
|--------|----------|----------|
| 로컬 (Nginx Gateway) | 30일 (logrotate + cron 자동 삭제) | Ansible |
| CloudWatch Logs | 30일 (기본값, 변수로 조정 가능) | Terraform `cloudwatch-logs` 모듈 |
| Bedrock 로그 | 14일 | Terraform `bedrock` 모듈 |
| S3 Logs 버킷 | 30일 Standard → 90일 Glacier → 365일 삭제 | Terraform `s3` 모듈 Lifecycle Policy |

## 사용 방법

### 사전 준비

1. **AWS CLI 설정** (AdministratorAccess 권한 필요)
   ```bash
   aws configure
   ```

2. **Terraform 설치 확인** (v1.0 이상, AWS Provider ~> 5.0)
   ```bash
   terraform version
   ```

3. **SSH 키 페어** - AWS 콘솔에서 생성 후 로컬에 저장 및 권한 설정
   ```bash
   chmod 400 <SSH_KEY_PATH>
   ```

4. **변수 파일 설정**
   ```bash
   cd terraform/environments/dev
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars 편집
   ```

### 배포 단계

```bash
cd terraform/environments/dev

# 초기화
terraform init

# 배포 계획 확인
terraform plan

# 전체 인프라 배포
terraform apply
```

### 모듈 실행 순서 (자동)

1. VPC → Public + Private Subnet 네트워크
2. Security → 3계층 보안 그룹
3. IAM → 서비스별 IAM Role & Instance Profile
4. Bedrock → AI 모델 SSM 파라미터
5. Compute → 3개 EC2 인스턴스 + NAT 라우트
6. S3 → Frontend + Images + Logs 버킷
7. ACM Certificate → CloudFront용 SSL/TLS 인증서 (us-east-1)
8. CloudFront → 3-Origin CDN 구성
9. SES → 이메일 서비스
10. CloudWatch Logs → 서비스별 로그 그룹

## React 프론트엔드 배포

```bash
# 1. React 앱 빌드
npm run build

# 2. 프론트엔드 S3에 업로드
aws s3 sync ./build s3://<FRONTEND_BUCKET_NAME> --delete

# 3. 이미지 파일 업로드
aws s3 sync ./images s3://<IMAGES_BUCKET_NAME>/images/

# 4. CloudFront 캐시 무효화 (필요시)
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

> `terraform output`으로 버킷 이름, Distribution ID 등을 확인할 수 있습니다.

## 고급 사용법

### 기존 리소스 Import (충돌 해결)
```bash
terraform import module.bedrock.aws_iam_role.bedrock_role <ROLE_NAME>
terraform import module.s3.aws_s3_bucket.mechuragi_images_bucket <BUCKET_NAME>
```

### 인스턴스 타입 조정
```bash
# AI 서비스만 스케일업
terraform apply -var="ai_service_instance_type=t3.medium"

# 전체 스케일업
terraform apply \
  -var="main_service_instance_type=t3.medium" \
  -var="ai_service_instance_type=t3.medium" \
  -var="nginx_gateway_instance_type=t3.small"
```

### 특정 모듈만 배포
```bash
terraform apply -target=module.cloudfront
terraform apply -target=module.s3
```

## 보안 설계

### 네트워크 보안
- Private Subnet에 백엔드 서버 격리, Nginx Gateway만 Public 노출
- VPC 내부 통신으로만 DB/캐시 접근
- Elastic IP 1개로 Gateway 고정 IP 확보

### 데이터 보안
- S3 AES-256 서버 측 암호화 + 퍼블릭 액세스 차단
- CloudFront OAC로 S3 직접 접근 차단
- EBS 볼륨 암호화 활성화

### 접근 보안
- SSH 키 기반 인증 (Bastion Host 경유)
- CloudFront HTTPS 강제
- IAM 최소 권한 원칙 (서비스별 필요 권한만 부여)

## 비용 최적화

### 현재 설정 (개발 환경)

| 항목 | 사양 | 비고 |
|------|------|------|
| 메인 서버 | t3.small | MySQL + Redis + API 통합 |
| AI 서버 | t3.small | Bedrock 연동 |
| Nginx Gateway | t3.micro | 최소 사양 |
| NAT | Nginx 자체 NAT | NAT Gateway 제거 (월 $40-50 절감) |
| EIP | 1개 | 4개 → 1개 (월 $9 절감) |
| 스토리지 | gp3 (암호화) | 로그 Lifecycle으로 비용 절감 |

### 운영 환경 권장사항
```bash
terraform apply \
  -var="main_service_instance_type=t3.large" \
  -var="ai_service_instance_type=c5.large" \
  -var="nginx_gateway_instance_type=t3.small"
```

## 보안 참고사항

- `terraform.tfvars`에 SSH 키 이름, 관리자 IP, 이메일 주소 등 민감 정보가 포함되어 있으므로 `.gitignore`에 추가하거나 공개 저장소에 커밋하지 않도록 주의합니다.
- `terraform.tfstate`에는 리소스 ID, IP 주소 등 인프라 전체 정보가 포함되므로 반드시 안전하게 관리합니다 (S3 Backend + DynamoDB Lock 권장).
- `terraform.tfvars.example`을 참고하여 실제 값 파일을 별도로 생성합니다.

## 문제 해결

### 권한 오류
```bash
aws iam get-user
aws sts get-caller-identity
```

### 리소스 충돌
```bash
aws iam list-roles | grep mechuragi
terraform import module.<MODULE>.<RESOURCE> <RESOURCE_NAME>
```

### CloudFront 배포 대기
```bash
# 배포 상태 확인 (보통 10-15분 소요)
aws cloudfront get-distribution --id <DISTRIBUTION_ID>
```

## 관련 문서

- [메인 README](../README.md): 전체 인프라 개요
- [Ansible 가이드](../ansible/README.md): 서버 소프트웨어 구성
