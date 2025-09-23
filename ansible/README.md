# Ansible Roles 기반 플레이북 실행 가이드

## 📋 개요

메추라기 분산 인프라를 위한 Ansible Roles 기반 구조입니다. 각 서비스별로 재사용 가능한 roles로 분리하여 책임을 명확히 하고 유지보수성을 향상시켰습니다.

## 📁 디렉토리 구조

```
ansible/
├── README.md                          # 이 가이드 파일
├── ansible.cfg                        # Ansible 설정
├── group_vars/
│   └── all.yml                        # 전역 변수
├── inventory/
│   └── hosts.yml                      # 4개 서버 인벤토리
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

### 📝 사전 준비

1. **인벤토리 파일 IP 업데이트**
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
# 모든 서비스를 순서대로 자동 배포
ansible-playbook -i inventory/hosts.yml playbooks/deploy-all-services.yml
```

#### 2단계: 개별 서비스 배포 (필요시)

**① 데이터베이스 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml
```

**② 캐시 서버 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-cache.yml
```

**③ AI 추천 서비스 구축**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-ai-service.yml
```

**④ 메인 서비스 구축**
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
# MySQL 비밀번호 변경
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml -e "mysql_root_password=newpassword"

# Redis 메모리 제한 변경
ansible-playbook -i inventory/hosts.yml playbooks/setup-cache.yml -e "redis_maxmemory=2gb"
```

### 특정 호스트만 대상
```bash
# MySQL 서버만
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml --limit database

# 메인 서비스만
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml --limit main_service
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
ansible-playbook -i inventory/hosts.yml playbooks/setup-mysql.yml --check -v
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
- 비밀번호는 `defaults/main.yml`에서 관리
- 템플릿에서 민감 정보 마스킹
- 파일 권한 엄격 설정 (600/640)

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

이제 재사용성과 유지보수성이 크게 향상된 Ansible 구조로 메추라기 인프라를 관리할 수 있습니다! 🚀