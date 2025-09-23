# Ansible 플레이북 실행 가이드

## 📋 플레이북 개요

메추라기 분산 인프라를 위한 Ansible 플레이북들입니다. 각 서비스별로 독립적인 플레이북이 구성되어 있습니다.

## 📁 디렉토리 구조

```
ansible/
├── inventory/
│   └── hosts.yml                    # 인벤토리 파일 (4개 서버 그룹)
├── group_vars/
│   └── all.yml                      # 전역 변수
├── playbooks/
│   ├── setup-docker.yml             # Docker 환경 구축
│   ├── setup-mysql-native.yml       # MySQL 네이티브 설치
│   ├── setup-redis-native.yml       # Redis 네이티브 설치
│   ├── setup-ai-service.yml         # AI 추천 서비스 (Docker)
│   ├── setup-main-service.yml       # 메인 서비스 (Docker)
│   └── deploy-distributed-services.yml  # 전체 배포 통합
├── templates/                       # Jinja2 템플릿 파일들
└── README.md                       # 이 파일
```

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

### 🎯 실행 순서 (권장)

#### 1단계: 전체 자동 배포 (권장)
```bash
# 모든 서비스를 순서대로 자동 배포
ansible-playbook -i inventory/hosts.yml playbooks/deploy-distributed-services.yml
```

#### 2단계: 개별 서비스 배포 (필요시)

**① Docker 환경 구축** (메인 서비스 + AI 서비스)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-docker.yml
```

**② MySQL 데이터베이스 구축** (네이티브)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-mysql-native.yml
```

**③ Redis 캐시 서버 구축** (네이티브)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-redis-native.yml
```

**④ AI 추천 서비스 구축** (Docker)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-ai-service.yml
```

**⑤ 메인 서비스 구축** (Docker)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml
```

## 📋 플레이북 상세 설명

### `setup-docker.yml` - 도커 환경 구축
- **대상**: `main_service`, `ai_service` 그룹
- **기능**: Docker CE, Docker Compose 설치 및 구성
- **실행 시간**: 약 3-5분

### `setup-mysql-native.yml` - MySQL 데이터베이스 구축
- **대상**: `database` 그룹 (MySQL 서버)
- **기능**:
  - MySQL 8.0 네이티브 설치
  - 데이터베이스 및 사용자 생성
  - 백업 스크립트 및 크론 설정
  - 로그 로테이션 구성
- **실행 시간**: 약 5-8분

### `setup-redis-native.yml` - Redis 캐시 서버 구축
- **대상**: `cache` 그룹 (Redis 서버)
- **기능**:
  - Redis 네이티브 설치
  - t3.small 최적화 설정
  - 백업 스크립트 및 크론 설정
  - 로그 로테이션 구성
- **실행 시간**: 약 3-5분

### `setup-ai-service.yml` - AI 추천 서비스 구축
- **대상**: `ai_service` 그룹
- **기능**:
  - Docker 컨테이너로 SpringBoot 앱 실행
  - AWS Bedrock 연동 설정
  - 환경 변수 구성
- **실행 시간**: 약 2-3분

### `setup-main-service.yml` - 메인 서비스 구축
- **대상**: `main_service` 그룹
- **기능**:
  - Docker 컨테이너로 SpringBoot 앱 실행
  - Nginx 리버스 프록시 설정
  - AWS SES, S3 연동 설정
  - 환경 변수 구성
- **실행 시간**: 약 3-5분

### `deploy-distributed-services.yml` - 전체 배포 통합
- **대상**: 모든 서버 그룹
- **기능**:
  - 위 모든 플레이북을 순서대로 실행
  - 서비스 상태 검증
  - 배포 완료 확인
- **실행 시간**: 약 15-25분

## 🔧 고급 사용법

### 특정 그룹만 대상으로 실행
```bash
# MySQL 서버만
ansible-playbook -i inventory/hosts.yml playbooks/setup-mysql-native.yml --limit database

# 메인 서비스만
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml --limit main_service
```

### 태그 기반 실행 (해당되는 경우)
```bash
# 특정 태스크만 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml --tags "nginx"
```

### 드라이런(테스트) 모드
```bash
# 실제 변경 없이 테스트
ansible-playbook -i inventory/hosts.yml playbooks/setup-mysql-native.yml --check
```

### 상세 로그 출력
```bash
# 자세한 실행 로그
ansible-playbook -i inventory/hosts.yml playbooks/deploy-distributed-services.yml -v

# 매우 자세한 로그
ansible-playbook -i inventory/hosts.yml playbooks/deploy-distributed-services.yml -vvv
```

## 📏 플레이북 작성 규칙

### 1. 네이밍 규칙
- **플레이북 name**: 한국어로 작성
  ```yaml
  - name: 메인 서비스 구축 (SpringBoot + AWS SES + S3)
  ```

- **태스크 name**: 한국어로 작성
  ```yaml
  - name: 시스템 패키지 업데이트
  - name: Docker 설치 및 구성
  ```

### 2. 구조 규칙
- 각 서비스별로 독립적인 플레이북 작성
- 공통 설정은 `group_vars/all.yml`에 정의
- 템플릿 파일은 `templates/` 디렉토리에 위치

### 3. 실행 순서 고려사항
1. **데이터베이스 레이어** (MySQL, Redis) 먼저 구축
2. **애플리케이션 레이어** (AI 서비스, 메인 서비스) 나중에 구축
3. **의존성 순서**: MySQL → Redis → AI 서비스 → 메인 서비스

## ⚠️ 주의사항

1. **SSH 접근**: private 인스턴스들은 메인 서비스를 jump box로 사용
2. **방화벽**: 보안 그룹 설정 확인 필요
3. **메모리**: t3.small 인스턴스 메모리 제한 고려
4. **백업**: 자동 백업 스크립트가 설정되므로 디스크 공간 모니터링 필요

## 🔍 트러블슈팅

### 연결 실패 시
```bash
# 연결 테스트
ansible all -i inventory/hosts.yml -m ping

# SSH 연결 확인
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@<IP>
```

### 플레이북 실행 실패 시
```bash
# 특정 태스크부터 재시작
ansible-playbook -i inventory/hosts.yml playbooks/setup-mysql-native.yml --start-at-task="MySQL 루트 패스워드 설정"
```

### 서비스 상태 확인
```bash
# 모든 서버에서 서비스 상태 확인
ansible all -i inventory/hosts.yml -a "systemctl status docker" --become
ansible database -i inventory/hosts.yml -a "systemctl status mysql" --become
ansible cache -i inventory/hosts.yml -a "systemctl status redis-server" --become
```