# Ansible 서버 구성 가이드

메추라기 통합 인프라의 서버 자동 구성을 담당하는 Ansible 저장소입니다. 3개 서버(API Gateway, 통합 메인 서버, AI 서비스)의 초기 설정을 자동화합니다.

## 개요

Terraform으로 인프라를 프로비저닝한 후, Ansible로 각 서버의 소프트웨어 스택을 구성합니다.

### 주요 특징
- Roles 없이 4개의 플레이북으로 구성된 단순한 구조
- 기본 패키지, Docker, OpenResty Gateway, NAT 자동 구성
- Private Subnet 서버는 Bastion Host(Gateway)를 통한 SSH 접근
- `group_vars`를 통한 변수 중앙 관리

### 설치되는 항목
- **모든 서버**: 기본 패키지, AWS CLI v2, Docker CE + Compose
- **API Gateway**: OpenResty(Lua 기반 JWT 인증), NAT, CloudWatch Agent, S3 로그 백업

## 디렉토리 구조

```
ansible/
├── ansible.cfg                         # Ansible 설정
├── group_vars/
│   └── all/
│       └── main.yml                   # 전역 변수 (IP, 포트, 서비스 설정 등)
├── inventory/
│   └── hosts.yml                      # 3개 서버 인벤토리
├── playbooks/
│   ├── site.yml                       # 메인 오케스트레이션 (전체 실행)
│   ├── common.yml                     # 공통 시스템 설정
│   ├── docker.yml                     # Docker 설치
│   └── nginx-gateway.yml             # OpenResty Gateway + NAT + 모니터링
└── templates/
    ├── nginx.conf.j2                  # OpenResty 설정 (리버스 프록시 + JWT 인증)
    ├── cloudwatch-agent-config.json.j2 # CloudWatch Agent 설정
    └── s3-log-backup.sh.j2           # S3 로그 백업 스크립트
```

## Playbooks 설명

### site.yml - 메인 오케스트레이션

모든 초기 설정을 한 번에 실행하는 마스터 플레이북입니다.

**실행 순서:**
1. `common.yml` - 모든 서버에 기본 패키지 설치
2. `docker.yml` - 모든 서버에 Docker 설치
3. `nginx-gateway.yml` - API Gateway에 OpenResty + NAT + 모니터링 설정

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

---

### common.yml - 공통 시스템 설정

모든 서버의 기본 시스템 설정을 담당합니다.

**주요 작업:**
- apt 패키지 관리자 잠금 대기 (부팅 시 자동 업데이트 충돌 방지)
- 기본 패키지 설치 (curl, wget, git, vim, htop, net-tools, jq 등)
- 시간대 설정 (Asia/Seoul), 로케일 설정 (en_US.UTF-8)
- 애플리케이션 디렉토리 생성
- AWS CLI v2 설치

**대상:** 모든 서버 (all)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/common.yml
```

---

### docker.yml - Docker 설치

Docker CE와 Docker Compose Plugin을 설치합니다.

**주요 작업:**
- 기존 Docker 버전 제거
- Docker 공식 GPG 키 및 저장소 추가
- Docker CE, CLI, Containerd, Compose Plugin 설치
- Docker 그룹에 사용자 추가 및 서비스 활성화
- hello-world 컨테이너로 설치 검증

**대상:** 모든 서버 (all)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/docker.yml
```

---

### nginx-gateway.yml - OpenResty Gateway + NAT + 모니터링

API Gateway 서버에 OpenResty와 부가 기능을 설정합니다.

**대상:** API Gateway만 (nginx_gateway)

#### 1. OpenResty 설치
- OpenResty 패키지 설치 (GPG 키 검증)
- lua-resty-hmac, lua-resty-jwt 라이브러리 설치
- `nginx.conf.j2` 템플릿 배포

#### 2. 서비스 설정
- systemd 서비스 등록 (환경변수로 JWT Secret 주입)
- 설정 검증 후 서비스 시작

#### 3. NAT 설정
- IP 포워딩 활성화 (`net.ipv4.ip_forward = 1`)
- iptables MASQUERADE 규칙 설정 및 영구 저장
- Private Subnet 서버의 인터넷 연결 제공

#### 4. 로그 관리
- logrotate 설정 (일별 로테이션, 30일 보관, 압축)
- CloudWatch Agent 설치 및 로그 수집 설정
- S3 로그 백업 스크립트 배포 (매일 02:00 cron, 30일 이상 로컬 로그 자동 삭제)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/nginx-gateway.yml
```

## Templates 설명

### nginx.conf.j2 - OpenResty 설정

API Gateway의 리버스 프록시 및 인증 설정입니다.

**라우팅 규칙:**

| 경로 | 대상 | 설명 |
|------|------|------|
| `/api/*` | Main Server | Spring Security에서 인증 처리, SSE 스트리밍 지원 |
| `/actuator/*` | Main Server | 헬스체크 및 모니터링 |
| `/oauth2/authorization/*` | Main Server | OAuth 로그인 요청 (HTTPS 헤더 포워딩) |
| `/login/oauth2/*` | Main Server | OAuth 콜백 처리 |
| `/oauth2/callback` | CloudFront | SPA 라우팅을 위한 리다이렉트 |
| `/recommend/food` | AI Server | Lua 기반 JWT 검증 후 프록시 |
| `/` | Main Server | 기본 프록시 |
| `/nginx-health` | - | Gateway 자체 헬스체크 |

**주요 기능:**
- **JWT 인증**: `/recommend/food` 경로에서 Lua로 JWT 토큰 검증 (환경변수 → 공유 메모리 캐싱)
- **SSE 스트리밍**: `proxy_buffering off`, 300초 read timeout으로 실시간 이벤트 지원
- **Blue-Green 배포**: upstream 포트를 변수로 관리하여 무중단 배포 지원

### cloudwatch-agent-config.json.j2

- OpenResty access/error 로그를 CloudWatch Logs로 수집
- 60초 간격 메트릭 수집, 30일 보관

### s3-log-backup.sh.j2

- 압축된 로그 파일을 날짜별로 S3에 업로드
- 30일 이상 된 로컬 로그 자동 삭제

## 사용 가이드

### 사전 준비

1. **Terraform으로 인프라 프로비저닝**
   ```bash
   cd ../terraform/environments/dev
   terraform apply
   terraform output  # IP 주소 확인
   ```

2. **인벤토리 파일 설정** - Terraform output의 IP 주소를 `inventory/hosts.yml`에 입력

3. **SSH 키 권한 설정**
   ```bash
   chmod 400 <SSH_KEY_PATH>
   ```

4. **연결 테스트**
   ```bash
   ansible all -i inventory/hosts.yml -m ping
   ```

### 실행 방법

```bash
# 전체 인프라 초기 설정
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# 특정 호스트만 대상
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit nginx_gateway
ansible-playbook -i inventory/hosts.yml playbooks/common.yml --limit main_service

# 변수 오버라이드
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -e "app_user=admin"

# 드라이런 (변경사항 미리보기)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check

# 상세 로그 출력
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -vvv
```

### 설치 완료 후 다음 단계 (수동)

1. Main Service에 docker-compose.yml 배포 (MySQL + Redis + API)
2. AI Service에 docker-compose.yml 배포

## 모니터링 및 검증

```bash
# 모든 서버 Ping 테스트
ansible all -i inventory/hosts.yml -m ping

# Docker 상태 확인
ansible all -i inventory/hosts.yml -m shell \
  -a "docker --version && docker compose version" --become

# OpenResty 상태 확인 (Gateway만)
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "systemctl status openresty" --become

# NAT 설정 확인 (Gateway만)
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "sysctl net.ipv4.ip_forward" --become

# Private Subnet 서버의 인터넷 연결 확인
ansible main_service,ai_service -i inventory/hosts.yml -m shell \
  -a "curl -I https://www.google.com" --become

# CloudWatch Agent 상태 확인
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status" --become
```

## 관련 문서

- [메인 README](../README.md): 전체 인프라 개요
- [Terraform 가이드](../terraform/README.md): 인프라 프로비저닝
