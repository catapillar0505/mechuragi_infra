# VPC 내부 통신 문제 해결 가이드

## 문제 상황

EC2 인스턴스 (10.0.1.76)에서 MySQL 서버 (43.203.80.62)와 Redis 서버 (13.209.135.59)로 접근이 차단됩니다.

## 원인 분석

### 인스턴스 IP 정보

| 서비스 | Private IP | Public IP |
|--------|------------|-----------|
| Main Service | 10.0.1.76 | 15.165.136.100 |
| AI Service | 10.0.1.184 | 43.202.184.199 |
| MySQL | 10.0.1.214 | 43.203.80.62 |
| Redis | 10.0.1.185 | 13.209.135.59 |

### 핵심 문제

**같은 VPC 내부에서는 반드시 Private IP를 사용해야 합니다!**

현재 애플리케이션 설정에서 MySQL과 Redis의 **Public IP**를 사용하려고 하는데, Security Group이 이를 차단하고 있습니다.

## Security Group 설정 (이미 올바름)

### MySQL Security Group

```hcl
ingress {
  description = "MySQL from VPC only"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # VPC 내부에서만 접근 허용
}
```

✅ **설정 올바름**: VPC CIDR (10.0.0.0/16)에서 3306 포트 접근 허용

### Redis Security Group

```hcl
ingress {
  description = "Redis from VPC only"
  from_port   = 6379
  to_port     = 6379
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]  # VPC 내부에서만 접근 허용
}
```

✅ **설정 올바름**: VPC CIDR (10.0.0.0/16)에서 6379 포트 접근 허용

### Main Service Security Group

```hcl
egress {
  description = "All outbound traffic"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]  # 모든 아웃바운드 허용
}
```

✅ **설정 올바름**: 모든 아웃바운드 트래픽 허용

## 해결 방법

### ❌ 잘못된 방법 (Public IP 사용)

```bash
# Main Service에서
mysql -h 43.203.80.62 -P 3306 -u user -p       # 차단됨!
redis-cli -h 13.209.135.59 -p 6379              # 차단됨!
```

**왜 차단되나요?**
- Public IP로 접근하면 인터넷을 통해 다시 돌아오는 경로가 됨
- Security Group은 VPC 내부 (10.0.0.0/16)에서만 허용하도록 설정됨
- Public IP는 VPC 외부 주소로 인식되어 차단됨

### ✅ 올바른 방법 (Private IP 사용)

```bash
# Main Service에서
mysql -h 10.0.1.214 -P 3306 -u user -p         # 성공!
redis-cli -h 10.0.1.185 -p 6379                # 성공!
```

## 애플리케이션 설정 변경

### Spring Boot application.properties 또는 application.yml

**변경 전:**
```yaml
spring:
  datasource:
    url: jdbc:mysql://43.203.80.62:3306/mechuragi
  data:
    redis:
      host: 13.209.135.59
      port: 6379
```

**변경 후:**
```yaml
spring:
  datasource:
    url: jdbc:mysql://10.0.1.214:3306/mechuragi
  data:
    redis:
      host: 10.0.1.185
      port: 6379
```

### 환경 변수 사용 (권장)

```yaml
spring:
  datasource:
    url: jdbc:mysql://${MYSQL_HOST:10.0.1.214}:3306/mechuragi
  data:
    redis:
      host: ${REDIS_HOST:10.0.1.185}
      port: 6379
```

환경 변수 설정:
```bash
export MYSQL_HOST=10.0.1.214
export REDIS_HOST=10.0.1.185
```

## 단계별 연결 테스트

메인 서비스에서 MySQL과 Redis에 접근이 안될 때 단계적으로 문제를 진단합니다.

### 1단계: 기본 네트워크 연결 테스트 (ICMP)

```bash
# Main Service EC2에 SSH 접속
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@15.165.136.100

# MySQL 서버 ping 테스트
ping -c 4 10.0.1.214

# Redis 서버 ping 테스트
ping -c 4 10.0.1.185
```

**예상 결과:**
- ✅ 성공: `64 bytes from 10.0.1.214: icmp_seq=1 ttl=64 time=0.xxx ms`
- ❌ 실패: `Destination Host Unreachable` → Security Group ICMP 규칙 확인 필요

### 2단계: TCP 포트 연결 테스트

#### 방법 1: telnet 사용

```bash
# MySQL 포트 확인 (3306)
telnet 10.0.1.214 3306

# Redis 포트 확인 (6379)
telnet 10.0.1.185 6379
```

**예상 결과:**
- ✅ 성공: `Connected to 10.0.1.214.` 또는 MySQL/Redis 환영 메시지
- ❌ `Connection refused`: 서비스가 해당 주소/포트에서 리스닝하지 않음
- ❌ `Connection timed out`: Security Group 차단 또는 서비스 중단

#### 방법 2: nc (netcat) 사용

```bash
# telnet이 없다면 nc 사용
nc -zv 10.0.1.214 3306
nc -zv 10.0.1.185 6379
```

**예상 결과:**
- ✅ 성공: `Connection to 10.0.1.214 3306 port [tcp/mysql] succeeded!`
- ❌ 실패: `Connection refused` 또는 `timed out`

#### 방법 3: timeout을 추가하여 빠르게 테스트

```bash
# 3초 타임아웃으로 테스트
timeout 3 bash -c "</dev/tcp/10.0.1.214/3306" && echo "MySQL 포트 열림" || echo "MySQL 포트 닫힘"
timeout 3 bash -c "</dev/tcp/10.0.1.185/6379" && echo "Redis 포트 열림" || echo "Redis 포트 닫힘"
```

### 3단계: MySQL 서버 확인

MySQL 서버에 직접 접속하여 설정을 확인합니다.

```bash
# MySQL 서버에 SSH 접속
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@43.203.80.62

# MySQL 서비스 상태 확인
sudo systemctl status mysql
```

**예상 출력:**
```
● mysql.service - MySQL Community Server
   Active: active (running)  ✅
```

```bash
# MySQL이 어떤 주소로 리스닝하는지 확인
sudo ss -tlnp | grep 3306
```

**예상 결과:**
- ✅ 올바름: `0.0.0.0:3306` → 모든 인터페이스에서 수신
- ❌ 문제: `127.0.0.1:3306` → localhost에서만 수신 (외부 접근 불가)

```bash
# MySQL 설정 파일 확인
sudo grep bind-address /etc/mysql/mysql.conf.d/*.cnf
```

**예상 결과:**
- ✅ 올바름: `bind-address = 0.0.0.0`
- ❌ 문제: `bind-address = 127.0.0.1` → 수정 필요

#### MySQL bind-address 수정 (필요시)

```bash
# 설정 파일 편집
sudo nano /etc/mysql/mysql.conf.d/mechuragi.cnf

# 또는 기본 설정 파일
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

변경:
```ini
# 변경 전
bind-address = 127.0.0.1

# 변경 후
bind-address = 0.0.0.0
```

```bash
# MySQL 재시작
sudo systemctl restart mysql

# 확인
sudo ss -tlnp | grep 3306
# 출력: 0.0.0.0:3306 이어야 함
```

#### MySQL 사용자 권한 확인

```bash
# MySQL에 로그인
sudo mysql -u root -p

# 또는 root .my.cnf가 설정되어 있다면
sudo mysql
```

```sql
-- 사용자와 호스트 확인
SELECT user, host FROM mysql.user WHERE user='mechuragi_user';
```

**예상 결과:**
- ✅ 올바름: `mechuragi_user | 10.0.%` 또는 `mechuragi_user | %`
- ❌ 문제: `mechuragi_user | localhost`만 존재 → VPC에서 접근 불가

#### MySQL 사용자 권한 수정 (필요시)

```sql
-- VPC 내부에서 접근 허용
GRANT ALL PRIVILEGES ON mechuragi_db.* TO 'mechuragi_user'@'10.0.%' IDENTIFIED BY 'mechuragi_pass';
FLUSH PRIVILEGES;

-- 확인
SELECT user, host FROM mysql.user WHERE user='mechuragi_user';
EXIT;
```

### 4단계: Redis 서버 확인

Redis 서버에 직접 접속하여 설정을 확인합니다.

```bash
# Redis 서버에 SSH 접속
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@13.209.135.59

# Redis 서비스 상태 확인
sudo systemctl status redis-server
```

**예상 출력:**
```
● redis-server.service - Advanced key-value store
   Active: active (running)  ✅
```

```bash
# Redis가 어떤 주소로 리스닝하는지 확인
sudo ss -tlnp | grep 6379
```

**예상 결과:**
- ✅ 올바름: `0.0.0.0:6379` → 모든 인터페이스에서 수신
- ❌ 문제: `127.0.0.1:6379` → localhost에서만 수신 (외부 접근 불가)

```bash
# Redis 설정 파일 확인
sudo grep "^bind" /etc/redis/redis.conf
```

**예상 결과:**
- ✅ 올바름: `bind 0.0.0.0`
- ❌ 문제: `bind 127.0.0.1` → 수정 필요

#### Redis bind 주소 수정 (필요시)

```bash
# 설정 파일 편집
sudo nano /etc/redis/redis.conf
```

변경:
```ini
# 변경 전
bind 127.0.0.1 ::1

# 변경 후
bind 0.0.0.0
```

```bash
# protected-mode 확인
sudo grep "^protected-mode" /etc/redis/redis.conf
```

**설정:**
- `protected-mode yes` (권장, VPC 내부 통신)
- `protected-mode no` (비권장, 보안 취약)

```bash
# Redis 재시작
sudo systemctl restart redis-server

# 확인
sudo ss -tlnp | grep 6379
# 출력: 0.0.0.0:6379 이어야 함
```

### 5단계: Main Service에서 최종 연결 테스트

다시 Main Service로 돌아와서 연결을 테스트합니다.

```bash
# Main Service에 SSH 접속
ssh -i ~/.ssh/mechuragi-dev-key.pem ubuntu@15.165.136.100

# MySQL 연결 테스트
mysql -h 10.0.1.214 -P 3306 -u mechuragi_user -p
# 비밀번호: mechuragi_pass
```

**예상 결과:**
- ✅ 성공: `mysql>` 프롬프트 표시
- ❌ 실패: 에러 메시지 확인

**일반적인 에러:**
```
ERROR 2003 (HY000): Can't connect to MySQL server on '10.0.1.214' (111)
→ MySQL이 해당 주소에서 리스닝하지 않음 (bind-address 문제)

ERROR 2003 (HY000): Can't connect to MySQL server on '10.0.1.214' (110)
→ Connection timed out (Security Group 문제)

ERROR 1045 (28000): Access denied for user 'mechuragi_user'@'10.0.1.76'
→ 사용자 권한 문제 (host 설정 확인 필요)
```

```bash
# Redis 연결 테스트
redis-cli -h 10.0.1.185 -p 6379 ping
```

**예상 결과:**
- ✅ 성공: `PONG`
- ❌ 실패: `Could not connect` → Redis 서버 설정 확인

### 6단계: Security Group 재확인

AWS Console에서 Security Group 설정을 다시 확인합니다.

#### MySQL Security Group

```bash
# Terraform으로 확인
cd ~/mechuragi-infra/terraform/environments/dev
terraform show | grep -A 20 "mysql.*security_group"
```

**필수 Inbound Rule:**
- Type: MySQL/Aurora (3306)
- Protocol: TCP
- Port: 3306
- Source: `10.0.0.0/16` (VPC CIDR)

#### Redis Security Group

**필수 Inbound Rule:**
- Type: Custom TCP
- Protocol: TCP
- Port: 6379
- Source: `10.0.0.0/16` (VPC CIDR)

### 연결 테스트 체크리스트

문제 해결을 위한 체크리스트:

- [ ] **1단계**: Main Service → MySQL/Redis ping 성공
- [ ] **2단계**: Main Service → MySQL 포트 3306 연결 성공
- [ ] **2단계**: Main Service → Redis 포트 6379 연결 성공
- [ ] **3단계**: MySQL 서비스가 `0.0.0.0:3306`에서 리스닝
- [ ] **3단계**: MySQL 사용자가 `10.0.%` 호스트에서 접근 가능
- [ ] **4단계**: Redis 서비스가 `0.0.0.0:6379`에서 리스닝
- [ ] **5단계**: Main Service에서 MySQL 명령어로 연결 성공
- [ ] **5단계**: Main Service에서 Redis CLI로 연결 성공
- [ ] **6단계**: Security Group Inbound Rules 확인

### 빠른 진단 스크립트

모든 테스트를 한 번에 실행하는 스크립트:

```bash
# Main Service에서 실행
cat > ~/test-connectivity.sh << 'EOF'
#!/bin/bash

echo "=== VPC 내부 연결 테스트 ==="
echo ""

MYSQL_IP="10.0.1.214"
REDIS_IP="10.0.1.185"

echo "1. Ping 테스트"
echo -n "  MySQL ($MYSQL_IP): "
ping -c 1 -W 2 $MYSQL_IP > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

echo -n "  Redis ($REDIS_IP): "
ping -c 1 -W 2 $REDIS_IP > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

echo ""
echo "2. 포트 연결 테스트"
echo -n "  MySQL 포트 3306: "
timeout 3 bash -c "</dev/tcp/$MYSQL_IP/3306" 2>/dev/null && echo "✅ OPEN" || echo "❌ CLOSED"

echo -n "  Redis 포트 6379: "
timeout 3 bash -c "</dev/tcp/$REDIS_IP/6379" 2>/dev/null && echo "✅ OPEN" || echo "❌ CLOSED"

echo ""
echo "3. 서비스 연결 테스트"
echo -n "  MySQL 연결: "
mysql -h $MYSQL_IP -P 3306 -u mechuragi_user -pmechuragi_pass -e "SELECT 1" > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

echo -n "  Redis 연결: "
redis-cli -h $REDIS_IP -p 6379 ping > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

echo ""
echo "=== 테스트 완료 ==="
EOF

chmod +x ~/test-connectivity.sh
~/test-connectivity.sh
```

## Terraform Output 활용

Private IP는 Terraform output으로 확인할 수 있습니다:

```bash
cd ~/mechuragi-infra/terraform/environments/dev

# 모든 Private IP 확인
terraform output | grep private_ip

# 특정 서비스 Private IP 확인
terraform output mysql_private_ip    # 10.0.1.214
terraform output redis_private_ip    # 10.0.1.185
```

## VPC 내부 통신 원칙

### 같은 VPC 내부 통신

```
Main Service (10.0.1.76)
    │
    ├──[Private IP]──> MySQL (10.0.1.214) ✅ 허용
    ├──[Private IP]──> Redis (10.0.1.185) ✅ 허용
    └──[Private IP]──> AI Service (10.0.1.184) ✅ 허용
```

### 잘못된 통신 패턴

```
Main Service (10.0.1.76)
    │
    └──[Public IP]──> Internet ──> MySQL Public IP (43.203.80.62) ❌ 차단
                                    (Security Group에서 VPC 외부 차단)
```

## 보안 설계 정책

### Level 1: Main Service
- **인터넷 접근**: 허용 (웹 서비스)
- **Inbound**: HTTP/HTTPS (80, 443), Spring Boot (8080)
- **Outbound**: 모든 트래픽 허용

### Level 2: AI Service, MySQL, Redis
- **인터넷 접근**: SSH만 허용 (관리 목적)
- **애플리케이션 포트**: VPC 내부에서만 접근 허용
  - AI Service: 8081 (VPC only)
  - MySQL: 3306 (VPC only)
  - Redis: 6379 (VPC only)
- **Outbound**: 모든 트래픽 허용 (패키지 업데이트, API 호출 등)

## 트러블슈팅

### 연결 실패 시 체크리스트

1. **Private IP를 사용하고 있는가?**
   ```bash
   # 잘못된 예
   mysql -h 43.203.80.62 ...

   # 올바른 예
   mysql -h 10.0.1.214 ...
   ```

2. **Security Group 확인**
   ```bash
   # AWS Console에서 확인
   # EC2 → Security Groups → mysql-sg
   # Inbound rules에 10.0.0.0/16에서 3306 포트 허용되어 있는지 확인
   ```

3. **네트워크 연결 테스트**
   ```bash
   # Main Service에서
   ping 10.0.1.214        # MySQL 연결 확인
   ping 10.0.1.185        # Redis 연결 확인
   telnet 10.0.1.214 3306 # MySQL 포트 확인
   telnet 10.0.1.185 6379 # Redis 포트 확인
   ```

4. **VPC CIDR 확인**
   ```bash
   terraform output | grep vpc
   # VPC CIDR: 10.0.0.0/16인지 확인
   ```

## Ansible로 MySQL/Redis 재배포

현재 배포된 MySQL/Redis 서버가 잘못 설정되어 있다면 Ansible로 재배포하세요.

### Ansible 설정 확인

#### MySQL 설정 (`ansible/roles/mysql/`)

**주요 변경 사항:**
- `bind-address = 0.0.0.0` (모든 네트워크 인터페이스에서 수신) ✅
- 사용자 호스트 권한: `10.0.%` (VPC 내부만 허용) ✅

```yaml
# ansible/roles/mysql/tasks/main.yml
- name: 애플리케이션 사용자 생성 (VPC 내부에서만 접근)
  mysql_user:
    name: "{{ mysql_app_user }}"
    password: "{{ mysql_app_password }}"
    priv: "{{ mysql_database }}.*:ALL"
    host: "10.0.%"
    state: present
```

#### Redis 설정 (`ansible/roles/redis/`)

**주요 변경 사항:**
- `bind 0.0.0.0` (모든 네트워크 인터페이스에서 수신) ✅
- `protected-mode yes` (보안 모드 활성화) ✅

```jinja2
# ansible/roles/redis/templates/redis.conf.j2
bind 0.0.0.0
port {{ redis_port }}
protected-mode yes
```

### Ansible 재배포 실행

```bash
cd ~/mechuragi-infra/ansible

# MySQL만 재배포
ansible-playbook -i inventory/dev playbooks/setup-mysql.yml

# Redis만 재배포
ansible-playbook -i inventory/dev playbooks/setup-redis.yml

# 또는 전체 재배포
ansible-playbook -i inventory/dev playbooks/site.yml
```

### 재배포 후 확인

```bash
# MySQL 설정 확인
ssh ubuntu@43.203.80.62 "sudo cat /etc/mysql/mysql.conf.d/mechuragi.cnf | grep bind-address"
# 출력: bind-address = 0.0.0.0

# MySQL 사용자 확인
ssh ubuntu@43.203.80.62 "sudo mysql -e \"SELECT user, host FROM mysql.user WHERE user='mechuragi_user';\""
# 출력: mechuragi_user | 10.0.%
#       mechuragi_user | localhost

# Redis 설정 확인
ssh ubuntu@13.209.135.59 "grep '^bind' /etc/redis/redis.conf"
# 출력: bind 0.0.0.0
```

## 요약

### 문제의 핵심
- ❌ Public IP (43.203.80.62, 13.209.135.59) 사용
- ✅ Private IP (10.0.1.214, 10.0.1.185) 사용

### 해결 방법
1. 애플리케이션 설정에서 MySQL과 Redis 주소를 Private IP로 변경
2. Security Group 설정은 **변경 불필요** (이미 올바름)
3. MySQL/Redis 서버 설정이 잘못되었다면 Ansible로 재배포
4. 연결 테스트로 확인

### Ansible 설정 (이미 수정됨)
- **MySQL**: `bind-address = 0.0.0.0`, 사용자 권한 `10.0.%`
- **Redis**: `bind 0.0.0.0`, `protected-mode yes`

### 보안상 장점
- VPC 내부 트래픽은 인터넷을 거치지 않아 더 안전
- 지연 시간 감소 (내부 네트워크 사용)
- 데이터 전송 비용 절감 (AWS 내부 트래픽은 무료)
- MySQL 사용자가 VPC 외부에서 접근 불가
