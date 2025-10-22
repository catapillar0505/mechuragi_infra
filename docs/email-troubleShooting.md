# 트러블슈팅 가이드

## SES 이메일 전송 실패

### 증상

메인 서비스에서 이메일 인증 로직 구현 후 SES를 통해 이메일 전송 시 다음과 같은 오류 발생:

```
java.lang.RuntimeException: 이메일 발송에 실패했습니다.
  at com.mechuragi.mechuragi_server.auth.service.EmailService.sendVerificationEmail(EmailService.java:75)
```

### 원인 분석

SES 이메일 전송 실패의 주요 원인은 다음 3가지입니다:

#### 1. 메인 서비스 인스턴스에 SES IAM 권한이 없음 (가장 중요)

- **문제**: 메인 서비스가 실행되는 EC2 인스턴스에 SES를 사용할 수 있는 IAM instance profile이 설정되어 있지 않음
- **확인 방법**:
  - `terraform/modules/compute/main.tf`에서 `main_service` 인스턴스 리소스 확인
  - `iam_instance_profile` 속성이 없거나 SES 권한이 없는 profile이 설정되어 있음
  - AI 서비스는 Bedrock용 instance profile이 있지만, main 서비스는 없는 상태

#### 2. SES 이메일 주소 검증 필요

- **문제**: AWS SES는 기본적으로 sandbox 모드로 시작하므로 발신 이메일 주소가 검증되어야 함
- **확인 방법**:
  ```bash
  aws ses get-identity-verification-attributes \
    --identities mechuragi001@gmail.com \
    --region ap-northeast-2
  ```

#### 3. SES Production Access 요청 필요 (추후)

- **문제**: Sandbox 모드에서는 검증된 이메일 주소로만 이메일 발송 가능
- **영향**: 실제 사용자에게 이메일을 보내려면 SES Production Access 신청 필요

### 해결 방법

#### Step 1: Terraform으로 SES IAM Instance Profile 설정

**1-1. compute 모듈에 SES instance profile 변수 추가**

파일: `terraform/modules/compute/variables.tf`

```hcl
variable "ses_instance_profile_name" {
  description = "Name of the SES IAM instance profile for main service"
  type        = string
}
```

**1-2. main_service 인스턴스에 IAM instance profile 적용**

파일: `terraform/modules/compute/main.tf`

```hcl
# 메인 서비스용 EC2 인스턴스 (Docker)
resource "aws_instance" "main_service" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.main_service_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.ses_instance_profile_name  # SES 권한 필요

  network_interface {
    network_interface_id = aws_network_interface.main_service_eni.id
    device_index         = 0
  }

  # ... 나머지 설정
}
```

**1-3. dev 환경에서 SES instance profile 전달**

파일: `terraform/environments/dev/main.tf`

```hcl
module "compute" {
  source = "../../modules/compute"

  # ... 기존 설정들
  bedrock_instance_profile_name  = module.bedrock.bedrock_instance_profile_name
  ses_instance_profile_name      = module.ses.ses_instance_profile_name  # 추가
}
```

**1-4. Terraform 적용**

```bash
cd /home/jina/mechuragi-infra/terraform/environments/dev
terraform plan
terraform apply
```

#### Step 2: 이메일 주소 검증

**자동 검증 프로세스** (콘솔 불필요):

1. **검증 이메일 자동 발송**:
   - Terraform apply 시 `aws_ses_email_identity` 리소스가 생성되면서 자동으로 검증 이메일 발송
   - 위치: `terraform/modules/ses/main.tf:8-10`

2. **이메일 확인 및 검증**:
   - Gmail에서 "Amazon SES Email Address Verification" 제목의 이메일 확인
   - 이메일 내 링크를 클릭하여 검증 완료

3. **검증 상태 확인** (선택사항):
   ```bash
   aws ses get-identity-verification-attributes \
     --identities mechuragi001@gmail.com \
     --region ap-northeast-2
   ```

#### Step 3: SES Production Access 신청 (추후)

실제 사용자에게 이메일을 보내기 위해서는 다음 단계가 필요합니다:

1. AWS Console > SES > Account dashboard
2. "Request production access" 클릭
3. 사용 목적 및 이메일 내용 설명
4. 승인 대기 (보통 24시간 이내)

### 검증

#### 1. IAM Instance Profile 확인

```bash
# EC2 인스턴스의 IAM role 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mechuragi-dev-main-service" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --region ap-northeast-2
```

#### 2. SES 권한 확인

```bash
# IAM role에 SES 권한이 있는지 확인
aws iam get-role-policy \
  --role-name mechuragi-dev-ses-role \
  --policy-name mechuragi-dev-ses-policy \
  --region ap-northeast-2
```

#### 3. 이메일 전송 테스트

```bash
# AWS CLI로 직접 이메일 전송 테스트
aws ses send-email \
  --from mechuragi001@gmail.com \
  --destination ToAddresses=mechuragi001@gmail.com \
  --message Subject={Data="Test Email"},Body={Text={Data="This is a test"}} \
  --region ap-northeast-2
```

### 관련 파일

- `terraform/modules/ses/main.tf` - SES 리소스 및 IAM 정책 정의
- `terraform/modules/ses/outputs.tf` - SES instance profile 출력
- `terraform/modules/compute/main.tf` - EC2 인스턴스 정의
- `terraform/modules/compute/variables.tf` - Compute 모듈 변수
- `terraform/environments/dev/main.tf` - Dev 환경 모듈 호출
- `ansible/group_vars/all/main.yml` - SES 이메일 설정 (ses_email, ses_domain)
- `ansible/roles/application/templates/main-service.env.j2` - 환경 변수 템플릿

### 추가 참고사항

#### SES 샌드박스 모드 제한사항

- 검증된 이메일 주소로만 발송 가능
- 일일 발송 한도: 200개
- 초당 발송 속도: 1개

#### SES Production 모드

- 모든 이메일 주소로 발송 가능
- 일일 발송 한도: 50,000개 (증가 신청 가능)
- 초당 발송 속도: 14개 (증가 신청 가능)

#### SES 비용

- 첫 62,000건/월: 무료 (AWS Free Tier)
- 이후: 1,000건당 $0.10

---

## 환경변수 방식 vs IAM Instance Profile 충돌 여부

### 질문
메인 서비스 레포의 `application.yml`에서 환경변수(`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)로 SES 자격증명을 설정했는데, 인프라 레포에서 IAM instance profile을 적용하면 충돌이 발생할까?

### 답변: 충돌하지 않습니다

두 가지 방식은 공존 가능하며, **환경변수가 우선적으로 사용됩니다**.

#### AWS SDK 자격 증명 체인 (Credential Chain)

AWS SDK는 다음 순서로 자격 증명을 찾습니다:

1. **환경 변수** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. Java 시스템 속성
3. 프로파일 파일 (`~/.aws/credentials`)
4. **IAM Instance Profile** (EC2 메타데이터 서비스)

즉, 환경변수가 설정되어 있으면 그것을 사용하고, 없으면 자동으로 IAM instance profile을 사용합니다.

### 현재 상황

```yaml
# 메인 서비스 레포의 application.yml
spring:
  mail:
    access-key: ${AWS_ACCESS_KEY_ID}      # 현재 사용 중
    secret-key: ${AWS_SECRET_ACCESS_KEY}   # 현재 사용 중
```

```hcl
# 인프라 레포의 terraform/modules/compute/main.tf:38
resource "aws_instance" "main_service" {
  iam_instance_profile = var.ses_instance_profile_name  # 설정했지만 아직 apply 안 함
  # ...
}
```

### IAM Instance Profile을 사용해야 하는 이유

| 방식 | 장점 | 단점 |
|------|------|------|
| **환경변수** | 빠른 테스트 가능 | 키 관리 필요, 유출 위험, 로테이션 관리 |
| **IAM Instance Profile** | 보안, 자동 관리, 유출 위험 없음 | 초기 설정 필요 |

**권장**: IAM Instance Profile 사용 (보안 모범 사례)

### 안전한 마이그레이션 단계

#### Step 1: jina-admin IAM 사용자 권한 추가

Terraform을 실행하기 전에 `jina-admin` IAM 사용자에게 필요한 권한을 추가해야 합니다.

**필요한 권한**:
- `logs:DescribeLogGroups` (CloudWatch Logs 조회)
- `ssm:GetParameter` (SSM Parameter Store 조회)
- `cloudfront:GetOriginAccessControl` (CloudFront 조회)

**방법 1: AWS Console에서 권한 추가 (권장)**

1. AWS Console > IAM > Users > jina-admin
2. "Add permissions" > "Attach policies directly"
3. 다음 managed policies 추가:
   - `CloudWatchLogsReadOnlyAccess`
   - `AmazonSSMReadOnlyAccess`
   - `CloudFrontReadOnlyAccess`

**방법 2: AWS CLI로 권한 추가**

```bash
# CloudWatch Logs 읽기 권한
aws iam attach-user-policy \
  --user-name jina-admin \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess

# SSM 읽기 권한
aws iam attach-user-policy \
  --user-name jina-admin \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess

# CloudFront 읽기 권한
aws iam attach-user-policy \
  --user-name jina-admin \
  --policy-arn arn:aws:iam::aws:policy/CloudFrontReadOnlyAccess
```

#### Step 2: Terraform으로 IAM Instance Profile 적용

인프라 레포에서 이미 설정이 완료되어 있으므로 권한 추가 후 apply 가능합니다.

```bash
cd /home/jina/mechuragi-infra/terraform/environments/dev
terraform plan   # 변경 사항 확인
terraform apply  # IAM instance profile 적용
```

**중요**: 환경변수가 설정되어 있어서 현재는 환경변수를 계속 사용합니다. IAM profile은 fallback으로 준비만 됩니다.

#### Step 3: 현재 환경변수로 이메일 전송 테스트

```bash
# 메인 서비스 레포에서
# 이메일 전송 API 테스트
curl -X POST http://your-service/api/auth/send-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

#### Step 4: 환경변수 제거 및 IAM Profile로 전환

메인 서비스 레포의 `application.yml`에서 다음 설정 제거:

```yaml
# 제거 또는 주석 처리
# access-key: ${AWS_ACCESS_KEY_ID}
# secret-key: ${AWS_SECRET_ACCESS_KEY}
```

AWS SDK가 자동으로 credential chain을 따라 IAM instance profile을 사용하게 됩니다.

#### Step 5: IAM Profile로 이메일 전송 검증 (EC2에서)

**중요**: IAM instance profile은 **EC2 인스턴스에서만** 작동합니다. 반드시 메인 서비스 EC2에 SSH 접속하여 테스트해야 합니다.

```bash
# EC2 메인 서비스 서버에 SSH 접속
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@<메인-서비스-공인IP>

# 1. 애플리케이션 재시작
sudo systemctl restart main-service  # 또는 docker-compose restart

# 2. 이메일 전송 테스트
curl -X POST http://localhost:8080/api/auth/send-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "mechuragi001@gmail.com"}'

# 3. 로그 확인
tail -f /var/log/main-service.log
# 또는 docker logs -f main-service
```

### 검증 명령어

#### IAM Instance Profile 적용 확인

```bash
# EC2 인스턴스에 IAM profile이 연결되었는지 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mechuragi-dev-main-service" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --region ap-northeast-2
```

#### EC2 인스턴스 내부에서 IAM 권한 확인

```bash
# EC2에 SSH 접속 후
# 메타데이터 서비스에서 IAM role 확인
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Role 이름이 나오면 해당 이름으로 자격증명 확인
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/mechuragi-dev-ses-role
```

### 트러블슈팅

#### 환경변수 제거 후 "Access Denied" 오류

**원인**: IAM instance profile이 제대로 적용되지 않았거나 권한 부족

**해결**:
1. EC2 인스턴스 재시작 (IAM profile 변경이 즉시 반영 안될 수 있음)
2. IAM role에 SES 권한 확인

```bash
aws iam get-role-policy \
  --role-name mechuragi-dev-ses-role \
  --policy-name mechuragi-dev-ses-policy \
  --region ap-northeast-2
```

#### 환경변수와 IAM Profile 중 어느 것을 사용하는지 확인

애플리케이션 로그에서 다음과 같은 메시지 확인:
- 환경변수 사용: `Using AWS credentials from environment variables`
- IAM Profile 사용: `Using AWS credentials from EC2 instance metadata`

### 관련 파일

- **인프라 레포**:
  - `terraform/modules/compute/main.tf:38` - IAM instance profile 설정
  - `terraform/modules/ses/main.tf` - SES IAM policy 정의

- **메인 서비스 레포**:
  - `application.yml` - AWS 자격증명 설정

---

## 환경별 AWS 자격증명 설정 가이드

### 개요

AWS 자격증명은 환경에 따라 다른 방식을 사용합니다:
- **EC2 (Production/Staging)**: IAM Instance Profile 사용 (권장)
- **로컬 개발**: 환경변수 또는 `~/.aws/credentials` 사용

### 환경별 설정 방법

#### EC2 환경 (메인 서비스 서버)

**자격증명 방식**: IAM Instance Profile

1. **Terraform으로 IAM instance profile 적용** (이미 완료)
   ```hcl
   # terraform/modules/compute/main.tf:38
   resource "aws_instance" "main_service" {
     iam_instance_profile = var.ses_instance_profile_name  # ✓
     # ...
   }
   ```

2. **메인 서비스 레포의 application.yml 설정**
   ```yaml
   # application-dev.yml 또는 application-prod.yml (EC2용)
   # AWS 자격증명 설정을 명시하지 않음
   # AWS SDK가 자동으로 IAM instance profile을 사용
   ```

   또는 명시적으로 프로파일 사용 설정:
   ```yaml
   # EC2에서는 이 설정 없이도 자동으로 IAM profile 사용
   # 필요시 명시 가능
   cloud:
     aws:
       credentials:
         instance-profile: true
   ```

3. **환경변수 미설정 확인**

   EC2에서 환경변수가 설정되어 있으면 IAM profile보다 우선하므로 제거:
   ```bash
   # .env 파일이나 systemd 환경변수에서 제거
   # AWS_ACCESS_KEY_ID=xxxxx  ← 이 줄 삭제
   # AWS_SECRET_ACCESS_KEY=xxxxx  ← 이 줄 삭제
   ```

#### 로컬 개발 환경

**자격증명 방식**: 환경변수 (IAM instance profile 사용 불가)

1. **메인 서비스 레포의 application-local.yml 설정**
   ```yaml
   # application-local.yml (로컬 개발용)
   spring:
     mail:
       host: email-smtp.ap-northeast-2.amazonaws.com
       port: 587
       username: ${AWS_ACCESS_KEY_ID}
       password: ${AWS_SECRET_ACCESS_KEY}
       properties:
         mail:
           smtp:
             auth: true
             starttls:
               enable: true
   ```

   또는 AWS SDK 자격증명:
   ```yaml
   cloud:
     aws:
       credentials:
         access-key: ${AWS_ACCESS_KEY_ID}
         secret-key: ${AWS_SECRET_ACCESS_KEY}
       region:
         static: ap-northeast-2
   ```

2. **환경변수 설정**

   **방법 1**: `.env` 파일 (권장)
   ```bash
   # 메인 서비스 레포의 .env 파일
   AWS_ACCESS_KEY_ID=your-access-key
   AWS_SECRET_ACCESS_KEY=your-secret-key
   AWS_REGION=ap-northeast-2
   ```

   **방법 2**: 쉘 환경변수
   ```bash
   export AWS_ACCESS_KEY_ID=your-access-key
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   export AWS_REGION=ap-northeast-2
   ```

   **방법 3**: `~/.aws/credentials` 파일
   ```ini
   [default]
   aws_access_key_id = your-access-key
   aws_secret_access_key = your-secret-key
   region = ap-northeast-2
   ```

### EC2에서 IAM Instance Profile 테스트 절차

#### 1. EC2 메타데이터로 IAM Role 확인

```bash
# EC2에 SSH 접속
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@<메인-서비스-공인IP>

# IAM role 이름 확인
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# 출력 예: mechuragi-dev-ses-role

# IAM role의 임시 자격증명 확인
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/mechuragi-dev-ses-role
```

**정상 출력 예시**:
```json
{
  "Code": "Success",
  "LastUpdated": "2025-01-15T10:30:00Z",
  "Type": "AWS-HMAC",
  "AccessKeyId": "ASIA...",
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "2025-01-15T16:30:00Z"
}
```

#### 2. 환경변수 방식으로 먼저 테스트 (현재 상태)

terraform apply 직후에는 환경변수가 설정되어 있을 수 있으므로 먼저 환경변수로 테스트:

```bash
# EC2에서
# 메인 서비스 상태 확인
sudo systemctl status main-service
# 또는
docker ps | grep main-service

# 이메일 전송 API 테스트
curl -X POST http://localhost:8080/api/auth/send-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "mechuragi001@gmail.com"}'

# 로그 확인
sudo journalctl -u main-service -f
# 또는
docker logs -f main-service
```

#### 3. IAM Instance Profile로 전환

**Step 3-1**: 환경변수 제거

```bash
# EC2에서
# systemd 서비스 환경변수 확인
sudo systemctl show main-service | grep Environment

# 또는 .env 파일 확인
cat /home/ubuntu/app/.env

# 환경변수 제거 (.env 파일 편집)
nano /home/ubuntu/app/.env
# AWS_ACCESS_KEY_ID와 AWS_SECRET_ACCESS_KEY 줄 삭제 또는 주석 처리
```

또는 메인 서비스 레포의 `application-dev.yml`에서 제거:
```yaml
# 이 부분 삭제 또는 주석 처리
# spring:
#   mail:
#     username: ${AWS_ACCESS_KEY_ID}
#     password: ${AWS_SECRET_ACCESS_KEY}
```

**Step 3-2**: 애플리케이션 재시작

```bash
# systemd 서비스인 경우
sudo systemctl restart main-service

# Docker Compose인 경우
cd /home/ubuntu/app
docker-compose restart main-service
```

**Step 3-3**: IAM Profile로 이메일 전송 테스트

```bash
# 이메일 전송 API 호출
curl -X POST http://localhost:8080/api/auth/send-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "mechuragi001@gmail.com"}'

# 응답 예시 (성공):
# {"success": true, "message": "Verification email sent"}

# 로그 확인
docker logs -f main-service 2>&1 | grep -i "ses\|email\|credential"
```

#### 4. 어떤 자격증명을 사용하는지 확인

애플리케이션 로그에서 다음 메시지 확인:

- **환경변수 사용 시**:
  ```
  Using AWS credentials from environment variables
  ```

- **IAM Instance Profile 사용 시**:
  ```
  Using AWS credentials from EC2 instance metadata
  ```

또는 Spring Boot의 Debug 로그 활성화:
```yaml
# application.yml
logging:
  level:
    com.amazonaws: DEBUG
```

### 로컬에서 이메일 전송 테스트 절차

#### 1. AWS 자격증명 설정 확인

```bash
# 로컬 개발 환경에서
# 환경변수 확인
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# 또는 ~/.aws/credentials 확인
cat ~/.aws/credentials
```

#### 2. Spring Boot 로컬 실행

```bash
# 메인 서비스 레포에서
# local 프로파일로 실행
./gradlew bootRun --args='--spring.profiles.active=local'

# 또는
java -jar build/libs/mechuragi-server.jar --spring.profiles.active=local
```

#### 3. 이메일 전송 테스트

```bash
# 로컬에서 API 호출
curl -X POST http://localhost:8080/api/auth/send-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "mechuragi001@gmail.com"}'
```

### 트러블슈팅: 환경별

#### EC2에서 "Access Denied" 오류

**원인**: IAM instance profile이 제대로 적용되지 않음

**해결**:
```bash
# 1. EC2 인스턴스에 IAM profile이 연결되었는지 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mechuragi-dev-main-service" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --region ap-northeast-2

# 2. EC2 재시작 (IAM profile 변경이 즉시 반영 안될 수 있음)
aws ec2 reboot-instances --instance-ids i-xxxxxxxxx --region ap-northeast-2

# 3. IAM role에 SES 권한 확인
aws iam get-role-policy \
  --role-name mechuragi-dev-ses-role \
  --policy-name mechuragi-dev-ses-policy \
  --region ap-northeast-2
```

#### 로컬에서 "Credentials not found" 오류

**원인**: AWS 자격증명이 설정되지 않음

**해결**:
```bash
# 환경변수 설정
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=ap-northeast-2

# 또는 ~/.aws/credentials 파일 생성
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = your-access-key
aws_secret_access_key = your-secret-key
EOF

cat > ~/.aws/config << EOF
[default]
region = ap-northeast-2
EOF
```

### 권장 설정 요약

| 환경 | 자격증명 방식 | 설정 위치 | 보안 수준 |
|------|--------------|----------|----------|
| **EC2 (Production)** | IAM Instance Profile | Terraform | 높음 ✓ |
| **EC2 (Staging)** | IAM Instance Profile | Terraform | 높음 ✓ |
| **로컬 개발** | 환경변수 또는 ~/.aws/credentials | .env 파일 (gitignore) | 중간 |
| **CI/CD** | IAM Role (GitHub Actions OIDC) | GitHub Secrets | 높음 ✓ |

**보안 모범 사례**:
1. ✓ EC2에서는 항상 IAM Instance Profile 사용
2. ✓ 액세스 키는 `.gitignore`에 추가하여 Git에 커밋하지 않음
3. ✓ 로컬 개발용 IAM 사용자는 SES 권한만 부여 (최소 권한 원칙)
4. ✓ 정기적으로 액세스 키 로테이션

---

## 기타 트러블슈팅 항목

(추가 트러블슈팅 항목은 여기에 계속 추가합니다)
