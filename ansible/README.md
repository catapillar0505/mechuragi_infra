# Ansible 플레이북 실행 가이드

메추라기 프로젝트의 서버 설정을 위한 Ansible 플레이북 실행 방법입니다.

## 📋 사전 준비

### 1. 필수 파일 설정

#### `group_vars/all.yml` 생성
```yaml
---
# 서버 연결 정보
ansible_host: "YOUR_SERVER_IP"
ansible_user: "ec2-user"
ansible_ssh_private_key_file: "~/.ssh/YOUR_KEY.pem"
ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
ansible_python_interpreter: "/usr/bin/python3.8"

# MySQL 설정
mysql_root_password: "YOUR_MYSQL_ROOT_PASSWORD"
mysql_app_user: "mechuragi_user"
mysql_app_password: "YOUR_APP_PASSWORD"
mysql_database: "mechuragi_db"

# Redis 설정
redis_port: 6379

# 기타 설정
app_directory: "/home/ec2-user/app"

# Docker 설정
docker_compose_version: "v2.21.0"
mysql_docker_image: "mysql:8.0"
```

#### `inventory/hosts.yml` 생성
```bash
cp inventory/hosts.yml.template inventory/hosts.yml
```

### 2. SSH 키 권한 설정
```bash
chmod 400 ~/.ssh/YOUR_KEY.pem
```

## 🚀 플레이북 실행 순서

### 1단계: 시스템 기본 설정
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml
```
- 시스템 패키지 업데이트
- 필수 패키지 설치 (git, curl, wget, vim, htop)
- 애플리케이션 디렉토리 생성

### 2단계: Docker 환경 구성
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-docker.yml
```
- Docker 설치 및 서비스 시작
- ec2-user를 docker 그룹에 추가
- Docker Compose 설치
- Docker 버전 확인

### 3단계: 서비스 구성 (MySQL, Redis)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-services.yml
```
- MySQL Docker 컨테이너 실행
- MySQL 연결 테스트
- Redis 설치 및 설정
- Redis 연결 및 메모리 사용량 확인

### 4단계: 데이터베이스 초기화
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml
```
- mechuragi_db 데이터베이스 생성
- 애플리케이션용 사용자 생성 및 권한 부여
- 데이터베이스 연결 테스트

### 5단계: 전체 설정 검증
```bash
ansible-playbook -i inventory/hosts.yml playbooks/verify-setup.yml
```
- 포트 및 네트워크 상태 확인
- 서비스 버전 정보 확인
- 시스템 리소스 사용량 확인
- Docker 컨테이너 상태 확인

## 🔧 개별 실행 옵션

### 특정 플레이북만 실행
```bash
# Docker만 재설치
ansible-playbook -i inventory/hosts.yml playbooks/setup-docker.yml

# 서비스 상태만 확인
ansible-playbook -i inventory/hosts.yml playbooks/verify-setup.yml
```

### 상세 로그 확인
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml -v
```

### 드라이런 (실제 실행 안함)
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml --check
```

### 특정 태스크부터 시작
```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-services.yml --start-at-task="Redis 설치"
```

## 🔍 문제 해결

### 연결 테스트
```bash
ansible all -m ping -i inventory/hosts.yml
```

### 서버 상태 확인
```bash
ansible all -m command -a "systemctl is-active docker redis" --become -i inventory/hosts.yml
```

### MySQL 컨테이너 상태 확인
```bash
ansible all -m command -a "docker ps" --become -i inventory/hosts.yml
```

## 📝 주의사항

1. **보안**: `group_vars/all.yml`과 `inventory/hosts.yml`은 Git에 커밋하지 마세요
2. **순서**: 플레이북은 1단계부터 순서대로 실행하세요
3. **재실행**: 모든 플레이북은 멱등성을 가지므로 여러 번 실행해도 안전합니다
4. **권한**: `--become` 옵션이 필요한 작업들은 플레이북에 자동으로 설정되어 있습니다

## 📁 파일 구조

```
ansible/
├── README.md                    # 이 파일
├── group_vars/
│   └── all.yml                 # 변수 설정 (Git 제외)
├── inventory/
│   ├── hosts.yml               # 서버 인벤토리 (Git 제외)
│   └── hosts.yml.template      # 인벤토리 템플릿
└── playbooks/
    ├── setup-system.yml        # 시스템 기본 설정
    ├── setup-docker.yml        # Docker 환경 구성
    ├── setup-services.yml      # MySQL, Redis 서비스
    ├── setup-database.yml      # 데이터베이스 초기화
    └── verify-setup.yml        # 설정 검증
```