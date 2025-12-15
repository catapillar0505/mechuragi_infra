# Ansible 서버 구성 가이드

메추라기 통합 인프라의 서버 자동 구성을 담당하는 Ansible 저장소입니다. 3개 서버(Nginx Gateway, 통합 메인 서버, AI 서비스)의 초기 설정을 자동화합니다.

## 📋 개요

이 Ansible 구성은 3개의 통합 서버를 자동으로 초기 설정합니다. Terraform으로 인프라를 프로비저닝한 후 Ansible로 각 서버의 기본 소프트웨어 스택을 구성합니다.

### 주요 특징
- ✅ **단순화된 구조**: Roles 없이 4개의 플레이북만으로 구성
- ✅ **자동화된 설치**: 기본 패키지, Docker, Nginx Gateway, NAT 자동 구성
- ✅ **Private Subnet 최적화**: Bastion Host + NAT Instance 설정
- ✅ **변수 중앙 관리**: group_vars를 통한 통합 변수 관리

### 설치되는 항목
- **모든 서버**: 기본 패키지, AWS CLI v2, Docker CE + Compose
- **Nginx Gateway**: Nginx 웹 서버, NAT 설정 (Private Subnet 인터넷 연결)

## 📁 디렉토리 구조

```
ansible/
├── README.md                       # 이 가이드 파일
├── ansible.cfg                     # Ansible 설정
├── group_vars/                     # 🌐 변수 관리
│   └── all/
│       └── main.yml               # 전역 변수
├── inventory/                      # 📦 서버 인벤토리
│   └── hosts.yml                  # 3개 서버 목록 (Nginx Gateway, 통합 메인, AI)
└── playbooks/                      # 🎮 실행 플레이북 (단순화)
    ├── site.yml                    # 🚀 메인 오케스트레이션 (전체 실행)
    ├── common.yml                  # 🔧 공통 시스템 설정
    ├── docker.yml                  # 🐳 Docker 설치
    └── nginx-gateway.yml           # 🌐 Nginx Gateway + NAT 설정
```

## 📖 Playbooks 설명

### site.yml - 메인 오케스트레이션 (전체 실행)
모든 초기 설정을 한 번에 실행하는 마스터 플레이북입니다.

**실행 순서:**
1. common.yml - 모든 서버에 기본 패키지 설치
2. docker.yml - 모든 서버에 Docker 설치
3. nginx-gateway.yml - Nginx Gateway에 Nginx + NAT 설정

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

**설치 완료 후:**
- 기본 시스템 구성 완료
- Docker 환경 준비 완료
- Nginx Gateway NAT 기능 활성화
- **다음 단계**: Nginx 리버스 프록시 설정 및 docker-compose.yml 배포 (수동)

---

### common.yml - 공통 시스템 설정
모든 서버의 기본 시스템 설정을 담당합니다.

**주요 작업:**
- apt 패키지 관리자 잠금 대기 (부팅 시 자동 업데이트 충돌 방지)
- 기본 패키지 설치 (curl, wget, git, vim, htop, net-tools 등)
- 시간대 설정 (Asia/Seoul)
- 로케일 설정 (en_US.UTF-8)
- 애플리케이션 디렉토리 생성 (/opt/mechuragi, /var/log/mechuragi 등)
- AWS CLI v2 설치

**대상:** 모든 서버 (all)

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/common.yml
```

---

### docker.yml - Docker 설치
Docker CE와 Docker Compose를 설치합니다.

**주요 작업:**
- 기존 Docker 버전 제거
- Docker GPG 키 및 저장소 추가
- Docker CE, CLI, Containerd 설치
- Docker Compose Plugin 설치
- Docker 그룹에 사용자 추가
- Docker 서비스 시작 및 활성화
- hello-world 컨테이너로 설치 검증

**대상:** 모든 서버 (all)

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/docker.yml
```

---

### nginx-gateway.yml - Nginx Gateway + NAT 설정
Nginx Gateway 서버에 Nginx 웹 서버와 NAT 기능을 설정합니다.

**주요 작업:**
- Nginx 설치 및 시작
- IP 포워딩 활성화 (net.ipv4.ip_forward = 1)
- iptables NAT 설정 (MASQUERADE)
- iptables 규칙 영구 저장

**대상:** Nginx Gateway만 (nginx_gateway)

**사용법:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/nginx-gateway.yml
```

**NAT 기능:**
Private Subnet의 Main Service와 AI Service가 Nginx Gateway를 통해 인터넷에 연결됩니다.

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

#### 전체 자동 배포

한 번의 명령으로 모든 초기 설정을 완료합니다.

```bash
# 전체 인프라 초기 설정
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

**배포 결과:**
- ✅ 모든 서버: 기본 패키지, AWS CLI, Docker 설치 완료
- ✅ Nginx Gateway: Nginx 및 NAT 설정 완료
- ✅ Private Subnet 서버들이 인터넷 연결 가능

**다음 단계 (수동 작업):**
1. Nginx Gateway에 리버스 프록시 설정 추가
2. Main Service에 docker-compose.yml 배포 (MySQL + Redis + API)
3. AI Service에 docker-compose.yml 배포

### 🔧 고급 사용법

#### 특정 호스트만 대상

```bash
# Nginx Gateway만
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit nginx_gateway

# 메인 서비스만
ansible-playbook -i inventory/hosts.yml playbooks/common.yml --limit main_service
```

#### 변수 오버라이드

```bash
# 사용자 이름 임시 변경
ansible-playbook -i inventory/hosts.yml playbooks/site.yml \
  -e "app_user=admin"

# 시간대 임시 변경
ansible-playbook -i inventory/hosts.yml playbooks/common.yml \
  -e "timezone=UTC"
```

#### 드라이런 (변경사항 미리보기)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check
```

#### 상세 로그 출력

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -v   # 일반
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -vv  # 상세
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -vvv # 매우 상세
```


## 📊 모니터링 및 검증

### 서비스 상태 확인

```bash
# 모든 서버 Ping 테스트
ansible all -i inventory/hosts.yml -m ping

# Docker 상태 확인
ansible all -i inventory/hosts.yml -m shell \
  -a "docker --version && docker compose version" --become

# Nginx 상태 확인 (Gateway만)
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "systemctl status nginx" --become

# NAT 설정 확인 (Gateway만)
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "sysctl net.ipv4.ip_forward" --become
```

### 연결성 테스트

```bash
# Private Subnet 서버의 인터넷 연결 확인
ansible main_service,ai_service -i inventory/hosts.yml -m shell \
  -a "curl -I https://www.google.com" --become

# Private Subnet 내부 통신 확인
ansible main_service -i inventory/hosts.yml -m shell \
  -a "ping -c 3 10.0.2.20" --become

# Nginx Gateway에서 Private 서버 접근 확인
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "ping -c 3 10.0.2.10" --become
```

### 로그 확인

```bash
# Nginx 로그 (Gateway만)
ansible nginx_gateway -i inventory/hosts.yml -m shell \
  -a "tail -20 /var/log/nginx/error.log" --become

# 시스템 로그
ansible all -i inventory/hosts.yml -m shell \
  -a "journalctl -u docker -n 20" --become
```

## 💡 베스트 프랙티스

### 1. 변수 관리
- 민감 정보는 `group_vars/`에 저장하고 `.gitignore`에 추가
- 환경별로 다른 값은 별도 인벤토리 사용
- 공통 값은 `group_vars/all/` 사용

### 2. 멱등성 유지
- 모든 playbook은 여러 번 실행해도 안전함
- `state: present` 같은 멱등성 있는 모듈 사용
- site.yml을 반복 실행해도 문제없음

### 3. 로그 활용
- 실패 시 `-vvv` 옵션으로 상세 로그 확인
- 각 태스크의 changed_when: false로 불필요한 변경 표시 방지

### 4. 핸들러 사용
- 설정 파일 변경 시에만 서비스 재시작
- nginx-gateway.yml에서 iptables 저장 핸들러 활용

### 5. 검증 강화
- 각 playbook에 검증 태스크 포함
- 설치 후 버전 확인 및 상태 확인

## 🔗 관련 문서

- **[메인 README](../README.md)**: 전체 인프라 개요
- **[Terraform 가이드](../terraform/README.md)**: 인프라 프로비저닝
- **[리팩토링 계획](../docs/refactoring.md)**: 아키텍처 개선 내역

---