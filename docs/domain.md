# CloudFront 커스텀 도메인 설정 가이드

## 개요

CloudFront Distribution에 커스텀 도메인 `mechuragi.kro.kr`을 연결하는 방법을 설명합니다.

### 아키텍처

```
kro.kr (DNS Provider)
  └─ CNAME: _abc123.mechuragi.kro.kr → ACM 검증용
  └─ CNAME: mechuragi.kro.kr → CloudFront Distribution

AWS CloudFront
  └─ Distribution ID: E2055JLBFIVGCA
  └─ Default Domain: d4pdjk57v9eg4.cloudfront.net
  └─ Custom Domain: mechuragi.kro.kr (ACM 인증서 사용)

AWS ACM (us-east-1)
  └─ Certificate: mechuragi.kro.kr
  └─ Validation Method: DNS (CNAME)
```

## 배경

### 초기 시도: Route53 호스팅 존 사용

처음에는 Route53 호스팅 존을 생성하여 도메인을 관리하려고 했으나, kro.kr에서 **네임서버 변경이 불가능**하고 **A/CNAME 레코드만 직접 설정 가능**하다는 것을 확인했습니다.

### 최종 방식: 수동 DNS 설정

Route53 호스팅 존 없이 ACM 인증서만 생성하고, kro.kr DNS 관리 페이지에서 직접 CNAME 레코드를 설정하는 방식으로 변경했습니다.

## Terraform 모듈 구조

### 1. ACM 인증서 모듈 (`terraform/modules/acm-certificate/`)

CloudFront용 SSL/TLS 인증서를 생성하는 모듈입니다.

**주요 특징:**
- us-east-1 리전에 생성 (CloudFront 요구사항)
- DNS 검증 방식 사용
- 검증 대기 기능 (`wait_for_validation` 변수로 제어)

**파일:**
- `main.tf`: ACM 인증서 생성 및 검증 대기 리소스
- `variables.tf`: 도메인 이름, 검증 대기 여부 등
- `outputs.tf`: 인증서 ARN, 검증용 DNS 레코드 정보
- `providers.tf`: us-east-1 provider 설정

### 2. CloudFront 모듈 업데이트 (`terraform/modules/cloudfront/`)

기본 CloudFront Distribution에 커스텀 도메인 지원 추가:

**추가된 변수:**
- `domain_name`: 커스텀 도메인 이름
- `acm_certificate_arn`: ACM 인증서 ARN
- `use_custom_domain`: 커스텀 도메인 활성화 여부 (기본값: false)

**동작 방식:**
- `use_custom_domain=false`: 기본 CloudFront 인증서 사용
- `use_custom_domain=true`: ACM 인증서와 커스텀 도메인 사용

## 설정 단계

### 1단계: Terraform 초기화 및 기본 인프라 생성

```bash
cd ~/mechuragi-infra/terraform/environments/dev

# 모듈 이름이 변경되었으므로 재초기화
terraform init -upgrade

# 인프라 생성 (ACM 인증서는 검증 대기 상태로 생성됨)
terraform apply
```

**생성되는 리소스:**
- ACM 인증서 (검증 대기 상태)
- CloudFront Distribution (기본 인증서 사용)
- 기타 S3, EC2 등 기존 리소스

### 2단계: ACM 검증용 DNS 레코드 확인

```bash
terraform output acm_domain_validation_options
```

**출력 예시:**
```json
[
  {
    "domain_name" = "mechuragi.kro.kr"
    "record_name" = "_abc123.mechuragi.kro.kr."
    "record_type" = "CNAME"
    "record_value" = "_xyz456.acm-validations.aws."
  }
]
```

### 3단계: kro.kr DNS 관리 페이지에서 CNAME 레코드 추가

1. kro.kr DNS 관리 페이지 접속
2. **첫 번째 CNAME 레코드 추가 (ACM 검증용):**
   - 호스트/이름: `_abc123.mechuragi.kro.kr` (또는 `_abc123`)
   - 타입: CNAME
   - 값/대상: `_xyz456.acm-validations.aws.`
   - TTL: 300 (기본값)

3. DNS 전파 대기 (5-30분)

### 4단계: ACM 인증서 검증 활성화

DNS 레코드가 전파된 후 (10-30분 후):

```bash
terraform apply -var="wait_for_acm_validation=true"
```

이 명령어는 ACM 인증서 검증이 완료될 때까지 대기합니다 (보통 2-5분).

**검증 확인:**
```bash
# 인증서 상태 확인
terraform output acm_certificate_status
# 출력: "ISSUED" (검증 완료)
```

### 5단계: CloudFront에 커스텀 도메인 적용

```bash
terraform apply -var="use_custom_domain=true" -var="wait_for_acm_validation=true"
```

**변경 사항:**
- CloudFront Distribution에 `mechuragi.kro.kr` 별칭(alias) 추가
- 기본 인증서에서 ACM 인증서로 변경
- SSL/TLS 설정: SNI-only, TLSv1.2_2021

### 6단계: kro.kr에 CloudFront CNAME 추가

1. CloudFront 도메인 확인:
```bash
terraform output cloudfront_domain_name
# 출력: d4pdjk57v9eg4.cloudfront.net
```

2. kro.kr DNS 관리 페이지에서 **두 번째 CNAME 레코드 추가:**
   - 호스트/이름: `mechuragi` (또는 루트 도메인이면 `@`)
   - 타입: CNAME
   - 값/대상: `d4pdjk57v9eg4.cloudfront.net`
   - TTL: 300

3. DNS 전파 대기 (5-30분)

### 7단계: 동작 확인

```bash
# DNS 확인
nslookup mechuragi.kro.kr

# 웹 브라우저에서 접속
# https://mechuragi.kro.kr
```

## Terraform 변수 설명

### `terraform/environments/dev/variables.tf`

```hcl
variable "domain_name" {
  description = "Custom domain name (e.g., mechuragi.kro.kr)"
  type        = string
  default     = "mechuragi.kro.kr"
}

variable "use_custom_domain" {
  description = "Enable custom domain for CloudFront (only after ACM certificate is validated)"
  type        = bool
  default     = false
}

variable "wait_for_acm_validation" {
  description = "Wait for ACM certificate validation (only after DNS CNAME records are added to kro.kr)"
  type        = bool
  default     = false
}
```

### 변수 조합

| 단계 | use_custom_domain | wait_for_acm_validation | 설명 |
|------|-------------------|-------------------------|------|
| 1 | false | false | ACM 인증서 생성 (검증 대기), CloudFront 기본 인증서 사용 |
| 2 | false | true | ACM 인증서 검증 완료 대기 |
| 3 | true | true | CloudFront에 커스텀 도메인 및 ACM 인증서 적용 |

## 주요 Output

```bash
# CloudFront 정보
terraform output cloudfront_domain_name          # d4pdjk57v9eg4.cloudfront.net
terraform output cloudfront_distribution_id       # E2055JLBFIVGCA
terraform output cloudfront_distribution_url      # https://d4pdjk57v9eg4.cloudfront.net

# ACM 인증서 정보
terraform output acm_certificate_arn              # arn:aws:acm:us-east-1:...
terraform output acm_certificate_status           # ISSUED 또는 PENDING_VALIDATION
terraform output acm_domain_validation_options    # DNS 검증 레코드 정보
```

## 트러블슈팅

### ACM 인증서 검증이 완료되지 않음

**증상:**
```bash
terraform apply -var="wait_for_acm_validation=true"
```
실행 시 20분 이상 대기

**원인:**
- kro.kr에 ACM 검증용 CNAME 레코드가 추가되지 않았거나
- DNS 전파가 아직 완료되지 않음

**해결:**
1. DNS 레코드가 올바르게 추가되었는지 확인
2. DNS 전파 확인:
```bash
nslookup -type=CNAME _abc123.mechuragi.kro.kr
```
3. 전파가 완료되지 않았다면 **Ctrl+C**로 중단하고 나중에 재시도

### CloudFront 업데이트 시 "Invalid SSL certificate" 오류

**증상:**
```
InvalidViewerCertificate: The specified SSL certificate doesn't exist, isn't valid
```

**원인:**
- ACM 인증서가 아직 검증되지 않았음 (상태: PENDING_VALIDATION)

**해결:**
1. 먼저 ACM 인증서 검증 완료:
```bash
terraform apply -var="wait_for_acm_validation=true"
```
2. 검증 완료 후 CloudFront 업데이트:
```bash
terraform apply -var="use_custom_domain=true" -var="wait_for_acm_validation=true"
```

### IAM 권한 부족 오류

**증상:**
```
User is not authorized to perform: route53:CreateHostedZone
User is not authorized to perform: acm:RequestCertificate
User is not authorized to perform: iam:GetRole
```

**해결:**
다음 AWS 관리형 정책을 `jina-admin` 사용자에게 추가:
- `Route53FullAccess` (현재는 사용하지 않지만 향후를 위해)
- `AWSCertificateManagerFullAccess`
- `IAMFullAccess`

CLI로 추가:
```bash
aws iam attach-user-policy --user-name jina-admin \
  --policy-arn arn:aws:iam::aws:policy/AWSCertificateManagerFullAccess

aws iam attach-user-policy --user-name jina-admin \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

## 비용 안내

- **ACM 인증서**: 무료
- **CloudFront**: 기존과 동일 (커스텀 도메인 사용에 따른 추가 비용 없음)
- **Route53 호스팅 존**: 사용하지 않음 (비용 없음)

## 참고 자료

- [AWS ACM 사용 설명서](https://docs.aws.amazon.com/acm/)
- [CloudFront와 ACM 인증서 사용](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html)
- [DNS 검증 방법](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)

## 변경 이력

- 2025-10-23: 초기 문서 작성
  - Route53 호스팅 존 방식에서 수동 DNS 설정 방식으로 변경
  - ACM 인증서 모듈 생성
  - CloudFront 커스텀 도메인 지원 추가
