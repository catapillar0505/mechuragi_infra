# Ansible Roles 기반 플레이북 실행 가이드

## 📋 개요

메추라기 분산 인프라를 위한 Ansible Roles 기반 구조입니다. 각 서비스별로 재사용 가능한 roles로 분리하고, 단순한 변수 관리를 통해 책임을 명확히 하고 유지보수성을 향상시켰습니다.

## 📁 디렉토리 구조

```
ansible/
├── README.md                          # 이 가이드 파일
├── ansible.cfg                        # Ansible 설정
├── group_vars/                        # 🌐 전역 변수
│   ├── all/
│   │   ├── common.yml                 # 프로젝트 공통 설정
│   │   ├── networking.yml             # 네트워크 설정
│   │   └── aws.yml                    # AWS 서비스 설정
│   ├── main_service/
│   │   └── application.yml            # 메인 서비스 설정
│   ├── ai_service/
│   │   └── application.yml            # AI 서비스 설정
│   ├── database/
│   │   └── mysql.yml                  # MySQL 설정 (비밀번호 포함)
│   └── cache/
│       └── redis.yml                  # Redis 설정
├── inventory/                         # 📦 서버 인벤토리
│   └── hosts.yml                      # 서버 목록
├── roles/                             # 🎭 재사용 가능한 역할들
│   ├── common/                        # 시스템 공통 설정
│   ├── docker/                        # Docker 환경 구축
│   ├── mysql/                         # MySQL 데이터베이스
│   ├── redis/                         # Redis 캐시
│   ├── nginx/                         # Nginx 리버스 프록시
│   └── application/                   # Spring Boot 애플리케이션
├── playbooks/                         # 📖 실행 플레이북들
│   ├── setup-database.yml            # 데이터베이스 구축
│   ├── setup-cache.yml               # 캐시 서버 구축
│   ├── setup-ai-service.yml          # AI 추천 서비스
│   ├── setup-main-service.yml        # 메인 서비스
│   ├── deploy-all-services.yml       # 🚀 전체 배포
│   └── backup/                       # 기존 플레이북 백업
├── group_vars_backup/                 # 기존 group_vars 백업
└── templates_backup/                  # 기존 템플릿 백업
```

## 🎭 Roles 상세 설명

### 1. **common** - 시스템 공통 설정
- **목적**: 모든 서버의 기본 설정
- **포함 기능**:
  - 시스템 패키지 업데이트
  - 기본 도구 설치 (curl, git, vim 등)
  - 디렉토리 생성
  - 시간대 및 로케일 설정
  - 커널 매개변수 최적화

### 2. **docker** - Docker 환경 구축
- **목적**: Docker 및 Docker Compose 설치
- **포함 기능**:
  - Docker CE 설치
  - Docker Compose 설치
  - 사용자 그룹 설정
  - Docker 서비스 시작
- **의존성**: common

### 3. **mysql** - MySQL 데이터베이스
- **목적**: MySQL 네이티브 설치 및 설정
- **포함 기능**:
  - MySQL 8.0 설치
  - 데이터베이스 및 사용자 생성
  - t3.small 최적화 설정
  - 백업 스크립트 및 크론 설정
  - 로그 로테이션
- **의존성**: common

### 4. **redis** - Redis 캐시 서버
- **목적**: Redis 네이티브 설치 및 설정
- **포함 기능**:
  - Redis 설치
  - 메모리 최적화 설정
  - 지속성 설정 (RDB + AOF)
  - 백업 스크립트 및 크론 설정
  - 시스템 튜닝
- **의존성**: common

### 5. **nginx** - Nginx 리버스 프록시
- **목적**: Nginx 설치 및 리버스 프록시 설정
- **포함 기능**:
  - Nginx 설치
  - 사이트 설정 파일 생성
  - SSL 지원 (옵션)
  - 보안 헤더 설정
- **의존성**: common

### 6. **application** - Spring Boot 애플리케이션
- **목적**: Docker 기반 Spring Boot 애플리케이션 배포
- **포함 기능**:
  - Docker Compose 파일 생성
  - 환경변수 설정
  - 로그 로테이션 설정
  - 헬스체크
- **의존성**: common, docker

## 🚀 플레이북 실행 순서

### 권장 실행 순서
1. **데이터베이스 구축** → MySQL 서버 설정
2. **캐시 서버 구축** → Redis 서버 설정
3. **AI 추천 서비스** → AI 서비스 배포
4. **메인 서비스** → 메인 애플리케이션 배포

또는 **전체 자동 배포**로 한 번에 모든 서비스를 배포할 수 있습니다.

## 🌍 변수 관리

### 변수 우선순위 (높음 → 낮음)
1. **명령행 변수** (`-e key=value`)
2. **전역 group_vars** (`group_vars/`)
3. **Role defaults** (`roles/{role}/defaults/main.yml`)

### 성능 설정 (t3.small 최적화)

| 구분 | 설정값 |
|------|--------|
| **인스턴스** | t3.small |
| **MySQL 메모리** | 1GB |
| **Redis 메모리** | 1GB |
| **연결 수** | 100/100 |
| **로그 레벨** | INFO |
| **백업 주기** | 일간 |

### 📝 사전 준비

1. **인벤토리 IP 업데이트**
   ```bash
   # Terraform 출력에서 IP 주소 확인
   cd ../terraform/environments/dev
   terraform output

   # hosts.yml에 실제 IP 주소 입력
   vi inventory/hosts.yml
   ```

2. **SSH 키 경로 확인**
   ```bash
   ls ~/.ssh/mechuragi-dev-key.pem
   chmod 400 ~/.ssh/mechuragi-dev-key.pem
   ```

### 🎯 실행 방법

#### 1단계: 전체 자동 배포 (권장) ⭐

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-all-services.yml
```

#### 2단계: 개별 서비스 배포

**데이터베이스 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml
```

**캐시 서버 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-cache.yml
```

**AI 추천 서비스 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-ai-service.yml
```

**메인 서비스 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml
```

## 🔧 고급 사용법

### 특정 Role만 실행
```bash
# MySQL role만 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml --tags mysql

# Docker role만 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml --tags docker
```

### 변수 오버라이드
```bash
# MySQL 비밀번호 임시 변경
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml -e "mysql_root_password=newpassword"

# Redis 메모리 제한 임시 변경
ansible-playbook -i inventory/hosts.yml playbooks/setup-cache.yml -e "redis_maxmemory=4gb"
```

### 특정 호스트만 대상
```bash
# MySQL 서버만
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml --limit database

# 메인 서비스만
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml --limit main_service
```

### 변수 확인
```bash
# 변수 확인
ansible-inventory -i inventory/hosts.yml --host mysql-server --vars
```

## 📏 Roles 작성 규칙

### 1. 디렉토리 구조 표준
```
role_name/
├── tasks/main.yml          # 🔧 주요 작업
├── handlers/main.yml       # 🔔 이벤트 핸들러
├── templates/              # 📝 Jinja2 템플릿
├── files/                  # 📄 정적 파일
├── vars/main.yml           # 🔧 Role 변수
├── defaults/main.yml       # ⚙️ 기본값
└── meta/main.yml           # 📋 메타데이터
```

### 2. 네이밍 규칙
- **Role 이름**: 소문자, 하이픈 사용 (예: `mysql`, `redis`)
- **Task 이름**: 한국어, 명확한 동작 설명
- **Variable**: snake_case 사용
- **Template**: `.j2` 확장자

### 3. 의존성 관리
- `meta/main.yml`에서 dependencies 명시
- 순환 의존성 방지
- common role을 베이스로 사용

### 4. 변수 우선순위
1. 명령행 변수 (`-e`)
2. vars/main.yml
3. group_vars/
4. defaults/main.yml

## 🔍 트러블슈팅

### Role 의존성 문제
```bash
# 의존성 확인
ansible-galaxy list

# Role 강제 재실행
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml --force-handlers
```

### 템플릿 문제
```bash
# 템플릿 렌더링 테스트
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml --check -v
```

### 변수 확인
```bash
# 호스트 변수 출력
ansible-inventory -i inventory/hosts.yml --host mysql-server --vars
```

## 🎯 성능 및 보안

### Role별 최적화
- **MySQL**: t3.small 메모리 최적화 (1GB buffer pool)
- **Redis**: LRU 정책, 1GB 메모리 제한
- **Nginx**: gzip 압축, 보안 헤더
- **Application**: 로그 크기 제한, 헬스체크

### 보안 설정
- 비밀번호는 `group_vars/database/mysql.yml`에서 관리
- 템플릿에서 민감 정보 마스킹
- 파일 권한 엄격 설정 (600/640)
- SSH 점프 박스를 통한 보안 접근

## 📈 확장 가이드

### 새 Role 추가
1. `roles/` 하위에 디렉토리 생성
2. 표준 구조 따라 파일 작성
3. `meta/main.yml`에서 의존성 정의
4. 플레이북에서 role 호출

### 기존 Role 수정
1. `defaults/main.yml`에서 기본값 변경
2. `tasks/main.yml`에서 로직 수정
3. `templates/`에서 설정 파일 업데이트
4. 테스트 후 배포

## 🏗️ 인프라 구조

### 4개 서버 분산 구조
- **메인 서비스 서버** (Public): Spring Boot + AWS SES + S3
- **AI 서비스 서버** (Private): Spring Boot + AWS Bedrock
- **MySQL 서버** (Private): 네이티브 MySQL 설치
- **Redis 서버** (Private): 네이티브 Redis 설치

### 네트워크 구성
- 메인 서비스만 Public IP 보유
- 나머지 서버들은 SSH 점프 박스를 통해 접근
- 내부 통신은 Private IP 사용