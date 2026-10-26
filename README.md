<div align="center">

# 🏗️ 메추라기 — Infrastructure

### Claude AI 기반 메뉴 추천 커뮤니티 플랫폼의 AWS 인프라 (IaC)

**Terraform + Ansible로 3개 서버 기반 마이크로서비스 환경 전체를 코드로 구축·운영합니다.**

![Award](https://img.shields.io/badge/Programming%20GURU%20해커톤-Android%20부문%20대상%20🏆-gold?style=flat)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonwebservices&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=flat&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![OpenResty](https://img.shields.io/badge/OpenResty%20·%20Lua%20JWT-00A9A5?style=flat&logo=nginx&logoColor=white)
![k6](https://img.shields.io/badge/k6%20부하%20테스트-7D64FF?style=flat&logo=k6&logoColor=white)

📹 **시연 영상**: [YouTube Shorts](https://youtube.com/shorts/QZbuvk-MRn8?feature=share)

> 이 저장소는 [teamMechuragi/mechuragi_infra](https://github.com/teamMechuragi/mechuragi_infra)의 포크입니다.
> 인프라는 팀 내에서 **김진아([@catapillar0505](https://github.com/catapillar0505))가 단독 설계·구축**했으며,
> 원본 저장소의 **머지 PR 8개 전부(기여 100%)**를 작성했습니다.

</div>

---

## 🏆 수상

> ### Programming GURU 해커톤 **Android 부문 대상**
> 서울여자대학교 · 팀 Mechuragi · **2024.02**

---

## 🏗️ 아키텍처 구조도

<p align="center">
  <img src="./docs/images/architecture.png" width="820"/>
</p>

---

## 🙋 나의 역할 — 인프라 전 구간 단독 담당

- **Terraform**으로 AWS 인프라 아키텍처 설계 및 구축 — VPC · EC2 · S3 · CloudFront · ACM · SES · IAM (10개 모듈)
- **Ansible** 플레이북으로 서버 구성 자동화 — OpenResty, Docker, CloudWatch Agent, 로그 백업
- **OpenResty + Lua JWT 인증 게이트웨이** 구현 — 리버스 프록시 · Bastion · NAT 인스턴스를 1대로 통합
- **k6 부하 테스트**로 게이트웨이 라우팅 구조(Direct vs Legacy)를 정량 검증 후 채택
- 비용 최적화 — NAT Gateway 제거(월 $40-50 절감), EIP 4→1개, 인스턴스 통합
- SES 이메일(도메인 검증·DKIM·bounce 처리), SSE 스트리밍 프록시 설정, IaC 드리프트 해결 ([#7](https://github.com/teamMechuragi/mechuragi_infra/pull/7), [#8](https://github.com/teamMechuragi/mechuragi_infra/pull/8), [#9](https://github.com/teamMechuragi/mechuragi_infra/pull/9))

---

## 🛠️ 트러블슈팅 하이라이트

### 1. k6 부하 테스트 — 게이트웨이 직행(Direct) 구조 채택 근거

AI 추천 요청이 Main Server(Spring Security JWT)를 경유하는 Legacy 구조와, OpenResty에서 **Lua로 JWT를 검증하고 AI 서버로 직행**하는 Direct 구조를 k6로 비교했습니다. (VU 50 × 60초, Bedrock Mock 3,200ms, Tomcat 스레드 32개 제한)

| 지표 | Legacy | Direct | 변화 (Direct 기준) |
|------|--------|--------|------|
| avg | 5,033ms | 3,231ms | **-36%** |
| p95 | 6,470ms | 3,545ms | **-45%** |
| 처리량 (60s) | 195건 | 285건 | **+46%** |

Legacy는 인증 때문에 AI 요청도 메인 서버를 한 번 더 거치는 구조(홉 +1)였고, 긴 AI 요청과 짧은 일반 API가 같은 경로를 써서 무관한 API까지 함께 느려졌습니다. CloudFront `/recommend/*` 분리 + OpenResty Lua JWT 검증으로 AI 서버에 바로 보내도록 경로를 줄였고(Lua 인증 약 5ms), **처리량 +46%, p95 -45%**를 확인해 Direct Path를 채택했습니다. ([상세 분석](https://github.com/catapillar0505/mechuragi_main_server#2-k6-부하-테스트로-증명한-게이트웨이-구조-개선--direct-vs-legacy-97))

### 2. 운영하며 남긴 트러블슈팅 문서 6편

발생한 문제를 그때그때 문서로 남겼습니다. 각 문서는 증상 → 원인 → 해결 → 재발 방지 구조입니다.

| 문서 | 내용 |
|------|------|
| [IaC Drift 해결](docs/Iac-drift-troubleShooting.md) | 콘솔 수동 변경으로 발생한 Terraform 상태 불일치 해소 ([#9](https://github.com/teamMechuragi/mechuragi_infra/pull/9)) |
| [CloudFront 403 오류](docs/cloudfront-403-troubleshooting.md) | OAC·SPA 라우팅 조합에서의 403 원인 분석 |
| [VPC 내부 연결성](docs/vpc-internal-connectivity.md) | Private Subnet 서버 간 통신 문제 해결 ([#2](https://github.com/teamMechuragi/mechuragi_infra/pull/2), [#3](https://github.com/teamMechuragi/mechuragi_infra/pull/3)) |
| [SSH 터널링](docs/ssh-tunnel-troubleShooting.md) | Bastion 경유 접속 구성 |
| [이메일 서비스](docs/email-troubleShooting.md) | SES 도메인 검증·bounce 이슈 |
| [일반 트러블슈팅](docs/troubleshooting-guide.md) | 그 외 운영 이슈 모음 |

---

# Mechuragi Infrastructure

메추라기 프로젝트의 AWS 인프라 저장소입니다. Terraform(IaC)과 Ansible(Configuration Management)을 사용하여 3개 서버 기반의 통합 마이크로서비스 환경을 구성합니다.

- [Terraform 가이드](terraform/README.md): 모듈별 상세 설정
- [Ansible 가이드](ansible/README.md): 서버 구성 실행 설정

## 아키텍처 개요

```
                    ┌──────────────────────────────┐
                    │     사용자 (Browser/Mobile)   │
                    └──────────────┬───────────────┘
                                   │ HTTPS
                    ┌──────────────▼───────────────┐
                    │       CloudFront (CDN)        │
                    │  - 커스텀 도메인 + ACM SSL    │
                    │  - SPA URL Rewrite Function   │
                    └──┬─────────┬─────────┬───────┘
                       │         │         │
            ┌──────────▼──┐  ┌──▼─────┐  ┌▼──────────────────┐
            │  S3 (React) │  │S3(Img) │  │ OpenResty Gateway  │
            │  Frontend   │  │Images  │  │ Public Subnet      │
            └─────────────┘  └────────┘  │ JWT Auth (Lua)     │
                                         │ Reverse Proxy      │
                                         │ + Bastion + NAT    │
                                         └─┬──────────┬───────┘
                                           │          │
                        ┌──────────────────┘          └──────────────────┐
                        │         Private Subnet (VPC 내부)              │
             ┌──────────▼──────────┐                  ┌──────────▼──────┐
             │  통합 메인 서버      │                  │  AI 추천 서버    │
             │  ┌────────────────┐ │                  │  :8082          │
             │  │ MySQL :3306    │ │◄────MySQL────────│  + Bedrock      │
             │  │ Redis :6379    │ │                  │  AI Gateway     │
             │  │ API :8080/8081 │ │                  └─────────────────┘
             │  └────────────────┘ │
             │  Docker Compose     │
             │  Blue-Green 배포    │
             └─────────────────────┘
```

### 서비스 구조 (3개 인스턴스)

| 서버 | 위치 | 역할 |
|------|------|------|
| **OpenResty Gateway** | Public Subnet | 리버스 프록시 (JWT 인증) + Bastion Host + NAT Instance |
| **통합 메인 서버** | Private Subnet | MySQL + Redis + Spring Boot API (Docker Compose) |
| **AI 서버** | Private Subnet | Bedrock 연동 AI 추천 서비스, 메인 서버 MySQL 직접 접근 |

### 트래픽 흐름

- **API 요청**: CloudFront → OpenResty → Main Server (Spring Security 인증)
- **AI 추천**: CloudFront → OpenResty (Lua JWT 검증) → AI Server
- **OAuth 로그인**: CloudFront → OpenResty → Main Server (HTTPS 헤더 포워딩)
- **프론트엔드**: CloudFront → S3 (OAC)
- **SSE 스트리밍**: `proxy_buffering off`, 300초 read timeout

## 프로젝트 구조

```
mechuragi-infra/
├── terraform/                             # AWS 인프라 프로비저닝
│   ├── environments/
│   │   └── dev/                           # 개발 환경 설정
│   └── modules/                           # 재사용 가능한 모듈
│       ├── vpc/                           # VPC 네트워킹 (Public + Private Subnet)
│       ├── security/                      # 3계층 보안 그룹
│       ├── iam/                           # 서비스별 IAM Roles & Instance Profiles
│       ├── compute/                       # 3개 EC2 인스턴스 + NAT 라우트
│       ├── s3/                            # S3 버킷 (Frontend + Images + Logs)
│       ├── cloudfront/                    # 3-Origin CDN + SPA URL Rewrite Function
│       ├── acm-certificate/               # SSL/TLS 인증서 (us-east-1)
│       ├── ses/                           # 이메일 서비스
│       ├── bedrock/                       # AI 모델 설정 (SSM Parameter Store)
│       └── cloudwatch-logs/               # 서비스별 로그 그룹
├── ansible/                               # 서버 소프트웨어 구성
│   ├── inventory/hosts.yml                # 3개 서버 인벤토리
│   ├── group_vars/all/main.yml            # 전역 변수
│   ├── playbooks/
│   │   ├── site.yml                       # 메인 오케스트레이션
│   │   ├── common.yml                     # 공통 패키지 + AWS CLI
│   │   ├── docker.yml                     # Docker CE + Compose
│   │   └── nginx-gateway.yml              # OpenResty + JWT + NAT + 모니터링
│   └── templates/
│       ├── nginx.conf.j2                  # OpenResty 설정 (리버스 프록시 + JWT)
│       ├── cloudwatch-agent-config.json.j2
│       └── s3-log-backup.sh.j2
└── docs/                                  # 트러블슈팅 문서
```

## 인프라 구성 요소

### Terraform 모듈

| 모듈 | 설명 |
|------|------|
| **vpc** | VPC(10.0.0.0/16), Public/Private Subnet, Internet Gateway, Route Tables |
| **security** | 3계층 보안 그룹 (Gateway: 인터넷 허용 / Main: Nginx+AI만 / AI: Nginx만) |
| **iam** | 서비스별 최소 권한 IAM (Main: SES+S3+CloudWatch / AI: Bedrock+SSM / Nginx: S3 Logs+CloudWatch) |
| **compute** | EC2 3개 + ENI + EIP + NAT 라우트, AMI 변경 시 자동 교체 방지 (`ignore_changes = [ami]`) |
| **s3** | Frontend + Images + Logs 버킷 (AES-256 암호화, 퍼블릭 차단, Logs Lifecycle Policy) |
| **cloudfront** | 3-Origin CDN (Frontend/Images S3 + Nginx Gateway), SPA URL Rewrite CloudFront Function |
| **acm-certificate** | CloudFront용 SSL/TLS 인증서 (us-east-1, DNS 검증) |
| **ses** | 도메인 검증, DKIM, Configuration Set |
| **bedrock** | AI 모델 ID를 SSM Parameter Store에 저장, CloudWatch 로그 그룹 |
| **cloudwatch-logs** | 서비스별 로그 그룹 5개 (Main: MySQL/Redis/API, AI, Nginx) |

### Ansible Playbooks

| Playbook | 대상 | 설명 |
|----------|------|------|
| **site.yml** | 전체 | 아래 3개를 순서대로 실행하는 마스터 플레이북 |
| **common.yml** | 모든 서버 | 기본 패키지, 시간대(Asia/Seoul), 로케일, 디렉토리, AWS CLI v2 |
| **docker.yml** | 모든 서버 | Docker CE + Compose Plugin 설치 및 검증 |
| **nginx-gateway.yml** | Gateway만 | OpenResty + Lua JWT + NAT + logrotate + CloudWatch Agent + S3 로그 백업 |

### OpenResty Gateway 라우팅

| 경로 | 대상 | 인증 | 비고 |
|------|------|------|------|
| `/api/*` | Main Server | Spring Security | SSE 스트리밍 지원 |
| `/actuator/*` | Main Server | - | 헬스체크 |
| `/oauth2/authorization/*` | Main Server | - | OAuth 로그인 (HTTPS 헤더 포워딩) |
| `/login/oauth2/*` | Main Server | - | OAuth 콜백 처리 |
| `/oauth2/callback` | CloudFront | - | SPA 라우팅 리다이렉트 |
| `/recommend/food` | AI Server | Lua JWT 검증 | SSE 스트리밍 지원 |
| `/` | Main Server | - | 기본 프록시 |
| `/nginx-health` | - | - | Gateway 자체 헬스체크 |

## 배포 가이드

### 사전 준비

1. AWS CLI 설정 (AdministratorAccess 권한)
2. Terraform v1.0+, Ansible 2.9+ 설치
3. AWS 콘솔에서 SSH 키 페어 생성 후 로컬 저장 (`chmod 400`)

### 1단계: Terraform 인프라 배포

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 (키 페어, 도메인 등 설정)

terraform init
terraform plan
terraform apply
terraform output  # IP 주소, 버킷 이름 등 확인
```

### 2단계: Ansible 서버 구성

```bash
cd ansible

# inventory/hosts.yml에 Terraform output의 IP 주소 입력
# group_vars/all/main.yml에 필요한 변수 설정

# 전체 서버 구성 (한 번에 실행)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

### 3단계: React 프론트엔드 배포

```bash
npm run build
aws s3 sync ./build s3://<FRONTEND_BUCKET> --delete
aws s3 sync ./images s3://<IMAGES_BUCKET>/images/

# 필요시 CloudFront 캐시 무효화
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
```

### 4단계: Docker Compose 배포 (수동)

1. Main Service에 docker-compose.yml 배포 (MySQL + Redis + API)
2. AI Service에 docker-compose.yml 배포

## 보안 설계

### 네트워크 보안
- Private Subnet에 백엔드 서버 격리, Gateway만 Public 노출
- 3계층 보안 그룹 (최소 권한 원칙)
- NAT Instance로 Private Subnet 아웃바운드만 허용
- Blue-Green 배포용 8080/8081 포트 관리

### 데이터 보안
- EBS/S3 AES-256 암호화
- CloudFront OAC로 S3 직접 접근 차단
- HTTPS 강제 (CloudFront + ACM SSL)
- JWT 인증 (OpenResty Lua 기반)

### 접근 보안
- SSH 키 기반 인증, Bastion Host 경유 (ProxyCommand)
- IAM 최소 권한 (서비스별 필요 권한만)
- 민감 정보: `terraform.tfvars`, `terraform.tfstate`, `group_vars/all/main.yml`, `inventory/hosts.yml`에 포함되므로 공개 저장소 커밋 금지

## 비용 최적화

| 항목 | 내용 |
|------|------|
| NAT Gateway 제거 | Nginx 자체 NAT → 월 $40-50 절감 |
| Elastic IP 감축 | 4개 → 1개 → 월 $9 절감 |
| 인스턴스 통합 | MySQL/Redis 독립 인스턴스 제거 |
| 로그 Lifecycle | S3 30일→Standard-IA, 90일→Glacier, 365일→삭제 |

## 로그 수집 체계

모든 서비스 로그는 **CloudWatch Logs**로 중앙 수집됩니다. 로컬에 별도 로그를 수집하지 않습니다.

### 서비스별 수집 경로

| 서버 | 로그 소스 | 수집 방식 | 비고 |
|------|----------|----------|------|
| 메인 서버 | MySQL / Redis / API 컨테이너 | Docker 로그 드라이버 → CloudWatch | 로그 그룹 3개 |
| AI 서버 | AI 컨테이너 | Docker 로그 드라이버 → CloudWatch | 로그 그룹 1개 |
| Nginx Gateway | OpenResty access/error 로그 | CloudWatch Agent → CloudWatch | 로그 그룹 1개 |

### Nginx Gateway 로그 관리 (다중 계층)

1. **로컬 파일**: `/var/log/openresty/access.log`, `error.log` (logrotate 일별 로테이션, 30일 보관)
2. **CloudWatch Agent**: 로컬 로그를 실시간 CloudWatch Logs 전송 (60초 간격)
3. **S3 아카이빙**: 매일 02:00 cron으로 압축 로그를 S3 Logs 버킷에 업로드

### 로그 보존 정책

| 저장소 | 보존 기간 |
|--------|----------|
| CloudWatch Logs | 30일 (변수로 조정 가능) |
| Bedrock 로그 | 14일 |
| S3 Logs 버킷 | 30일 Standard → 90일 Glacier → 365일 삭제 |
| Nginx 로컬 | 30일 (logrotate + cron 자동 삭제) |

## 문서

### 트러블슈팅
- [IaC Drift 해결](docs/Iac-drift-troubleShooting.md)
- [CloudFront 403 오류](docs/cloudfront-403-troubleshooting.md)
- [VPC 내부 연결성](docs/vpc-internal-connectivity.md)
- [SSH 터널링](docs/ssh-tunnel-troubleShooting.md)
- [이메일 서비스](docs/email-troubleShooting.md)
- [일반 트러블슈팅](docs/troubleshooting-guide.md)

### 기타
- [도메인 설정](docs/domain.md)
- [리팩토링 계획](docs/refactoring-plan.md)

---

## 관련 저장소

- 🐦 [mechuragi_main_server (포크)](https://github.com/catapillar0505/mechuragi_main_server) — Spring Boot 메인 백엔드 (전체 기여 요약 포함)
- 🤖 [mechuragi_ai_server (포크)](https://github.com/catapillar0505/mechuragi_ai_server) — AWS Bedrock Claude 추천 엔진
- 💻 [mechuragi_client (포크)](https://github.com/catapillar0505/mechuragi_client) — Next.js 웹 클라이언트
- 🏗️ [팀 원본 저장소](https://github.com/teamMechuragi/mechuragi_infra)
