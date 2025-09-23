# Mechuragi 분산 인프라 배포 가이드

## 아키텍처 개요

메추라기 프로젝트가 4개의 별도 t3.small EC2 인스턴스로 분산 배치되었습니다:

### 인스턴스 구성
1. **메인 서비스** (Public): SpringBoot + AWS SES + AWS S3 (Docker)
2. **AI 추천 서비스** (Private): SpringBoot + AWS Bedrock (Docker)
3. **MySQL 데이터베이스** (Private): MySQL 8.0 (네이티브)
4. **Redis 캐시 서버** (Private): Redis (네이티브)

### 네트워크 구성
- 메인 서비스: Public subnet (외부 접근 가능)
- AI 서비스, MySQL, Redis: Private subnet (내부 통신만)
- 모든 private 인스턴스는 메인 서비스를 통해 SSH 접근

## 배포 절차

### 1. Terraform으로 인프라 생성

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 2. 출력된 IP 주소 확인

```bash
terraform output
```

다음과 같은 정보를 확인하세요:
- `main_service_public_ip`: 메인 서비스 공인 IP
- `ai_service_private_ip`: AI 서비스 사설 IP
- `mysql_private_ip`: MySQL 사설 IP
- `redis_private_ip`: Redis 사설 IP

### 3. Ansible로 서비스 배포

```bash
cd ../../ansible

# 전체 서비스 배포
ansible-playbook -i inventory/hosts.yml playbooks/deploy-distributed-services.yml

# 또는 개별 서비스 배포
ansible-playbook -i inventory/hosts.yml playbooks/setup-mysql-native.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-redis-native.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-ai-service.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-main-service.yml
```

## 서비스 접근 방법

### SSH 접근
```bash
# 메인 서비스 (직접 접근)
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@<main_service_public_ip>

# Private 인스턴스들 (Jump Box 사용)
ssh -i ~/.ssh/mechuragi-dev-key.pem -J ubuntu@<main_service_public_ip> ubuntu@<ai_service_private_ip>
ssh -i ~/.ssh/mechuragi-dev-key.pem -J ubuntu@<main_service_public_ip> ubuntu@<mysql_private_ip>
ssh -i ~/.ssh/mechuragi-dev-key.pem -J ubuntu@<main_service_public_ip> ubuntu@<redis_private_ip>
```

### 애플리케이션 접근
- 메인 서비스: `http://<main_service_public_ip>:8080`
- Health Check: `http://<main_service_public_ip>/health`

## 서비스 모니터링

### 각 서비스 상태 확인

```bash
# MySQL 상태
sudo systemctl status mysql

# Redis 상태
sudo systemctl status redis-server

# Docker 컨테이너 상태
docker ps
docker logs mechuragi-main-service
docker logs mechuragi-ai-service
```

### 로그 위치
- MySQL: `/var/log/mysql/`
- Redis: `/var/log/redis/`
- Main Service: `docker logs mechuragi-main-service`
- AI Service: `docker logs mechuragi-ai-service`

## 백업 설정

### 자동 백업
- MySQL: 매일 오전 2시 백업 (`/var/backups/mysql/`)
- Redis: 매일 오전 2시 30분 백업 (`/var/backups/redis/`)

### 수동 백업
```bash
# MySQL 백업
sudo /usr/local/bin/mysql-backup.sh

# Redis 백업
sudo /usr/local/bin/redis-backup.sh
```

## 성능 최적화

### t3.small 인스턴스 (2GB RAM) 최적화 설정

#### MySQL 설정
- InnoDB buffer pool: 1GB
- Max connections: 100
- Query cache: 64MB

#### Redis 설정
- Max memory: 1GB
- Memory policy: allkeys-lru
- Persistence: RDB + AOF

## 보안 설정

### 보안 그룹 구성
- 메인 서비스: HTTP(80), HTTPS(443), SSH(22), App(8080)
- AI 서비스: SSH(22), App(8081) - VPC 내부만
- MySQL: SSH(22), MySQL(3306) - VPC 내부만
- Redis: SSH(22), Redis(6379) - VPC 내부만

### 방화벽 규칙
- Private 인스턴스들은 VPC CIDR 블록 내에서만 접근 가능
- 외부에서는 메인 서비스만 접근 가능

## 트러블슈팅

### 일반적인 문제들

1. **서비스 연결 실패**
   ```bash
   # 네트워크 연결 확인
   telnet <target_ip> <port>

   # 보안 그룹 규칙 확인
   # AWS 콘솔에서 보안 그룹 인바운드 규칙 점검
   ```

2. **Docker 컨테이너 문제**
   ```bash
   # 컨테이너 상태 확인
   docker ps -a

   # 로그 확인
   docker logs <container_name>

   # 컨테이너 재시작
   docker-compose down && docker-compose up -d
   ```

3. **데이터베이스 연결 문제**
   ```bash
   # MySQL 연결 테스트
   mysql -h <mysql_private_ip> -u <username> -p

   # Redis 연결 테스트
   redis-cli -h <redis_private_ip> ping
   ```

## 확장 및 업그레이드

### 인스턴스 타입 변경
1. 인스턴스 중지
2. 인스턴스 타입 변경 (예: t3.medium)
3. 메모리 설정 조정 (MySQL, Redis)
4. 인스턴스 재시작

### 서비스 업데이트
1. 새 애플리케이션 JAR 파일 업로드
2. Docker 컨테이너 재시작
3. Health check 확인

## 비용 최적화

### 예상 월 비용 (서울 리전)
- EC2 t3.small × 4대: ~$60/월
- EIP × 1개: ~$3.6/월
- 스토리지 (20GB × 4): ~$8/월
- **총 예상 비용: ~$71.6/월**

### 비용 절약 팁
- Reserved Instance 구매 (1년 약정 시 30% 절약)
- 개발 환경은 야간/주말 자동 중지 설정
- CloudWatch로 리소스 사용률 모니터링