# Ansible 서버 구성 가이드

메추라기 분산 인프라의 서버 자동 구성을 담당하는 Ansible 저장소입니다. MySQL, Redis, Nginx 등의 핵심 서비스를 자동으로 설치하고 설정합니다.

## 📋 개요

이 Ansible 구성은 4개의 분산 서버(메인 서비스, AI 서비스, MySQL, Redis)를 자동으로 설정합니다. Terraform으로 인프라를 프로비저닝한 후 Ansible로 각 서버의 소프트웨어 스택을 구성합니다.

### 주요 특징
- ✅ **Role 기반 구조**: 재사용 가능한 모듈형 설계
- ✅ **자동화된 설치**: MySQL, Redis, Docker, Nginx 자동 설치 및 설정
- ✅ **자동 검증**: 각 서비스 설치 후 연결성 및 상태 자동 확인
- ✅ **VPC 최적화**: 내부 통신 설정 (MySQL, Redis)
- ✅ **변수 중앙 관리**: group_vars를 통한 통합 변수 관리

## 📁 디렉토리 구조

```
ansible/
├── README.md                       # 이 가이드 파일
├── ansible.cfg                     # Ansible 설정
├── group_vars/                     # 🌐 변수 관리
│   └── all/
│       └── main.yml               # 전역 변수
├── inventory/                      # 📦 서버 인벤토리
│   └── hosts.yml                  # 서버 목록 및 그룹
├── roles/                          # 🎭 서비스별 Role
│   ├── common/                    # 기본 시스템 설정
│   │   ├── defaults/              # 기본 변수
│   │   └── tasks/                 # 실행 태스크
│   ├── docker/                    # Docker 환경
│   │   ├── defaults/
│   │   ├── handlers/              # 서비스 재시작 핸들러
│   │   └── tasks/
│   ├── mysql/                     # MySQL 데이터베이스
│   │   ├── defaults/
│   │   ├── files/                 # 설정 파일
│   │   ├── handlers/
│   │   ├── tasks/
│   │   └── templates/             # Jinja2 템플릿
│   ├── redis/                     # Redis 캐시
│   │   ├── defaults/
│   │   ├── files/
│   │   ├── handlers/
│   │   ├── tasks/
│   │   └── templates/
│   └── nginx/                     # Nginx 템플릿
│       └── templates/             # Nginx 설정 템플릿
└── playbooks/                      # 📖 실행 플레이북
    ├── setup/                     # 🔧 설치 및 구성
    │   ├── deploy-all-services.yml    # 🚀 전체 인프라 배포
    │   ├── setup-basic-system.yml     # 기본 시스템 설정
    │   ├── setup-database.yml         # MySQL 설치
    │   ├── setup-cache.yml            # Redis 설치
    │   ├── setup-docker-only.yml      # Docker 설치
    │   └── setup-nginx.yml            # Nginx 설치
    └── test/                      # ✅ 검증 및 테스트
        ├── test-connectivity.yml      # AI/Main 서비스 헬스체크
        ├── test-db.yml                # MySQL 연결성 테스트
        ├── test-redis.yml             # Redis 연결성 테스트
        ├── test-docker.yml            # Docker 설치 검증
        └── test-front.yml             # 프론트엔드 테스트
```

## 🎭 Roles 설명

### 1. common - 기본 시스템 설정
모든 서버의 공통 설정을 담당합니다.

**주요 기능:**
- 시스템 패키지 업데이트
- 기본 도구 설치 (curl, git, vim, htop 등)
- 디렉토리 생성 및 권한 설정
- 시간대 및 로케일 설정

**파일 구조:**
```
common/
├── defaults/main.yml    # 기본 변수
└── tasks/main.yml       # 실행 태스크
```

### 2. docker - Docker 환경
Docker 및 Docker Compose를 설치합니다.

**주요 기능:**
- Docker CE 설치
- Docker Compose 설치
- Docker 서비스 시작 및 활성화
- 사용자 그룹 설정

**파일 구조:**
```
docker/
├── defaults/main.yml
├── handlers/main.yml    # Docker 재시작 핸들러
└── tasks/main.yml
```

### 3. mysql - MySQL 데이터베이스
MySQL 8.0을 네이티브로 설치하고 VPC 내부 통신을 설정합니다.

**주요 기능:**
- MySQL 8.0 설치
- 데이터베이스 및 사용자 생성
- VPC 내부 접근 설정 (bind-address: 0.0.0.0)
- t3.micro 최적화 설정
- 백업 스크립트 및 크론 설정
- 로그 로테이션

**파일 구조:**
```
mysql/
├── defaults/main.yml
├── files/               # 백업 스크립트 등
├── handlers/main.yml    # MySQL 재시작 핸들러
├── tasks/main.yml
└── templates/           # my.cnf 등 설정 파일
```

### 4. redis - Redis 캐시
Redis를 네이티브로 설치하고 VPC 내부 통신을 설정합니다.

**주요 기능:**
- Redis 설치
- VPC 내부 접근 설정 (bind 0.0.0.0)
- 메모리 최적화 설정
- 지속성 설정 (RDB + AOF)
- 백업 스크립트 및 크론 설정
- 시스템 튜닝

**파일 구조:**
```
redis/
├── defaults/main.yml
├── files/               # 백업 스크립트 등
├── handlers/main.yml    # Redis 재시작 핸들러
├── tasks/main.yml
└── templates/           # redis.conf 등 설정 파일
```

### 5. nginx - Nginx 템플릿
Nginx 설정 템플릿만 제공합니다. (실제 설치는 playbook에서 직접 수행)

**주요 기능:**
- Main Service용 역방향 프록시 설정
- AI Service용 역방향 프록시 설정
- Blue-Green 배포 설정

**파일 구조:**
```
nginx/
└── templates/
    ├── nginx-main-service.conf.j2   # 메인 서비스 Nginx 설정
    ├── nginx-ai-service.conf.j2     # AI 서비스 Nginx 설정
    └── blue-green-main.conf.j2      # Blue-Green 배포 설정
```

## 📖 Playbooks 설명

### 🔧 Setup Playbooks (설치 및 구성)

#### deploy-all-services.yml - 전체 인프라 배포 (권장)
모든 서비스를 한 번에 배포합니다.

**실행 순서:**
1. MySQL 데이터베이스 구축 (setup-database.yml)
2. Redis 캐시 구축 (setup-cache.yml)
3. Nginx 설치 및 설정 (setup-nginx.yml)

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml
```

**배포 후 검증:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
```

#### setup-basic-system.yml - 기본 시스템 설정
모든 서버에 공통 시스템 설정을 적용합니다.

**주요 작업:**
- common role 실행 (기본 패키지 설치)
- AWS CLI 설치
- MySQL/Redis 클라이언트 설치

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-basic-system.yml
```

#### setup-database.yml - MySQL 설치
MySQL 서버를 설치하고 설정합니다.

**주요 작업:**
- MySQL 8.0 설치 및 설정
- VPC 내부 통신 설정 (bind-address: 0.0.0.0)
- 데이터베이스 및 사용자 생성

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml

# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
```

#### setup-cache.yml - Redis 설치
Redis 서버를 설치하고 설정합니다.

**주요 작업:**
- Redis 설치 및 설정
- VPC 내부 통신 설정 (bind 0.0.0.0)
- 메모리 최적화 설정

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-cache.yml

# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
```

#### setup-docker-only.yml - Docker 설치
메인/AI 서비스에 Docker만 설치합니다.

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-docker-only.yml

# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-docker.yml
```

#### setup-nginx.yml - Nginx 설치
메인/AI 서비스에 Nginx를 설치하고 설정합니다.

**주요 작업:**
- Nginx 설치 및 서비스 활성화
- Main Service용 역방향 프록시 설정
- AI Service용 역방향 프록시 설정

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-nginx.yml
```

### ✅ Test Playbooks (검증 및 테스트)

#### test-db.yml - MySQL 연결성 테스트
MySQL 서버 설정 및 연결성을 종합적으로 테스트합니다.

**테스트 단계:**
1. MySQL 서버 설정 확인 (서비스 상태, bind-address, 사용자 권한)
2. Main 서비스에서 MySQL 연결 테스트
3. AI 서비스에서 MySQL 연결 테스트
4. 최종 요약 및 문제 해결 방안

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
```

#### test-redis.yml - Redis 연결성 테스트
Redis 서버 설정 및 연결성을 종합적으로 테스트합니다.

**테스트 단계:**
1. 기본 네트워크 연결 (ICMP Ping)
2. TCP 포트 연결 테스트
3. Redis 서버 상세 설정 확인
4. Main 서비스에서 Redis 연결 테스트
5. AI 서비스에서 Redis 연결 테스트
6. 최종 요약 및 문제 해결 방안

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
```

#### test-docker.yml - Docker 설치 검증
Docker 설치 상태를 검증합니다.

**검증 항목:**
- Docker 버전 및 서비스 상태
- Docker 프로세스 및 소켓
- 사용자 그룹 멤버십
- 이미지, 컨테이너, 네트워크, 볼륨 조회

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test/test-docker.yml
```

#### test-connectivity.yml - AI/Main 서비스 헬스체크
AI 서비스와 Main 서비스의 헬스체크를 수행합니다.

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test/test-connectivity.yml
```

#### test-front.yml - 프론트엔드 테스트
프론트엔드 관련 테스트를 수행합니다.

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/test/test-front.yml
```

## 🚀 사용 가이드

### 📝 사전 준비

1. **Terraform으로 인프라 프로비저닝**
   ```bash
   cd ../terraform/environments/dev
   terraform apply
   terraform output  # IP 주소 확인
   ```

2. **인벤토리 파일 설정**
   ```bash
   vi inventory/hosts.yml
   # Terraform output의 IP 주소들을 입력
   ```

3. **SSH 키 권한 설정**
   ```bash
   chmod 400 ~/.ssh/mechuragi-dev-key.pem
   ```

4. **연결 테스트**
   ```bash
   ansible all -i inventory/hosts.yml -m ping
   ```

### 🎯 실행 방법

#### 방법 1: 전체 자동 배포 (권장) ⭐

한 번의 명령으로 모든 서비스를 배포합니다.

```bash
# 1. 전체 인프라 배포
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml

# 2. 배포 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
ansible-playbook -i inventory/hosts.yml playbooks/test/test-connectivity.yml
```

**배포 결과:**
- ✅ MySQL 데이터베이스 설치 및 설정
- ✅ Redis 캐시 설치 및 설정
- ✅ Main Service Nginx 설치
- ✅ AI Service Nginx 설치

#### 방법 2: 개별 서비스 배포

필요한 서비스만 개별적으로 배포합니다.

**기본 시스템 설정:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-basic-system.yml
```

**MySQL 데이터베이스:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml
# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
```

**Redis 캐시:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-cache.yml
# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
```

**Docker 환경:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-docker-only.yml
# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-docker.yml
```

**Nginx 웹 서버:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-nginx.yml
```

### 🔧 고급 사용법

#### 특정 호스트만 대상

```bash
# MySQL 서버만
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml --limit database

# 메인 서비스만
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml --limit main_service
```

#### 변수 오버라이드

```bash
# MySQL 비밀번호 임시 변경
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml \
  -e "mysql_root_password=newpassword"

# Redis 메모리 제한 임시 변경
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-cache.yml \
  -e "redis_maxmemory=2gb"
```

#### 드라이런 (변경사항 미리보기)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml --check
```

#### 상세 로그 출력

```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml -v   # 일반
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml -vv  # 상세
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml -vvv # 매우 상세
```

## 🌍 변수 관리

### 변수 우선순위 (높음 → 낮음)

1. **명령행 변수** (`-e key=value`)
2. **전역 group_vars** (`group_vars/`)
3. **Role defaults** (`roles/{role}/defaults/main.yml`)

### 주요 변수 파일

#### group_vars/all/main.yml
전역 공통 변수를 정의합니다.

### inventory/hosts.yml
서버 그룹 및 접속 정보를 정의합니다.

**구조 예시:**
```yaml
all:
  children:
    main_service:
      hosts:
        main-service-server:
          ansible_host: XXX.XXX.XXX.XXX
          private_ip: 10.0.2.XX

    ai_service:
      hosts:
        ai-service-server:
          ansible_host: XXX.XXX.XXX.XXX
          private_ip: 10.0.2.XX

    database:
      hosts:
        mysql-server:
          ansible_host: XXX.XXX.XXX.XXX
          private_ip: 10.0.2.XX

    cache:
      hosts:
        redis-server:
          ansible_host: XXX.XXX.XXX.XXX
          private_ip: 10.0.2.XX
```

## 📊 모니터링 및 검증

### 서비스 상태 확인

```bash
# 모든 서버 Ping 테스트
ansible all -i inventory/hosts.yml -m ping

# MySQL 상태 확인
ansible database -i inventory/hosts.yml -m shell \
  -a "systemctl status mysql" --become

# Redis 상태 확인
ansible cache -i inventory/hosts.yml -m shell \
  -a "systemctl status redis-server" --become

# Nginx 상태 확인
ansible main_service,ai_service -i inventory/hosts.yml -m shell \
  -a "systemctl status nginx" --become

```

### 포트 리스닝 확인

```bash
# 모든 서버의 포트 확인
ansible all -i inventory/hosts.yml -m shell \
  -a "ss -tlnp | grep -E '3306|6379|8080|8081|8082|80'" --become
```

### 연결성 테스트

```bash
# MySQL 연결성 테스트 (상세)
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml

# Redis 연결성 테스트 (상세)
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml

# AI/Main 서비스 헬스체크
ansible-playbook -i inventory/hosts.yml playbooks/test/test-connectivity.yml

# Docker 설치 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-docker.yml

# MySQL 간단 연결 테스트
ansible database -i inventory/hosts.yml -m shell \
  -a "mysql -e 'SELECT \"MySQL 연결 성공!\" as status;'" --become

# Redis 간단 연결 테스트
ansible cache -i inventory/hosts.yml -m shell \
  -a "redis-cli ping" --become
```

### 로그 확인

```bash
# MySQL 로그
ansible database -i inventory/hosts.yml -m shell \
  -a "tail -20 /var/log/mysql/error.log" --become

# Redis 로그
ansible cache -i inventory/hosts.yml -m shell \
  -a "tail -20 /var/log/redis/redis-server.log" --become

# Nginx 로그
ansible main_service -i inventory/hosts.yml -m shell \
  -a "tail -20 /var/log/nginx/error.log" --become
```

## 🔍 트러블슈팅

### 연결 실패

**증상:** SSH 연결이 안됨
```bash
# 해결 1: SSH 키 권한 확인
chmod 400 ~/.ssh/mechuragi-dev-key.pem

# 해결 2: SSH 연결 테스트
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@XXX.XXX.XXX.XXX

# 해결 3: 보안 그룹 확인
# AWS 콘솔에서 22번 포트 열려있는지 확인
```

### MySQL 연결 실패

**증상:** Main Service에서 MySQL 접근 불가

```bash
# 진단 1: MySQL bind-address 확인
ansible database -i inventory/hosts.yml -m shell \
  -a "grep bind-address /etc/mysql/mysql.conf.d/*.cnf" --become

# 진단 2: MySQL 사용자 권한 확인
ansible database -i inventory/hosts.yml -m shell \
  -a "mysql -e \"SELECT user, host FROM mysql.user;\"" --become

# 해결: setup-database.yml 재실행
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml

# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-db.yml
```

### Redis 연결 실패

**증상:** Main Service에서 Redis 접근 불가

```bash
# 진단 1: Redis bind 설정 확인
ansible cache -i inventory/hosts.yml -m shell \
  -a "grep '^bind' /etc/redis/redis.conf" --become

# 진단 2: Redis 포트 확인
ansible cache -i inventory/hosts.yml -m shell \
  -a "ss -tlnp | grep 6379" --become

# 해결: setup-cache.yml 재실행
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-cache.yml

# 검증
ansible-playbook -i inventory/hosts.yml playbooks/test/test-redis.yml
```

### Playbook 실행 실패

**증상:** 특정 태스크에서 실패

```bash
# 해결 1: 상세 로그로 재실행
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml -vvv

# 해결 2: 특정 태스크부터 재실행 (--start-at-task)
ansible-playbook -i inventory/hosts.yml playbooks/setup/deploy-all-services.yml \
  --start-at-task="MySQL 설치"

# 해결 3: 강제 핸들러 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup/setup-database.yml \
  --force-handlers
```

### 변수 확인

**증상:** 변수가 올바르게 적용되지 않음

```bash
# 특정 호스트의 모든 변수 확인
ansible-inventory -i inventory/hosts.yml --host mysql-server --vars

# 전체 인벤토리 확인
ansible-inventory -i inventory/hosts.yml --list
```

## 💡 베스트 프랙티스

### 1. 변수 관리
- 민감 정보는 `group_vars/`에 저장하고 `.gitignore`에 추가
- 환경별로 다른 값은 `group_vars/{group}/` 사용
- 공통 값은 `group_vars/all/` 사용

### 2. 멱등성 유지
- 모든 playbook은 여러 번 실행해도 안전해야 함
- `state: present` 같은 멱등성 있는 모듈 사용

### 3. 태그 활용
- 큰 playbook은 태그로 분리하여 부분 실행 가능하게 함
- 예: `--tags mysql` 또는 `--skip-tags backup`

### 4. 핸들러 사용
- 설정 파일 변경 시에만 서비스 재시작
- `notify`와 `handlers` 활용

### 5. 검증 강화
- 각 playbook에 `post_tasks`로 검증 추가
- 실패 시 명확한 에러 메시지 제공

## 🔗 관련 문서

- **[메인 README](../README.md)**: 전체 인프라 개요
- **[Terraform 가이드](../terraform/README.md)**: 인프라 프로비저닝
- **[CloudFront 설정](../docs/cloudfront-403-troubleshooting.md)**: CDN 설정
- **[트러블슈팅](../docs/troubleshooting-guide.md)**: 일반 문제 해결

---

**🎯 이 Ansible 구성은 메추라기 프로젝트의 서버 자동 설정을 담당하며, 인프라 배포 후 즉시 사용 가능한 환경을 제공합니다.**
