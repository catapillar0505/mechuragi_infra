# CloudFront 403 Forbidden 오류 트러블슈팅

## 문제 증상

```
403 ERROR
The request could not be satisfied.
Bad request. We can't connect to the server for this app or website at this time.
```

커스텀 도메인(예: mechuragi.kro.kr)으로 접속 시 CloudFront에서 403 Forbidden 오류 발생

## 원인 분석

CloudFront 배포에서 커스텀 도메인을 받아들이려면 다음 조건이 **모두** 충족되어야 합니다:

1. **DNS CNAME 레코드 설정** ✅
   - `mechuragi.kro.kr` → CloudFront 배포 도메인 (`d4pdjk57v9eg4.cloudfront.net`)

2. **ACM SSL 인증서 발급 및 검증** ✅
   - us-east-1 리전에 인증서 생성
   - DNS 검증 CNAME 레코드 추가
   - 상태: ISSUED

3. **CloudFront aliases(CNAME) 설정** ❌ ← **문제 발생 원인**
   - CloudFront 배포 설정에 커스텀 도메인 추가 필요
   - Terraform 변수 `use_custom_domain = false`로 비활성화되어 있음

## 점검 항목

### 1. EC2 보안 그룹 - CloudFront IP 허용

**파일**: `terraform/modules/security/main.tf`

```terraform
# 메인 서비스 HTTP 허용
ingress {
  description = "HTTP from internet"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # 전체 인터넷 허용 (CloudFront 포함)
}
```

**결론**: ✅ 문제 없음 - `0.0.0.0/0`으로 모든 IP 허용 중

### 2. CloudFront CNAME 설정 확인

**파일**: `terraform/modules/cloudfront/main.tf`

```terraform
# CloudFront 배포 설정
resource "aws_cloudfront_distribution" "main_distribution" {
  # ...

  # aliases는 조건부로 설정됨
  aliases = var.use_custom_domain && var.acm_certificate_arn != null ? [var.domain_name] : []

  # SSL 인증서 설정
  viewer_certificate {
    cloudfront_default_certificate = var.use_custom_domain && var.acm_certificate_arn != null ? false : true
    acm_certificate_arn            = var.use_custom_domain && var.acm_certificate_arn != null ? var.acm_certificate_arn : null
    ssl_support_method             = var.use_custom_domain && var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.use_custom_domain && var.acm_certificate_arn != null ? "TLSv1.2_2021" : null
  }
}
```

**결론**: ⚠️ `use_custom_domain` 변수가 `false`로 설정되어 aliases가 비어있음

### 3. 지리적 제한 및 WAF 설정

**파일**: `terraform/modules/cloudfront/main.tf`

```terraform
restrictions {
  geo_restriction {
    restriction_type = "none"  # 지리적 제한 없음
  }
}
```

**결론**: ✅ 문제 없음 - 지리적 제한 및 WAF 미설정

### 4. Nginx 설정 - CloudFront 요청 처리

**파일**: `ansible/roles/nginx/templates/nginx-main-service.conf.j2`

```nginx
server {
    listen 80;
    server_name {{ ansible_host }} _;  # 와일드카드로 모든 호스트 허용

    # CloudFront 헤더 전달
    location /api/ {
        proxy_pass http://backend/;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**결론**: ✅ 문제 없음 - 와일드카드(`_`)로 모든 호스트 허용

## 해결 방법

### 1. Terraform 변수 파일 수정

**파일**: `terraform/environments/dev/terraform.tfvars`

**수정 전**:
```hcl
# cloudfront 설정
domain_name = "mechuragi.kro.kr"
use_custom_domain = false  # ❌ 비활성화
```

**수정 후**:
```hcl
# cloudfront 설정
domain_name = "mechuragi.kro.kr"
use_custom_domain = true   # ✅ 활성화
wait_for_acm_validation = true
```

### 2. Terraform Apply 실행

```bash
cd terraform/environments/dev

# 변경사항 확인
terraform plan -target=module.cloudfront.aws_cloudfront_distribution.main_distribution

# 적용
terraform apply -target=module.cloudfront.aws_cloudfront_distribution.main_distribution -auto-approve
```

**예상 변경사항**:
- `aliases`: `[]` → `["mechuragi.kro.kr"]`
- `acm_certificate_arn`: null → ACM 인증서 ARN
- `cloudfront_default_certificate`: true → false
- `minimum_protocol_version`: "TLSv1" → "TLSv1.2_2021"
- `ssl_support_method`: null → "sni-only"

**적용 시간**: 약 3-4분 소요

### 3. 배포 상태 확인

```bash
aws cloudfront get-distribution --id <DISTRIBUTION_ID> \
  --query 'Distribution.{Status:Status,Aliases:DistributionConfig.Aliases.Items,Certificate:DistributionConfig.ViewerCertificate.ACMCertificateArn}'
```

**성공 응답**:
```json
{
    "Status": "Deployed",
    "Aliases": ["mechuragi.kro.kr"],
    "Certificate": "arn:aws:acm:us-east-1:xxx:certificate/xxx"
}
```

## 테스트 방법

### 1. 브라우저 캐시 초기화

- Chrome/Edge: `Ctrl + Shift + Delete`
- 시크릿 모드로 테스트 권장

### 2. DNS 캐시 초기화

```bash
# Windows
ipconfig /flushdns

# Mac
sudo dscacheutil -flushcache

# Linux
sudo systemd-resolve --flush-caches
```

### 3. CloudFront 캐시 무효화 (선택사항)

```bash
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

### 4. 접속 테스트

```bash
# HTTPS로 접속 (자동 리디렉션)
curl -I https://mechuragi.kro.kr

# 예상 응답
HTTP/2 200
server: CloudFront
x-cache: Miss from cloudfront
```

## 예방 조치

### 초기 인프라 구축 시 체크리스트

1. **ACM 인증서 발급**
   ```bash
   terraform apply -target=module.acm_certificate
   ```

2. **DNS 검증 레코드 추가**
   - ACM 콘솔에서 CNAME 레코드 확인
   - 도메인 제공자(kro.kr 등)에 CNAME 레코드 추가

3. **인증서 검증 대기** (최대 30분)
   ```bash
   terraform output acm_certificate_status
   # 출력: "ISSUED"
   ```

4. **CloudFront 커스텀 도메인 활성화**
   ```hcl
   # terraform.tfvars
   use_custom_domain = true
   wait_for_acm_validation = true
   ```

5. **전체 인프라 배포**
   ```bash
   terraform apply
   ```

## 추가 참고사항

### CloudFront 배포 업데이트 시간

- 일반적으로 3-5분 소요
- 전 세계 엣지 로케이션 전파: 최대 15분
- 긴급 상황이 아니면 캐시 무효화는 불필요

### CORS 설정 (프로덕션 환경)

**파일**: `ansible/roles/nginx/templates/nginx-main-service.conf.j2`

현재는 모든 origin 허용:
```nginx
add_header 'Access-Control-Allow-Origin' '*' always;
```

프로덕션에서는 특정 도메인으로 제한 권장:
```nginx
add_header 'Access-Control-Allow-Origin' 'https://mechuragi.kro.kr' always;
```

## 관련 문서

- [CloudFront 커스텀 도메인 설정 가이드](./cloudfront-custom-domain-setup.md)
- [VPC 내부 연결성 가이드](./vpc-internal-connectivity.md)
