# 메추라기 인프라 트러블슈팅 가이드

이 문서는 메추라기 프로젝트 인프라 구축 및 운영 중 발생한 문제들과 해결 방법을 정리한 가이드입니다.

## 목차

1. [MySQL 관련 문제](#1-mysql-관련-문제)
2. [Docker 관련 문제](#2-docker-관련-문제)
3. [Ansible 관련 문제](#3-ansible-관련-문제)
4. [AWS 권한 관련 문제](#4-aws-권한-관련-문제)
5. [Nginx 관련 문제](#5-nginx-관련-문제)
6. [CloudFront 관련 문제](#6-cloudfront-관련-문제)
   - 6.1 [CloudFront Distribution 조회 실패](#61-cloudfront-distribution-조회-실패)
   - 6.2 [CloudFront 403 Forbidden Error](#62-cloudfront-403-forbidden-error)
   - 6.3 [Nginx가 프론트엔드 요청을 가로채는 문제](#63-nginx가-프론트엔드-요청을-가로채는-문제)
   - 6.4 [CloudFront API Origin 잘못된 설정 (순환 참조)](#64-cloudfront-api-origin-잘못된-설정-순환-참조)

---

## 1. MySQL 관련 문제

### 1.1 MySQL Connection Refused (bind-address 문제)

**증상:**
```
ERROR 2003 (HY000): Can't connect to MySQL server on '10.0.1.214' (111)
```

**원인:**
MySQL이 `127.0.0.1:3306`에서만 리스닝하고 있어 VPC 내부 다른 서버에서 접근 불가

**확인 방법:**
```bash
ss -tlnp | grep 3306
# 출력: 127.0.0.1:3306 (잘못된 경우)
# 출력: 0.0.0.0:3306 (올바른 경우)
```

**근본 원인:**
- `/etc/mysql/mysql.conf.d/mechuragi.cnf`에 `bind-address = 0.0.0.0` 설정
- 하지만 `/etc/mysql/mysql.conf.d/mysqld.cnf`에도 `bind-address = 127.0.0.1` 존재
- MySQL이 나중에 로드된 설정 우선 적용

**해결 방법:**

**파일:** `ansible/roles/mysql/tasks/main.yml`

```yaml
- name: 기본 mysqld.cnf의 bind-address 주석 처리 (중복 설정 방지)
  lineinfile:
    path: /etc/mysql/mysql.conf.d/mysqld.cnf
    regexp: '^bind-address\s*='
    line: '# bind-address = 127.0.0.1  # Commented out by Ansible - using mechuragi.cnf instead'
    backup: yes
  notify: MySQL 재시작
```

**검증:**
```bash
# MySQL 서버에서
sudo systemctl restart mysql
ss -tlnp | grep 3306
# 출력: 0.0.0.0:3306 확인

# 다른 서버에서 연결 테스트
mysql -h 10.0.1.214 -u mechuragi_user -p
```

---

### 1.2 MySQL 사용자 생성 실패 (auth_socket 문제)

**증상:**
```
Access denied for user 'root'@'localhost'
```

**원인:**
MySQL 8.0은 기본적으로 `auth_socket` 플러그인을 사용하여 root 사용자는 sudo 권한으로만 접근 가능

**해결 방법:**

모든 MySQL 명령어에 `sudo` 추가:

```yaml
- name: 애플리케이션 데이터베이스 생성
  shell: |
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS {{ mysql_database }};"

- name: 애플리케이션 사용자 생성 및 권한 부여 (VPC 내부)
  shell: |
    sudo mysql -e "CREATE USER IF NOT EXISTS '{{ mysql_app_user }}'@'10.0.%' IDENTIFIED BY '{{ mysql_app_password }}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON {{ mysql_database }}.* TO '{{ mysql_app_user }}'@'10.0.%';"

- name: 권한 플러시
  shell: sudo mysql -e "FLUSH PRIVILEGES;"
```

**검증:**
```bash
sudo mysql -e "SELECT user, host FROM mysql.user WHERE user='mechuragi_user';"
```

**출력 예시:**
```
+-----------------+--------+
| user            | host   |
+-----------------+--------+
| mechuragi_user  | 10.0.% |
+-----------------+--------+
```

---

### 1.3 MySQL Client 미설치

**증상:**
```
/bin/sh: 1: mysql: not found
```

**원인:**
Main Service 서버에서 MySQL 연결 테스트를 하려 했으나 `mysql-client`가 설치되어 있지 않음

**해결 방법:**

**파일:** `ansible/playbooks/test-connectivity.yml`

```yaml
- name: MySQL 클라이언트 설치 확인
  shell: which mysql
  register: mysql_client_check
  ignore_errors: yes

- name: MySQL 클라이언트 설치 (없는 경우)
  become: yes
  apt:
    name: mysql-client
    state: present
    update_cache: yes
  when: mysql_client_check.rc != 0
  ignore_errors: yes

- name: "→ MySQL 클라이언트 설치"
  debug:
    msg: "{{ '✅ 이미 설치됨' if mysql_client_check.rc == 0 else '✅ 설치 완료' }}"
```

**검증:**
```bash
which mysql
mysql --version
```

---

## 2. Docker 관련 문제

### 2.1 Docker 명령어 권한 부족

**증상:**
Ansible에서 `docker ps` 실행 시 아무 결과도 반환되지 않음, 하지만 SSH로 직접 접속해서 `sudo docker ps`를 하면 컨테이너가 정상 출력됨

**원인:**
Ansible이 사용하는 `ubuntu` 사용자는 Docker 소켓에 접근할 권한이 없음

**해결 방법:**

모든 Docker 명령어에 `sudo` 추가:

**파일:** `ansible/playbooks/test-connectivity.yml`

```yaml
- name: AI 서비스 컨테이너 실행 확인
  shell: sudo docker ps --filter "name=ai-service" --format "{{.Names}}\t{{.Status}}"
  register: ai_container
  ignore_errors: yes

- name: Main 서비스 컨테이너 실행 확인
  shell: sudo docker ps --filter "name=main-service" --format "{{.Names}}\t{{.Status}}"
  register: main_container
  ignore_errors: yes
```

**검증:**
```bash
# SSH 접속 후
docker ps  # 권한 에러 발생
sudo docker ps  # 정상 출력
```

---

### 2.2 Docker 컨테이너 이름 필터링 문제

**증상:**
```
TASK [→ Main 컨테이너 상태]
ok: [main-service-server] => {
    "msg": "❌ 컨테이너 없음"
}
```

하지만 실제로 SSH 접속하면 컨테이너가 실행 중

**원인:**
`--filter "name=main-service"` 필터가 실제 컨테이너 이름과 정확히 일치하지 않을 수 있음

**해결 방법:**

더 유연한 검색 방법 사용:

```yaml
- name: 모든 Docker 컨테이너 확인 (디버깅)
  shell: sudo docker ps --format "{{.Names}}\t{{.Status}}"
  register: all_containers
  ignore_errors: yes

- name: "→ 실행 중인 모든 컨테이너"
  debug:
    msg: "{{ all_containers.stdout_lines if all_containers.rc == 0 else '❌ 확인 불가' }}"

- name: Main 서비스 컨테이너 실행 확인
  shell: sudo docker ps | grep -i main || echo "not found"
  register: main_container
  ignore_errors: yes

- name: "→ Main 컨테이너 상태"
  debug:
    msg: "{{ main_container.stdout if 'not found' not in main_container.stdout else '❌ 컨테이너 없음' }}"
```

**장점:**
- 대소문자 구분 없이 검색 (`-i`)
- 'main'을 포함한 모든 컨테이너 이름 매칭 가능
- 먼저 모든 컨테이너를 출력하여 디버깅 용이

---

## 3. Ansible 관련 문제

### 3.1 Shell 명령어 결과가 "changed"만 표시

**증상:**
```
TASK [MySQL 리스닝 주소 확인]
changed: [mysql-server]
```

실제 명령어 출력 결과를 볼 수 없음

**원인:**
Ansible은 기본적으로 `changed` 상태만 표시하고 실제 stdout을 자동으로 출력하지 않음

**해결 방법:**

모든 shell 명령어 뒤에 즉시 debug 출력 추가:

```yaml
- name: MySQL 리스닝 주소 확인
  shell: ss -tlnp | grep 3306 | awk '{print $4}'
  register: mysql_listen
  ignore_errors: yes

- name: "→ 리스닝 주소 결과"
  debug:
    msg: "{{ mysql_listen.stdout_lines if mysql_listen.rc == 0 else '❌ 포트 3306 리스닝하지 않음' }}"
```

**패턴:**
1. Shell 명령 실행 → `register` 변수에 저장
2. 즉시 다음 태스크에서 `debug`로 결과 출력
3. 성공/실패 조건에 따라 다른 메시지 출력

---

### 3.2 Ansible 조건문 에러 (dict object has no attribute 'rc')

**증상:**
```
fatal: [localhost]: FAILED! => {"msg": "The conditional check 'cloudfront_detail is defined and cloudfront_detail.rc == 0' failed. The error was: error while evaluating conditional (cloudfront_detail is defined and cloudfront_detail.rc == 0): 'dict object' has no attribute 'rc'"}
```

**원인:**
`when` 조건에서 skip된 태스크의 경우 변수가 dict로 존재하지만 `rc` 속성이 없음

**해결 방법:**

`.rc` 확인 전에 반드시 `.rc is defined` 체크:

**잘못된 코드:**
```yaml
when: cloudfront_detail is defined and cloudfront_detail.rc == 0
```

**올바른 코드:**
```yaml
when: cloudfront_detail.rc is defined and cloudfront_detail.rc == 0
```

**모든 조건문 패턴:**
```yaml
# 변수 자체 존재 확인
when: variable_name is defined

# shell/command 결과 성공 확인
when: result.rc is defined and result.rc == 0

# 변수 값 확인
when: variable_name is defined and variable_name == 'value'

# stdout 확인
when: result.stdout is defined and 'text' in result.stdout
```

---

## 4. AWS 권한 관련 문제

### 4.1 AWS CLI 미설치

**증상:**
Security Group 확인 명령어 실패:
```
/bin/sh: 1: aws: not found
```

**해결 방법:**

**파일:** `ansible/playbooks/setup-basic-system.yml`

```yaml
tasks:
  - name: AWS CLI 설치 확인
    shell: which aws
    register: awscli_check
    ignore_errors: yes

  - name: AWS CLI 설치 (없는 경우)
    apt:
      name: awscli
      state: present
      update_cache: yes
    when: awscli_check.rc != 0
    register: awscli_install

  - name: AWS CLI 버전 확인
    shell: aws --version
    register: awscli_version
    ignore_errors: yes

  - name: AWS CLI 설치 결과
    debug:
      msg: |
        🔧 AWS CLI:
        {% if awscli_check.rc == 0 %}
        ✅ 이미 설치됨 - {{ awscli_version.stdout }}
        {% elif awscli_install is succeeded %}
        ✅ 설치 완료 - {{ awscli_version.stdout }}
        {% else %}
        ❌ 설치 실패
        {% endif %}
```

**검증:**
```bash
aws --version
```

---

### 4.2 EC2 인스턴스 IAM Role 권한 부족

**증상:**
Security Group 조회 실패:
```
An error occurred (UnauthorizedOperation) when calling the DescribeSecurityGroups operation
```

**원인:**
EC2 인스턴스에 `ec2:DescribeInstances`, `ec2:DescribeSecurityGroups` 권한이 없음

**해결 방법:**

#### 4.2.1 Main Service (SES Role에 권한 추가)

**파일:** `terraform/modules/ses/main.tf`

```hcl
# EC2 메타데이터 및 Security Group 조회 권한 (Ansible 테스트용)
data "aws_iam_policy_document" "ec2_describe_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_describe_policy" {
  name   = "${var.project_name}-${var.environment}-ec2-describe-policy"
  role   = aws_iam_role.ses_sending_role.id
  policy = data.aws_iam_policy_document.ec2_describe_policy.json
}
```

#### 4.2.2 AI Service (Bedrock Role에 권한 추가)

**파일:** `terraform/modules/bedrock/main.tf`

```hcl
# EC2 메타데이터 및 Security Group 조회 권한 (Ansible 테스트용)
data "aws_iam_policy_document" "ec2_describe_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_describe_policy" {
  name   = "${var.project_name}-${var.environment}-bedrock-ec2-describe-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.ec2_describe_policy.json
}
```

#### 4.2.3 MySQL & Redis (새로운 IAM Role 생성)

**파일:** `terraform/modules/compute/main.tf`

```hcl
# EC2 메타데이터 조회용 IAM Role (MySQL, Redis용)
resource "aws_iam_role" "ec2_describe_role" {
  name = "${var.project_name}-${var.environment}-ec2-describe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# EC2 메타데이터 및 Security Group 조회 권한
data "aws_iam_policy_document" "ec2_describe_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_describe_policy" {
  name   = "${var.project_name}-${var.environment}-ec2-describe-policy"
  role   = aws_iam_role.ec2_describe_role.id
  policy = data.aws_iam_policy_document.ec2_describe_policy.json
}

resource "aws_iam_instance_profile" "ec2_describe_profile" {
  name = "${var.project_name}-${var.environment}-ec2-describe-profile"
  role = aws_iam_role.ec2_describe_role.name
}

# MySQL 인스턴스에 연결
resource "aws_instance" "mysql" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.mysql_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = aws_iam_instance_profile.ec2_describe_profile.name
  # ...
}

# Redis 인스턴스에 연결
resource "aws_instance" "redis" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.redis_instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = aws_iam_instance_profile.ec2_describe_profile.name
  # ...
}
```

**적용:**
```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

**검증:**
```bash
# EC2 인스턴스에서
aws ec2 describe-instances --instance-ids $(ec2-metadata --instance-id | cut -d " " -f 2)
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

---

## 5. Nginx 관련 문제

### 5.1 Nginx 서비스 미설치

**증상:**
```
fatal: [main-service-server]: FAILED! => {"changed": false, "msg": "Could not find the requested service nginx: host"}
```

**원인:**
Nginx가 설치되어 있지 않은 상태에서 서비스 시작 시도

**해결 방법:**

**파일:** `ansible/playbooks/deploy-all-services.yml`

```yaml
# 3단계: Main Service - Nginx 설치 및 시작
- name: Main Service - Nginx 설치 및 시작
  hosts: main_service
  become: yes
  gather_facts: no
  tasks:
    - name: Nginx 패키지 설치
      apt:
        name: nginx
        state: present
        update_cache: yes
      register: nginx_install
      ignore_errors: yes

    - name: Nginx 서비스 시작 및 활성화
      systemd:
        name: nginx
        state: started
        enabled: yes
      register: nginx_start
      ignore_errors: yes

    - name: Nginx 서비스 상태 확인
      shell: systemctl is-active nginx
      register: nginx_status
      ignore_errors: yes

    - name: Nginx 포트 리스닝 확인
      shell: ss -tlnp | grep :80
      register: nginx_port
      ignore_errors: yes

# 4단계: AI Service - Nginx 설치 및 시작
- name: AI Service - Nginx 설치 및 시작
  hosts: ai_service
  become: yes
  gather_facts: no
  tasks:
    # (Main Service와 동일한 태스크)
```

**검증:**
```bash
systemctl status nginx
ss -tlnp | grep :80
curl localhost
```

---

## 6. CloudFront 관련 문제

### 6.1 CloudFront Distribution 조회 실패

**증상:**
```
TASK [→ CloudFront Distribution 조회]
ok: [localhost] => {
    "msg": []
}

TASK [→ Distribution ID]
ok: [localhost] => {
    "msg": "❌ 찾을 수 없음"
}
```

**원인:**
S3 버킷 기반 필터링 쿼리가 복잡하여 빈 결과 반환

**해결 방법:**

#### 6.1.1 CloudFront 정보를 Group Vars에 추가

**파일:** `ansible/group_vars/all/main.yml`

```yaml
# CloudFront 설정
wait_for_deployment: false
cloudfront_distribution_id: "E2055JLBFIVGCA"
cloudfront_domain_name: "d4pdjk57v9eg4.cloudfront.net"
```

#### 6.1.2 직접 Distribution ID 사용

**파일:** `ansible/playbooks/test-front.yml`

**변경 전:**
```yaml
- name: CloudFront Distribution 목록 조회
  shell: |
    aws cloudfront list-distributions --region us-east-1 --query "DistributionList.Items[?Origins.Items[?DomainName=='{{ s3_frontend_bucket }}.s3.{{ aws_region }}.amazonaws.com']].{ID:Id,DomainName:DomainName,Status:Status,Enabled:Enabled}" --output json 2>&1
  register: cloudfront_list
  ignore_errors: yes

- name: CloudFront Distribution ID 추출
  set_fact:
    cloudfront_id: "{{ (cloudfront_list.stdout | from_json)[0].ID }}"
  when: cloudfront_list.rc == 0 and (cloudfront_list.stdout | from_json | length > 0)
  ignore_errors: yes
```

**변경 후:**
```yaml
- name: CloudFront Distribution ID 설정
  set_fact:
    cloudfront_id: "{{ cloudfront_distribution_id }}"

- name: "→ Distribution ID"
  debug:
    msg: "✅ {{ cloudfront_id }}"

- name: CloudFront Distribution 존재 확인
  shell: aws cloudfront get-distribution --id {{ cloudfront_id }} --region us-east-1 --query "Distribution.{ID:Id,DomainName:DomainName,Status:Status}" --output json 2>&1
  register: cloudfront_check
  ignore_errors: yes

- name: "→ CloudFront 존재 확인"
  debug:
    msg: "{{ '✅ 존재함' if cloudfront_check.rc == 0 else '❌ 존재하지 않음: ' + cloudfront_check.stderr }}"
```

**장점:**
- 복잡한 필터링 쿼리 불필요
- group_vars에서 한 번만 정의
- 더 빠르고 확실한 조회

**검증:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test-front.yml
```

---

### 6.2 CloudFront 403 Forbidden Error

**증상:**
CloudFront 도메인(`mechuragi.kro.kr`)에 접속하면 403 에러 발생:

```
403 ERROR
The request could not be satisfied.
Bad request. We can't connect to the server for this app or website at this time.
There might be too much traffic or a configuration error.
```

**가능한 원인 및 해결 방법:**

#### 원인 1: S3 버킷에 파일이 없음

**확인:**
```bash
aws s3 ls s3://mechuragi-dev-frontend --recursive
```

**해결:**
S3 버킷에 최소한 `index.html` 파일이 있어야 함

```bash
# 테스트 파일 업로드
echo "<h1>Hello Mechuragi</h1>" > index.html
aws s3 cp index.html s3://mechuragi-dev-frontend/index.html
```

#### 원인 2: CloudFront Origin Access Control (OAC) 권한 문제

**확인:**
```bash
# CloudFront Distribution 설정 확인
aws cloudfront get-distribution-config --id E2055JLBFIVGCA --region us-east-1

# S3 버킷 정책 확인
aws s3api get-bucket-policy --bucket mechuragi-dev-frontend
```

**해결:**

S3 버킷 정책에 CloudFront OAC 접근 권한 추가 필요:

**Terraform 파일 확인:** `terraform/modules/s3/main.tf`

```hcl
# CloudFront Origin Access Control이 S3에 접근할 수 있도록 버킷 정책 설정
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.mechuragi_frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mechuragi_frontend_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}
```

#### 원인 3: CloudFront Default Root Object 설정 누락

**확인:**
```bash
aws cloudfront get-distribution-config --id E2055JLBFIVGCA --region us-east-1 | grep DefaultRootObject
```

**해결:**

**Terraform 파일 확인:** `terraform/modules/cloudfront/main.tf`

```hcl
resource "aws_cloudfront_distribution" "main_distribution" {
  # ...

  default_root_object = "index.html"  # 이 설정이 있어야 함

  # ...
}
```

#### 원인 4: S3 Public Access Block 설정

**확인:**
```bash
aws s3api get-public-access-block --bucket mechuragi-dev-frontend
```

**참고:**
CloudFront OAC를 사용하는 경우 S3 버킷은 Public Access를 막아도 됨.
하지만 버킷 정책이 올바르게 설정되어야 함.

#### 원인 5: CloudFront Cache가 에러를 캐싱

**해결:**
CloudFront Invalidation 생성:

```bash
# 모든 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E2055JLBFIVGCA \
  --paths "/*"
```

**Invalidation 상태 확인:**
```bash
aws cloudfront list-invalidations --distribution-id E2055JLBFIVGCA
```

#### 종합 해결 순서:

1. **S3 버킷에 파일 확인:**
   ```bash
   aws s3 ls s3://mechuragi-dev-frontend/
   ```

2. **없으면 테스트 파일 업로드:**
   ```bash
   echo "<h1>Mechuragi Frontend</h1>" > index.html
   aws s3 cp index.html s3://mechuragi-dev-frontend/index.html
   ```

3. **S3 버킷 정책 확인 및 수정 (Terraform):**
   ```bash
   cd terraform/environments/dev
   terraform plan -target=module.s3
   terraform apply -target=module.s3
   ```

4. **CloudFront 설정 확인 및 수정 (Terraform):**
   ```bash
   terraform plan -target=module.cloudfront
   terraform apply -target=module.cloudfront
   ```

5. **CloudFront 캐시 무효화:**
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id E2055JLBFIVGCA \
     --paths "/*"
   ```

6. **5-10분 대기 후 재확인:**
   ```bash
   curl -I https://mechuragi.kro.kr
   ```

#### 디버깅 명령어:

```bash
# CloudFront 에러 로그 확인 (CloudWatch Logs)
# 먼저 CloudFront Logging이 활성화되어 있어야 함

# S3 버킷 내용 확인
aws s3 ls s3://mechuragi-dev-frontend/ --recursive

# CloudFront Distribution 전체 설정 확인
aws cloudfront get-distribution --id E2055JLBFIVGCA --region us-east-1

# S3에서 직접 파일 다운로드 테스트 (CloudFront 우회)
aws s3 cp s3://mechuragi-dev-frontend/index.html -

# CloudFront를 통한 접근 테스트 (상세 헤더 확인)
curl -I https://d4pdjk57v9eg4.cloudfront.net
curl -I https://mechuragi.kro.kr
```

#### 예상 결과 (정상):

```bash
$ curl -I https://mechuragi.kro.kr
HTTP/2 200
content-type: text/html
content-length: 28
date: Mon, 28 Oct 2025 12:00:00 GMT
last-modified: Mon, 28 Oct 2025 11:00:00 GMT
etag: "xxxxx"
accept-ranges: bytes
server: AmazonS3
x-cache: Hit from cloudfront
via: 1.1 xxxxx.cloudfront.net (CloudFront)
x-amz-cf-pop: ICN54-C1
x-amz-cf-id: xxxxx
```

**주요 체크 포인트:**
- HTTP 상태 코드: `200` (정상) vs `403` (권한 문제)
- `x-cache` 헤더: `Hit from cloudfront` (캐시됨) vs `Miss from cloudfront` (캐시 없음)
- `server` 헤더: `AmazonS3` (S3 Origin)

---

### 6.3 Nginx가 프론트엔드 요청을 가로채는 문제

**증상:**
- CloudFront에서 정상적으로 S3 Origin이 설정되어 있음
- Nginx를 EC2에 설치한 후 갑자기 CloudFront 403 에러 발생
- Nginx가 모든 경로(`/`)를 backend로 프록시하여 프론트엔드 요청까지 처리

**원인:**
Nginx 설정의 `location /` 블록이 모든 요청을 Spring Boot backend로 프록시하고 있어서, CloudFront에서 S3로 가야 할 프론트엔드 요청까지 Nginx가 처리하려고 시도

**잘못된 Nginx 설정:**
```nginx
# 문제 있는 설정
location / {
    proxy_pass http://backend/;
    proxy_set_header Host $host;
    # ... 기타 프록시 설정
}
```

이 설정은 다음 문제를 야기:
- `/` 요청 → Nginx → backend (❌ S3로 가야 함)
- `/index.html` 요청 → Nginx → backend (❌ S3로 가야 함)
- `/api/users` 요청 → Nginx → backend (✅ 올바름)

**해결 방법:**

#### 아키텍처 이해:
```
사용자 요청
    ↓
CloudFront Distribution (mechuragi.kro.kr)
    ├─ /api/*     → EC2 (Nginx) → Spring Boot (Origin: mechuragi.kro.kr)
    ├─ /images/*  → S3 Images Bucket
    └─ /*         → S3 Frontend Bucket (index.html, static files)
```

**프론트엔드는 CloudFront → S3에서 제공**
**백엔드 API만 CloudFront → EC2 Nginx → Spring Boot에서 처리**

#### Nginx 설정 수정:

**파일:** `ansible/roles/nginx/templates/nginx-main-service.conf.j2`

**변경 전:**
```nginx
# 기본 경로 - 모든 요청을 backend로 프록시 (문제!)
location / {
    proxy_pass http://backend/;
    proxy_set_header Host $host;
    # ...
}
```

**변경 후:**
```nginx
# 기본 경로 - 프론트엔드는 CloudFront/S3에서 제공되므로 404 응답
# Nginx는 오직 /api/* 경로만 처리
location / {
    access_log off;
    return 404 "This server only handles /api/* requests. Frontend is served via CloudFront.\n";
    add_header Content-Type text/plain;
}
```

#### 최종 Nginx 설정:

**Main Service** (`nginx-main-service.conf.j2`):
```nginx
upstream backend {
    server 127.0.0.1:{{ main_service_port }} max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name {{ ansible_host }} _;

    # Nginx 자체 헬스체크
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # ✅ API 요청만 Spring Boot로 프록시
    location /api/ {
        proxy_pass http://backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # ... CORS 및 타임아웃 설정
    }

    # ✅ Actuator 헬스체크
    location /actuator/health {
        proxy_pass http://backend/actuator/health;
        # ... 헤더 설정
    }

    # ✅ Actuator 엔드포인트 (VPC 내부만 접근)
    location /actuator/ {
        proxy_pass http://backend/actuator/;
        allow 10.0.0.0/16;  # VPC 내부만
        allow 127.0.0.1;
        deny all;
    }

    # ❌ 기타 모든 경로 - 404 응답 (CloudFront → S3에서 처리)
    location / {
        access_log off;
        return 404 "This server only handles /api/* requests. Frontend is served via CloudFront.\n";
        add_header Content-Type text/plain;
    }
}
```

**AI Service** (`nginx-ai-service.conf.j2`):
```nginx
# Main Service와 동일한 구조
upstream ai_backend {
    server 127.0.0.1:{{ ai_service_port }} max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    # ... (Main Service와 동일한 location 블록들)
}
```

#### 배포 방법:

**1. Nginx 설정 파일 수정:**
```bash
# Main Service
vi ansible/roles/nginx/templates/nginx-main-service.conf.j2

# AI Service
vi ansible/roles/nginx/templates/nginx-ai-service.conf.j2
```

**2. Playbook에 설정 배포 태스크 추가:**

**파일:** `ansible/playbooks/deploy-all-services.yml`

```yaml
# 3단계: Main Service - Nginx 설치 및 시작
- name: Main Service - Nginx 설치 및 시작
  hosts: main_service
  become: yes
  gather_facts: no
  vars_files:
    - ../group_vars/all/main.yml
  tasks:
    - name: Nginx 패키지 설치
      apt:
        name: nginx
        state: present
        update_cache: yes

    - name: Nginx 서비스 시작 및 활성화
      systemd:
        name: nginx
        state: started
        enabled: yes

    # ✅ 설정 파일 배포
    - name: Nginx 설정 파일 배포 (API만 처리)
      template:
        src: ../roles/nginx/templates/nginx-main-service.conf.j2
        dest: /etc/nginx/sites-available/main-service
        backup: yes
      register: nginx_config

    - name: 기본 Nginx 사이트 비활성화
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent

    - name: Nginx 사이트 활성화
      file:
        src: /etc/nginx/sites-available/main-service
        dest: /etc/nginx/sites-enabled/main-service
        state: link

    - name: Nginx 설정 테스트
      command: nginx -t
      register: nginx_test
      ignore_errors: yes

    # ✅ 설정 변경 시 재시작
    - name: Nginx 재시작 (설정 변경 시)
      systemd:
        name: nginx
        state: restarted
      when: nginx_config.changed and nginx_test.rc == 0
```

**3. 배포 실행:**
```bash
cd /home/jina/mechuragi-infra/ansible

# 전체 인프라 배포 (Nginx 포함)
ansible-playbook -i inventory/hosts.yml playbooks/deploy-all-services.yml
```

**4. 검증:**
```bash
# Main Service 서버에서
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@<main-service-ip>

# Nginx 설정 확인
sudo cat /etc/nginx/sites-available/main-service

# Nginx 설정 테스트
sudo nginx -t

# Nginx 상태 확인
sudo systemctl status nginx

# 로컬에서 테스트
curl localhost/               # 404 응답 (예상됨)
curl localhost/api/           # Spring Boot API 응답
curl localhost/nginx-health   # "healthy" 응답

# CloudFront를 통한 테스트
curl https://mechuragi.kro.kr/                  # S3 index.html (200)
curl https://mechuragi.kro.kr/api/actuator/health  # Spring Boot API (200)
```

#### 요청 흐름 정리:

**프론트엔드 요청:**
```
https://mechuragi.kro.kr/
    ↓
CloudFront (mechuragi.kro.kr)
    ↓
S3 Frontend Bucket (mechuragi-dev-frontend)
    ↓
index.html 반환 (200 OK)
```

**API 요청:**
```
https://mechuragi.kro.kr/api/users
    ↓
CloudFront (mechuragi.kro.kr)
    ↓ (path: /api/*)
EC2 Main Service (mechuragi.kro.kr:80)
    ↓
Nginx (location /api/)
    ↓
Spring Boot (localhost:8080)
    ↓
API 응답 반환
```

**이미지 요청:**
```
https://mechuragi.kro.kr/images/profile.jpg
    ↓
CloudFront (mechuragi.kro.kr)
    ↓ (path: /images/*)
S3 Images Bucket (mechuragi-dev-images)
    ↓
이미지 파일 반환 (200 OK)
```

#### 핵심 원칙:

1. **CloudFront가 라우팅 담당:**
   - `/*` → S3 Frontend Bucket
   - `/images/*` → S3 Images Bucket
   - `/api/*` → EC2 Nginx

2. **Nginx는 API만 처리:**
   - `/api/*` → Spring Boot로 프록시
   - `/actuator/*` → 모니터링 (VPC 내부만)
   - 기타 경로 → 404 (CloudFront → S3로 가야 함)

3. **프론트엔드는 절대 EC2/Nginx를 거치지 않음:**
   - React 빌드 파일 → S3에 업로드
   - CloudFront → S3에서 직접 제공
   - Nginx는 관여하지 않음

#### 참고 사항:

- **S3 버킷에 index.html이 없으면 여전히 403 발생**
  ```bash
  # S3 버킷 확인
  aws s3 ls s3://mechuragi-dev-frontend/

  # 없으면 테스트 파일 업로드
  echo "<h1>Mechuragi Frontend</h1>" > index.html
  aws s3 cp index.html s3://mechuragi-dev-frontend/index.html

  # CloudFront 캐시 무효화
  aws cloudfront create-invalidation \
    --distribution-id E2055JLBFIVGCA \
    --paths "/*"
  ```

- **Nginx 로그 확인:**
  ```bash
  # Main Service
  sudo tail -f /var/log/nginx/main_service_access.log
  sudo tail -f /var/log/nginx/main_service_error.log

  # AI Service
  sudo tail -f /var/log/nginx/ai_service_access.log
  sudo tail -f /var/log/nginx/ai_service_error.log
  ```

---

### 6.4 CloudFront API Origin 잘못된 설정 (순환 참조)

**증상:**
- CloudFront가 배포되었지만 API 요청(`/api/*`)이 제대로 작동하지 않음
- 프론트엔드는 S3에서 정상 제공되지만 API 호출 실패
- CloudFront가 자기 자신 또는 잘못된 포트로 요청을 보냄

**원인:**
CloudFront의 API origin 설정이 잘못되어 있음:

1. **순환 참조**: `domain_name = "mechuragi.kro.kr"` (CloudFront 자신을 가리킴)
2. **잘못된 포트**: `http_port = 8080` (Nginx는 80번 포트 사용)

**잘못된 Terraform 설정:**

```hcl
# terraform/modules/cloudfront/main.tf
origin {
  domain_name = var.web_domain  # "mechuragi.kro.kr" - 순환 참조!
  origin_id   = "api-origin"

  custom_origin_config {
    http_port              = 8080  # Nginx는 80번 포트인데 8080으로 설정!
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
```

**문제점:**
```
CloudFront (mechuragi.kro.kr) /api/* 요청
    ↓
mechuragi.kro.kr:8080 (CloudFront 자신 또는 존재하지 않는 포트)
    ↓
❌ 연결 실패 또는 무한 루프
```

**올바른 아키텍처:**
```
CloudFront (mechuragi.kro.kr) /api/* 요청
    ↓
EC2 Public DNS:80 (ec2-X-X-X-X.ap-northeast-2.compute.amazonaws.com)
    ↓
Nginx (포트 80)
    ↓
Spring Boot (localhost:8080)
    ↓
✅ API 응답
```

**해결 방법:**

#### 1단계: Compute 모듈에 Public DNS 출력 추가

**파일:** `terraform/modules/compute/outputs.tf`

```hcl
output "main_service_public_dns" {
  description = "Public DNS name of the main service instance"
  value       = aws_instance.main_service.public_dns
}
```

#### 2단계: CloudFront 모듈에 변수 추가

**파일:** `terraform/modules/cloudfront/variables.tf`

```hcl
variable "main_service_public_dns" {
  description = "Public DNS name of the main service EC2 instance (e.g., ec2-X-X-X-X.ap-northeast-2.compute.amazonaws.com)"
  type        = string
}
```

#### 3단계: API Origin 설정 수정

**파일:** `terraform/modules/cloudfront/main.tf`

**변경 전:**
```hcl
# Spring Boot API 서버 오리진
origin {
  domain_name = var.web_domain  # ❌ "mechuragi.kro.kr" - 잘못됨!
  origin_id   = "api-origin"

  custom_origin_config {
    http_port              = 8080  # ❌ Nginx는 80번 포트
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
```

**변경 후:**
```hcl
# Spring Boot API 서버 오리진 (Nginx → Spring Boot)
origin {
  domain_name = var.main_service_public_dns  # ✅ EC2 Public DNS
  origin_id   = "api-origin"

  custom_origin_config {
    http_port              = 80   # ✅ Nginx는 80번 포트에서 리스닝
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
```

**중요:** CloudFront는 origin domain_name에 IP 주소를 직접 사용할 수 없습니다. EC2의 Public DNS Name(`ec2-X-X-X-X.ap-northeast-2.compute.amazonaws.com`)을 사용해야 합니다.

#### 4단계: 환경 설정에 Public DNS 전달

**파일:** `terraform/environments/dev/main.tf`

```hcl
# CloudFront 모듈 호출
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name                      = var.project_name
  environment                       = var.environment
  s3_frontend_bucket_name           = module.s3.s3_frontend_bucket_name
  s3_frontend_bucket_domain_name    = module.s3.s3_frontend_bucket_domain_name
  s3_frontend_bucket_arn            = module.s3.s3_frontend_bucket_arn
  s3_images_bucket_name             = module.s3.s3_images_bucket_name
  s3_images_bucket_domain_name      = module.s3.s3_images_bucket_domain_name
  s3_images_bucket_arn              = module.s3.s3_images_bucket_arn
  main_service_public_dns           = module.compute.main_service_public_dns  # ✅ 추가
  domain_name                       = var.domain_name
  acm_certificate_arn               = module.acm_certificate.certificate_arn
  use_custom_domain                 = var.use_custom_domain
}
```

#### 5단계: Terraform 적용

```bash
cd /home/jina/mechuragi-infra/terraform/environments/dev

# 변경사항 확인
terraform plan

# 주요 변경사항:
# ~ update in-place
# CloudFront Distribution (main_distribution)
#   ~ origin {
#       ~ domain_name: "mechuragi.kro.kr" → "ec2-15-165-136-100.ap-northeast-2.compute.amazonaws.com"
#       ~ custom_origin_config {
#           ~ http_port: 8080 → 80
#         }
#     }

# 적용
terraform apply

# CloudFront 배포 대기 (약 5-10분)
# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E2055JLBFIVGCA \
  --paths "/*"
```

#### 6단계: 검증

**CloudFront Distribution 설정 확인:**
```bash
aws cloudfront get-distribution-config \
  --id E2055JLBFIVGCA \
  --query 'DistributionConfig.Origins.Items[?Id==`api-origin`]' \
  --output json
```

**예상 출력:**
```json
[
  {
    "Id": "api-origin",
    "DomainName": "ec2-15-165-136-100.ap-northeast-2.compute.amazonaws.com",
    "CustomOriginConfig": {
      "HTTPPort": 80,
      "HTTPSPort": 443,
      "OriginProtocolPolicy": "http-only"
    }
  }
]
```

**참고:** DomainName은 EC2의 Public DNS Name입니다. IP 주소가 아닙니다!

**Main Service Nginx 확인:**
```bash
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@<main-service-ip>

# Nginx 상태 확인
sudo systemctl status nginx

# Nginx 포트 리스닝 확인
sudo ss -tlnp | grep :80

# Nginx 헬스체크
curl localhost/nginx-health
# 출력: healthy

# Spring Boot 헬스체크 (Nginx를 통해)
curl localhost/api/actuator/health
# 출력: {"status":"UP"}
```

**CloudFront를 통한 접근 테스트:**
```bash
# 프론트엔드 (S3)
curl -I https://mechuragi.kro.kr/
# HTTP/2 200
# x-cache: Hit from cloudfront
# server: AmazonS3

# API (EC2 Nginx → Spring Boot)
curl https://mechuragi.kro.kr/api/actuator/health
# {"status":"UP"}

# 이미지 (S3 Images Bucket)
curl -I https://mechuragi.kro.kr/images/test.jpg
# HTTP/2 200 또는 404 (파일 존재 여부)
# x-cache: Hit from cloudfront
```

#### 최종 아키텍처:

```
사용자 (https://mechuragi.kro.kr)
    ↓
CloudFront Distribution
    │
    ├─ /*
    │   ↓
    │  S3 Frontend Bucket (index.html, static files)
    │   ↓
    │  React 프론트엔드 ✅
    │
    ├─ /images/*
    │   ↓
    │  S3 Images Bucket (이미지 파일)
    │   ↓
    │  이미지 제공 ✅
    │
    └─ /api/*
        ↓
       EC2 Main Service (Public IP:80)
        ↓
       Nginx (listen 80)
        ├─ /api/ → proxy_pass http://localhost:8080
        ├─ /actuator/health → proxy_pass http://localhost:8080/actuator/health
        └─ / → return 404 (CloudFront에서 S3로 처리)
        ↓
       Spring Boot (localhost:8080)
        ↓
       API 응답 ✅
```

#### 핵심 포인트:

1. **CloudFront는 라우팅만 담당**
   - `/*` → S3 Frontend
   - `/images/*` → S3 Images
   - `/api/*` → EC2 Nginx

2. **Nginx는 API 프록시만 담당**
   - 80번 포트 리스닝
   - `/api/*` → Spring Boot (8080)로 프록시
   - 프론트엔드는 처리하지 않음 (404 반환)

3. **순환 참조 방지**
   - CloudFront origin은 **EC2 Public DNS** 사용 (`ec2-X-X-X-X.ap-northeast-2.compute.amazonaws.com`)
   - CloudFront 도메인(`mechuragi.kro.kr`)이 아님
   - IP 주소를 직접 사용할 수 없음 (CloudFront 제한)

4. **포트 매핑**
   - CloudFront → EC2: 80번 포트
   - Nginx → Spring Boot: 8080번 포트

#### 주의 사항:

**EC2 재시작 시:**
```bash
# EC2 인스턴스를 중지/시작하면:
# 1. Public IP는 Elastic IP로 고정되어 있어 변경되지 않음
# 2. Public DNS는 자동으로 업데이트됨 (ec2-X-X-X-X... 형식 유지)

# Terraform에서 Elastic IP 사용 중:
# terraform/modules/compute/main.tf 참조:
resource "aws_eip" "main_service" {
  instance = aws_instance.main_service.id
  domain   = "vpc"
}

# Elastic IP가 할당되면 Public DNS도 고정됨
# 따라서 EC2 재시작해도 CloudFront 설정 변경 불필요
```

**Nginx 설정 변경 시:**
```bash
# Nginx 설정 변경 후
sudo nginx -t
sudo systemctl reload nginx

# CloudFront 캐시 무효화 필요 없음 (origin 설정만 올바르면 됨)
```

**Spring Boot 포트 변경 시:**
```bash
# application.yml에서 server.port 변경 시
# Nginx upstream backend 설정도 함께 변경 필요

# ansible/roles/nginx/templates/nginx-main-service.conf.j2
upstream backend {
    server 127.0.0.1:{{ main_service_port }} max_fails=3 fail_timeout=30s;
}
```

---

## 공통 트러블슈팅 팁

### 1. Ansible 디버깅

**유용한 명령어:**
```bash
# 상세 출력 (-v ~ -vvvv)
ansible-playbook -i inventory/hosts.yml playbooks/test.yml -v

# 특정 호스트만 실행
ansible-playbook -i inventory/hosts.yml playbooks/test.yml --limit main-service-server

# 특정 태스크부터 시작
ansible-playbook -i inventory/hosts.yml playbooks/test.yml --start-at-task="MySQL 설치"

# Dry-run (실제 변경 없이 테스트)
ansible-playbook -i inventory/hosts.yml playbooks/test.yml --check
```

### 2. MySQL 디버깅

**유용한 명령어:**
```bash
# MySQL 서비스 상태
sudo systemctl status mysql

# MySQL 리스닝 확인
ss -tlnp | grep 3306
netstat -tlnp | grep 3306

# MySQL 설정 확인
grep -r "bind-address" /etc/mysql/
cat /etc/mysql/mysql.conf.d/mechuragi.cnf

# MySQL 사용자 확인
sudo mysql -e "SELECT user, host FROM mysql.user;"

# MySQL 권한 확인
sudo mysql -e "SHOW GRANTS FOR 'mechuragi_user'@'10.0.%';"

# MySQL 연결 테스트
mysql -h <IP> -u <USER> -p -e "SELECT 1;"
```

### 3. Docker 디버깅

**유용한 명령어:**
```bash
# 실행 중인 컨테이너
sudo docker ps

# 모든 컨테이너 (중단된 것 포함)
sudo docker ps -a

# 컨테이너 로그
sudo docker logs <container_name>
sudo docker logs -f <container_name>  # 실시간 로그

# 컨테이너 내부 접속
sudo docker exec -it <container_name> /bin/bash

# 컨테이너 상세 정보
sudo docker inspect <container_name>

# Docker 네트워크 확인
sudo docker network ls
sudo docker network inspect bridge
```

### 4. 네트워크 디버깅

**유용한 명령어:**
```bash
# 포트 리스닝 확인
ss -tlnp | grep <PORT>
netstat -tlnp | grep <PORT>
lsof -i :<PORT>

# 연결 테스트
telnet <IP> <PORT>
nc -zv <IP> <PORT>
curl -v http://<IP>:<PORT>

# Ping 테스트
ping -c 4 <IP>

# 방화벽 확인
sudo ufw status
sudo iptables -L -n
```

### 5. AWS CLI 디버깅

**유용한 명령어:**
```bash
# IAM Role 확인
aws sts get-caller-identity

# EC2 인스턴스 정보
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/

# Security Group 확인
aws ec2 describe-security-groups --group-ids <SG_ID>

# S3 버킷 확인
aws s3 ls
aws s3 ls s3://<BUCKET_NAME>

# CloudFront Distribution 확인
aws cloudfront list-distributions
aws cloudfront get-distribution --id <DISTRIBUTION_ID>
```

---

## 참고 자료

- [VPC 내부 연결성 가이드](./vpc-internal-connectivity.md)
- [Ansible Playbooks 문서](../ansible/playbooks/)
- [Terraform Modules 문서](../terraform/modules/)
- MySQL 공식 문서: https://dev.mysql.com/doc/
- Docker 공식 문서: https://docs.docker.com/
- Ansible 공식 문서: https://docs.ansible.com/
- AWS CLI 공식 문서: https://docs.aws.amazon.com/cli/

---

## 버전 정보

- **작성일:** 2025-10-28
- **프로젝트:** 메추라기 (mechuragi)
- **환경:** Development (dev)
- **리전:** ap-northeast-2

## 변경 이력

| 날짜 | 내용 | 작성자 |
|------|------|--------|
| 2025-10-28 | 초기 작성 - 인프라 구축 중 발생한 모든 트러블슈팅 내용 정리 | Claude Code |
| 2025-10-28 | CloudFront API Origin 순환 참조 문제 추가 (섹션 6.4) | Claude Code |
