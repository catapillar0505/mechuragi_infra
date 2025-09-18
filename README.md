# Mechuragi Infrastructure

메추라기 프로젝트의 AWS 인프라스트럭처를 관리하는 저장소입니다. Terraform과 Ansible을 사용하여 클라우드 인프라의 프로비저닝과 서버 설정을 자동화합니다.

## 🏗️ 프로젝트 구조

```
mechuragi-infra/
├── terraform/                          # AWS 인프라 프로비저닝
│   ├── environments/
│   │   └── dev/                        # 개발 환경 설정
│   │       ├── main.tf                 # 메인 테라폼 설정
│   │       ├── variables.tf            # 변수 정의
│   │       ├── outputs.tf              # 출력 값 정의
│   │       └── terraform.tfvars.example # 변수 예시 파일
│   └── modules/                        # 재사용 가능한 테라폼 모듈
│       ├── vpc/                        # VPC 및 네트워크 구성
│       ├── security/                   # 보안 그룹 설정
│       ├── compute/                    # EC2 인스턴스 설정
│       └── s3/                         # S3 버킷 설정
└── ansible/                            # 서버 구성 관리
    ├── README.md                       # Ansible 실행 가이드
    ├── ansible.cfg                     # Ansible 설정
    ├── group_vars/
    │   └── all.yml                     # 변수 설정 (Git 제외)
    ├── inventory/
    │   ├── hosts.yml                   # 서버 인벤토리 (Git 제외)
    │   └── hosts.yml.template          # 인벤토리 템플릿
    └── playbooks/                      # 모듈화된 플레이북
        ├── setup-system.yml           # 시스템 기본 설정
        ├── setup-docker.yml           # Docker 환경 구성
        ├── setup-services.yml         # MySQL, Redis 서비스
        ├── setup-database.yml         # 데이터베이스 초기화
        ├── verify-setup.yml           # 설정 검증
        └── setup-server.yml.backup    # 기존 통합 플레이북 백업
```

## 🏛️ 인프라 구성

### AWS 리소스

- **VPC**: 10.0.0.0/16 CIDR 블록
  - Public Subnet: 10.0.1.0/24 (ap-northeast-2a)
  - Private Subnet: 10.0.10.0/24 (ap-northeast-2b)
- **EC2**: Amazon Linux 2, t3.micro 인스턴스 (EBS 암호화)
- **보안 그룹**: HTTP(80), HTTPS(443), SSH(22), Spring Boot(8080), MySQL(3306), Redis(6379)
- **S3**: 이미지 저장용 버킷 (CORS 설정, 버전 관리 활성화)
- **Elastic IP**: 고정 공인 IP 할당

### 서버 소프트웨어

- **Docker & Docker Compose**: 컨테이너 관리
- **MySQL 8.0**: Docker 컨테이너로 실행
- **Redis 6**: 시스템 서비스로 실행
- **개발 도구**: git, curl, wget, vim, htop

## 🚀 사용 방법

### 1단계: Terraform으로 인프라 프로비저닝

```bash
# 1. 변수 파일 설정
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에서 실제 값 입력

# 2. 인프라 배포
terraform init
terraform plan
terraform apply
```

### 2단계: Ansible로 서버 설정

```bash
cd ansible

# 1. 변수 파일 설정
# group_vars/all.yml과 inventory/hosts.yml 설정
# (자세한 방법은 ansible/README.md 참조)

# 2. 순차적 설정 실행
ansible-playbook -i inventory/hosts.yml playbooks/setup-system.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-docker.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-services.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup-database.yml
ansible-playbook -i inventory/hosts.yml playbooks/verify-setup.yml
```

## ⚙️ 설정 파일

### 🔧 Terraform 설정

**terraform.tfvars** (생성 필요):
```hcl
aws_region    = "ap-northeast-2"
project_name  = "mechuragi"
environment   = "dev"
vpc_cidr      = "10.0.0.0/16"
instance_type = "t3.micro"
key_pair_name = "your-actual-key-name"
```

### 🔧 Ansible 설정

**group_vars/all.yml** (생성 필요):
```yaml
# 서버 연결 정보
ansible_host: "YOUR_SERVER_IP"
ansible_ssh_private_key_file: "~/.ssh/YOUR_KEY.pem"

# MySQL 설정
mysql_root_password: "YOUR_MYSQL_PASSWORD"
mysql_app_password: "YOUR_APP_PASSWORD"

# 기타 설정...
```

## 🔒 보안 설정

### Git에서 제외되는 민감한 파일들:
- `terraform/environments/dev/terraform.tfvars`
- `terraform/environments/dev/*.tfstate*`
- `ansible/group_vars/all.yml`
- `ansible/inventory/hosts.yml`
- `*.pem`, `*.key` (SSH 키)

### 보안 모범 사례:
- ✅ EBS 볼륨 암호화 활성화
- ✅ SSH 키 기반 인증
- ✅ 보안 그룹으로 포트 제한
- ✅ MySQL/Redis VPC 내부 접근만 허용
- ✅ 민감한 정보 Git 제외

## 📊 출력 정보

### Terraform 출력:
- EC2 공인 IP 주소
- SSH 접속 명령어
- S3 버킷 이름

### Ansible 검증 결과:
- 포트 리스닝 상태
- 서비스 실행 상태
- 시스템 리소스 사용량
- Docker 컨테이너 목록

## 📋 전제 조건

- **AWS CLI** 설정 및 인증 완료
- **Terraform** 1.0 이상
- **Ansible** 2.9 이상
- **AWS 키 페어** 생성 완료
- **Python 3.8+** (대상 서버)

## 🎯 주요 특징

- **모듈화된 아키텍처**: 책임별로 분리된 플레이북
- **멱등성 보장**: 여러 번 실행해도 안전
- **보안 중심**: 민감한 정보 분리 관리
- **자동화된 검증**: 설치 후 상태 확인 자동화
- **단계별 실행**: 필요한 부분만 선택적 실행 가능

## 🔧 문제 해결

### 연결 테스트:
```bash
ansible all -m ping -i inventory/hosts.yml
```

### 서비스 상태 확인:
```bash
ansible all -m command -a "systemctl is-active docker redis" --become -i inventory/hosts.yml
```

### Docker 컨테이너 확인:
```bash
ansible all -m command -a "docker ps" --become -i inventory/hosts.yml
```

## 📚 추가 정보

- Terraform 모듈 구조와 변수는 각 모듈의 `variables.tf` 참조
- Ansible 플레이북 실행 방법은 `ansible/README.md` 참조
- 보안 설정 및 변수 관리는 `.gitignore` 파일 참조

---

**⚠️ 주의사항**: 이 인프라는 개발 환경용으로 설계되었습니다. 프로덕션 환경에서는 추가적인 보안 강화가 필요합니다.