# 로그 관리 가이드

이 디렉토리는 메추라기 분산 서비스의 로그들을 로컬에서 확인할 수 있도록 수집하는 공간입니다.

## 📁 디렉토리 구조

```
logs/
├── README.md              # 이 가이드 파일
├── collect-logs.sh         # 로그 수집 스크립트
├── last_collected.txt      # 마지막 수집 시간
├── mysql/                  # MySQL 로그들
│   ├── error.log          # MySQL 에러 로그
│   └── slow.log           # MySQL 슬로우 쿼리 로그
├── redis/                  # Redis 로그들
│   └── redis-server.log   # Redis 서버 로그
├── main-service/           # 메인 서비스 로그들
│   └── main-service.log   # 메인 서비스 Docker 로그
└── ai-service/             # AI 서비스 로그들
    └── ai-service.log     # AI 서비스 Docker 로그
```

## 🚀 사용 방법

### 로그 수집 실행

```bash
# 현재 디렉토리에서 로그 수집 스크립트 실행
./logs/collect-logs.sh

# 또는 절대 경로로 실행
/home/jina/mechuragi-infra/logs/collect-logs.sh
```

### 수집된 로그 확인

```bash
# MySQL 에러 로그 확인
cat logs/mysql/error.log

# MySQL 슬로우 쿼리 로그 확인
cat logs/mysql/slow.log

# Redis 로그 확인
cat logs/redis/redis-server.log

# 메인 서비스 로그 확인 (최근 100줄)
cat logs/main-service/main-service.log

# AI 서비스 로그 확인 (최근 100줄)
cat logs/ai-service/ai-service.log
```

### 실시간 로그 확인 (서버에서 직접)

```bash
# MySQL 로그 실시간 모니터링
ansible mysql-server -i ansible/inventory/hosts.yml -m shell -a "tail -f /var/log/mysql/error.log" --become

# Redis 로그 실시간 모니터링
ansible redis-server -i ansible/inventory/hosts.yml -m shell -a "tail -f /var/log/redis/redis-server.log" --become

# Docker 컨테이너 로그 실시간 모니터링
ansible main-service-server -i ansible/inventory/hosts.yml -m shell -a "docker logs -f mechuragi-main-service" --become
ansible ai-service-server -i ansible/inventory/hosts.yml -m shell -a "docker logs -f mechuragi-ai-service" --become
```

## ⏰ 자동 수집 설정

cron을 사용해서 주기적으로 로그를 수집할 수 있습니다:

```bash
# crontab 편집
crontab -e

# 10분마다 로그 수집 (예시)
*/10 * * * * /home/jina/mechuragi-infra/logs/collect-logs.sh >> /home/jina/mechuragi-infra/logs/collect.log 2>&1
```

## 📊 로그 분석

### 에러 패턴 찾기

```bash
# MySQL 에러 로그에서 ERROR 패턴 찾기
grep -i "error" logs/mysql/error.log

# Redis 로그에서 WARNING 이상 찾기
grep -E "(WARNING|ERROR|CRITICAL)" logs/redis/redis-server.log

# 애플리케이션 로그에서 Exception 찾기
grep -i "exception\|error" logs/main-service/main-service.log
grep -i "exception\|error" logs/ai-service/ai-service.log
```

### 로그 크기 확인

```bash
# 각 로그 파일 크기 확인
du -sh logs/*/

# 전체 로그 디렉토리 크기
du -sh logs/
```

## 🔧 트러블슈팅

### 로그 수집 실패 시

1. **네트워크 연결 확인**
   ```bash
   ansible all -i ansible/inventory/hosts.yml -m ping
   ```

2. **서비스 상태 확인**
   ```bash
   ansible all -i ansible/inventory/hosts.yml -m shell -a "systemctl status mysql redis-server" --become
   ```

3. **로그 파일 존재 여부 확인**
   ```bash
   ansible mysql-server -i ansible/inventory/hosts.yml -m shell -a "ls -la /var/log/mysql/" --become
   ansible redis-server -i ansible/inventory/hosts.yml -m shell -a "ls -la /var/log/redis/" --become
   ```

### Docker 컨테이너가 없을 때

```bash
# 실행 중인 컨테이너 확인
ansible main-service-server -i ansible/inventory/hosts.yml -m shell -a "docker ps" --become
ansible ai-service-server -i ansible/inventory/hosts.yml -m shell -a "docker ps" --become
```

## 📝 주의사항

- 로그 파일들은 `.gitignore`에 추가되어 있어 Git에 커밋되지 않습니다
- 로그 수집은 네트워크 상태와 서버 성능에 영향을 받을 수 있습니다
- 대용량 로그 파일의 경우 수집에 시간이 걸릴 수 있습니다
- 정기적으로 오래된 로그 파일들을 정리하는 것을 권장합니다