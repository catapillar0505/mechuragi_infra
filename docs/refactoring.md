# 메추라기 인프라 리팩토링 문서

## 1. 리팩토링 개요

이 문서는 메추라기 프로젝트의 AWS 인프라 구조 개편 내용을 정리한 것입니다. 기존의 4개 인스턴스 분리 구조를 3개 인스턴스 통합 구조로 변경하여 비용 절감과 관리 효율성을 높이는 것이 목표입니다.

---

## 2. 기존 구조 (Before)

### 2.1 컴퓨팅 리소스 구성

기존에는 총 **4개의 EC2 인스턴스**가 각각 독립적으로 운영되었습니다:

#### 인스턴스 1: 메인 서비스 서버
- **인스턴스 타입**: t3.small
- **사설 IP**: 10.0.1.76 (고정)
- **Elastic IP**: 할당됨
- **역할**: Spring Boot API 서버
- **컨테이너화**: Docker 컨테이너로 운영
- **IAM 권한**: SES (이메일 발송)
- **보안 그룹**:
  - 인바운드: HTTP(80), HTTPS(443), SSH(22), Spring Boot(8080) - 전체 인터넷 허용
  - 아웃바운드: 모든 트래픽 허용

#### 인스턴스 2: AI 추천 서버
- **인스턴스 타입**: t3.small
- **사설 IP**: 10.0.1.184 (고정)
- **Elastic IP**: 할당됨
- **역할**: AI 추천 서비스 (AWS Bedrock 사용)
- **컨테이너화**: Docker 컨테이너로 운영
- **IAM 권한**: Bedrock (AI 모델 접근)
- **보안 그룹**:
  - 인바운드: SSH(22) - 인터넷 허용, Spring Boot AI(8082) - VPC 내부만
  - 아웃바운드: 모든 트래픽 허용

#### 인스턴스 3: MySQL 데이터베이스 서버
- **인스턴스 타입**: t3.micro
- **사설 IP**: 10.0.1.214 (고정)
- **Elastic IP**: 할당됨
- **역할**: MySQL 데이터베이스
- **설치 방식**: 네이티브 설치 (컨테이너 없음)
- **IAM 권한**: EC2 메타데이터 조회
- **보안 그룹**:
  - 인바운드: SSH(22) - 인터넷 허용, MySQL(3306) - VPC 내부만
  - 아웃바운드: 모든 트래픽 허용

#### 인스턴스 4: Redis 캐시 서버
- **인스턴스 타입**: t3.micro
- **사설 IP**: 10.0.1.185 (고정)
- **Elastic IP**: 할당됨
- **역할**: Redis 캐시 서버
- **설치 방식**: 네이티브 설치 (컨테이너 없음)
- **IAM 권한**: EC2 메타데이터 조회
- **보안 그룹**:
  - 인바운드: SSH(22) - 인터넷 허용, Redis(6379) - VPC 내부만
  - 아웃바운드: 모든 트래픽 허용

### 2.2 CloudFront 구성

CloudFront는 3개의 오리진을 통해 트래픽을 분산 처리했습니다:

#### Origin 1: React 프론트엔드 S3 버킷
- **경로**: 기본 경로 (/)
- **용도**: React SPA 정적 파일 제공
- **접근 방식**: Origin Access Control (OAC)
- **캐싱**: 1일 기본, 최대 1년
- **압축**: 활성화

#### Origin 2: 이미지 S3 버킷
- **경로**: /images/*
- **용도**: 사용자 업로드 이미지 제공
- **접근 방식**: Origin Access Control (OAC)
- **캐싱**: 1주일 기본, 최대 1년
- **압축**: 활성화

#### Origin 3: API 서버 (메인 서비스 인스턴스)
- **경로**: /api/*
- **용도**: REST API 요청 처리
- **타겟**: 메인 서비스 EC2의 Public DNS
- **프로토콜**: HTTP Only (EC2로는 80번 포트 접근)
- **주석 내용**: "Nginx는 80번 포트에서 리스닝"
- **캐싱**: 비활성화 (TTL 0)
- **압축**: 비활성화

### 2.3 기존 구조의 문제점

1. **높은 인프라 비용**: 4개의 독립 인스턴스 운영으로 EC2 비용 및 Elastic IP 비용 증가
2. **리소스 낭비**: MySQL과 Redis가 각각 t3.micro 인스턴스를 독점하며 유휴 리소스 발생
3. **복잡한 네트워크 관리**: 각 인스턴스마다 보안 그룹 및 ENI 설정 필요
4. **배포 복잡도**: 각 서비스가 독립 인스턴스에서 실행되어 통합 배포 어려움
5. **SSH 접근 분산**: 각 인스턴스에 직접 SSH 접근 필요 (보안 취약점)
6. **무중단 배포 미지원**: 블루-그린 배포 등 고급 배포 전략 부재

---

## 3. 개선 구조 (After)

### 3.1 컴퓨팅 리소스 구성

개선된 구조는 총 **3개의 EC2 인스턴스**로 통합 운영됩니다:

#### 인스턴스 1: 통합 메인 서버
- **인스턴스 타입**: t3.medium
- **서브넷 배치**: **Private Subnet** (외부 직접 접근 불가, Nginx NAT를 통한 아웃바운드만 가능)
- **네트워크 설정**:
  - **사설 IP만 할당** (Public IP 없음)
  - Private Subnet의 라우트 테이블이 Nginx ENI를 NAT 게이트웨이로 지정
- **역할**: MySQL, Redis, API 서버를 모두 포함
- **컨테이너 구성**:
  1. **MySQL 컨테이너**: 데이터베이스 서비스
  2. **Redis 캐시 컨테이너**: 캐싱 레이어
  3. **API 처리용 컨테이너**: Spring Boot API 서버
- **관리 방식**: docker-compose를 통한 통합 관리
- **Terraform 관리 범위**: EC2 인스턴스 프로비저닝만 담당, 컨테이너 오케스트레이션은 애플리케이션 레포지토리에서 관리
- **통신 경로**:
  - **인바운드**: Nginx 게이트웨이를 통해서만 접근 가능 (VPC 내부)
  - **아웃바운드**: Nginx NAT를 통해 인터넷 접근 (Docker Hub, AWS SES 등)
  - **컨테이너 간**: Docker 네트워크를 통한 localhost 통신
- **장점**:
  - 네트워크 레이턴시 최소화 (동일 호스트 내 통신)
  - 리소스 효율성 증가
  - 단일 인스턴스 관리로 운영 단순화
  - Public IP 비용 절감
  - 외부 공격 표면 제거 (보안 강화)

#### 인스턴스 2: AI 추천 서버
- **인스턴스 타입**: t3.small
- **서브넷 배치**: **Private Subnet** (외부 직접 접근 불가, Nginx NAT를 통한 아웃바운드만 가능)
- **네트워크 설정**:
  - **사설 IP만 할당** (Public IP 없음)
  - Private Subnet의 라우트 테이블이 Nginx ENI를 NAT 게이트웨이로 지정
- **변경 사항**: 통신 구조 개선 (아래 3.4절 참고)
- **역할**: AWS Bedrock 기반 AI 추천 서비스 + AI 게이트웨이
- **컨테이너 구성**: AI 서비스 컨테이너
- **IAM 권한**: Bedrock 접근
- **통신 경로**:
  - **인바운드**: Nginx 게이트웨이를 통해 프론트엔드 요청 수신
  - **아웃바운드**: Nginx NAT를 통해 Bedrock API 호출
  - **데이터베이스**: 통합 메인 서버의 MySQL에 직접 접근 (VPC 내부 통신)
- **유지 이유**: AI 워크로드는 독립적이며, Bedrock API 호출 특성상 분리 운영이 적합

#### 인스턴스 3: Nginx 게이트웨이 서버 (신규)
- **인스턴스 타입**: t3.micro (1 vCPU, 1GB RAM)
- **서브넷 배치**: **Public Subnet** (Internet Gateway를 통한 인터넷 양방향 통신)
- **네트워크 설정**:
  - **Public IP + Elastic IP 할당** (유일한 외부 통신 인스턴스)
  - Public Subnet의 라우트 테이블이 Internet Gateway를 기본 게이트웨이로 지정
  - **Source/Destination Check 비활성화** (NAT 동작을 위해 필수)
- **역할**:
  1. **리버스 프록시**: CloudFront에서 오는 API 요청을 메인 서버 또는 AI 서버로 라우팅
  2. **블루-그린 무중단 배포**: 트래픽 전환을 통한 무중단 배포 지원
  3. **SSH 게이트웨이 (Bastion Host)**: 모든 서버로의 SSH 접근을 Nginx 서버를 통해서만 허용 (보안 강화)
  4. **NAT 인스턴스**: Private Subnet에 있는 메인/AI 서버의 아웃바운드 인터넷 트래픽을 중계 (NAT Gateway 대체로 비용 절감)
     - Docker Hub 이미지 다운로드
     - AWS SES (이메일 발송)
     - AWS Bedrock API 호출
  5. **로드 밸런싱**: 필요 시 여러 메인 서버 인스턴스로 트래픽 분산
- **컨테이너 구성**: Nginx 컨테이너
- **NAT 동작 원리**:
  - Private Subnet의 라우트 테이블에서 0.0.0.0/0 트래픽을 Nginx ENI로 라우팅
  - Nginx 인스턴스에서 IP forwarding 활성화 (`net.ipv4.ip_forward=1`)
  - iptables MASQUERADE 규칙으로 Private IP를 Nginx의 Public IP로 변환
  - 응답 패킷은 NAT 테이블을 통해 원래 Private IP로 복원되어 전달
- **보안 강화**:
  - 메인 서버와 AI 서버는 SSH 포트를 VPC 내부(Nginx에서만)로 제한
  - 외부에서는 Nginx 서버를 통해서만 내부 서버 접근 가능
  - Bastion Host로 작동하여 SSH 접근을 중앙 집중화하고 감사 로그 수집 가능
  - 메인 서버와 AI 서버는 Public IP가 없어 직접적인 외부 공격 표면 제거
- **단점 및 대응**:
  - Nginx가 단일 장애점(SPOF)이 될 수 있음 → 향후 Auto Scaling Group으로 고가용성 확보
  - NAT 트래픽으로 인한 대역폭 부담 → 인스턴스 타입 적절히 선택 (네트워크 성능 고려)

### 3.2 CloudFront 구성

CloudFront 오리진 구성이 변경됩니다:

#### Origin 1: Nginx 서버 - API 경로 (신규 변경)
- **경로**: /api/*
- **타겟**: Nginx 서버의 Public DNS
- **변경 사항**:
  - 기존에는 메인 서버로 직접 연결
  - 이제는 Nginx 서버를 거쳐 메인 서버로 프록시
- **프로토콜**: HTTP/HTTPS
- **캐싱**: 비활성화 (API 응답)
- **추가 기능**:
  - 블루-그린 배포 시 Nginx에서 트래픽 전환
  - Health Check를 통한 자동 장애 조치

#### Origin 2: Nginx 서버 - AI 경로 (신규 추가)
- **경로**: /ai/* 또는 /recommend/*
- **타겟**: Nginx 서버의 Public DNS (동일 Origin)
- **용도**: AI 추천 요청을 AI 서버로 직접 라우팅
- **변경 사항**:
  - 기존에는 메인 서버를 거쳐 AI 서버로 간접 호출
  - 이제는 Nginx가 AI 서버로 직접 프록시하여 응답 속도 개선
  - AI 서버가 MySQL에서 사용자 정보를 직접 조회하고 Bedrock 호출 후 응답
- **프로토콜**: HTTP/HTTPS
- **캐싱**: 비활성화 (개인화된 AI 응답)

#### Origin 3: 이미지 S3 버킷
- **변경 사항**: 없음 (기존과 동일)
- **경로**: /images/*
- **용도**: 이미지 파일 CDN

#### Origin 4: 프론트엔드 S3 버킷
- **변경 사항**: 없음 (기존과 동일)
- **경로**: 기본 경로 (/)
- **용도**: React SPA 정적 파일

### 3.3 네트워크 및 보안 구성 변경

#### 보안 그룹 변경사항

**통합 메인 서버 보안 그룹**:
- 인바운드:
  - HTTP(80), HTTPS(443): Nginx 서버에서만 허용 (VPC 내부)
  - SSH(22): Nginx 서버에서만 허용 (VPC 내부)
  - MySQL(3306): AI 서버에서 접근 허용 (VPC 내부) - AI 서버가 사용자 정보 직접 조회
  - Redis(6379): 컨테이너 간 통신 (localhost)
- 아웃바운드: 모든 트래픽 허용

**Nginx 게이트웨이 보안 그룹** (신규):
- 인바운드:
  - HTTP(80), HTTPS(443): 인터넷 전체 허용 (CloudFront)
  - SSH(22): 관리자 IP만 허용 (화이트리스트)
- 아웃바운드: VPC 내부 통신 허용 (메인 서버, AI 서버로 프록시)

**AI 서버 보안 그룹**:
- 인바운드:
  - SSH(22): Nginx 서버에서만 허용 (VPC 내부)
  - Spring Boot AI(8082): Nginx 서버에서 허용 (VPC 내부) - 프론트엔드 요청 직접 처리
- 아웃바운드: 모든 트래픽 허용 (Bedrock API 호출, MySQL 접근)

### 3.4 AI 서버 통신 구조 개선

기존 구조에서는 AI 추천 응답이 느린 문제가 있었습니다. 이를 해결하기 위해 AI 서버의 통신 구조를 대폭 개선합니다.

#### 기존 통신 흐름 (Before)
1. 프론트엔드 → CloudFront → 메인 서버 (AI 추천 요청)
2. 메인 서버 → AI 서버 (사용자 정보 전달)
3. AI 서버 → Bedrock API (추천 생성)
4. AI 서버 → 메인 서버 (추천 결과 반환)
5. 메인 서버 → CloudFront → 프론트엔드 (최종 응답)

**문제점**:
- 메인 서버와 AI 서버 간 2번의 네트워크 왕복 (단계 2, 4)
- 메인 서버가 단순 중계 역할만 하면서 불필요한 레이턴시 추가
- 사용자 정보를 API 요청 본문으로 전달하면서 데이터 크기 증가

#### 개선된 통신 흐름 (After)
1. 프론트엔드 → CloudFront → Nginx → AI 서버 (AI 추천 요청, 사용자 ID만 전달)
2. AI 서버 → 메인 서버의 MySQL (사용자 정보 직접 조회 with Projection)
3. AI 서버 → Bedrock API (추천 생성)
4. AI 서버 → Nginx → CloudFront → 프론트엔드 (최종 응답)

**개선 사항**:
- **메인 서버 우회**: AI 서버가 AI 게이트웨이 역할을 수행하여 메인 서버 거치지 않음
- **데이터베이스 직접 접근**: AI 서버가 MySQL에 직접 연결하여 필요한 사용자 정보만 Projection으로 조회 (네트워크 오버헤드 최소화)
- **네트워크 홉 감소**: 5단계 → 4단계로 단축, 서버 간 불필요한 왕복 제거
- **응답 속도 향상**: 메인 서버 중계 단계 제거로 전체 레이턴시 30-40% 감소 예상

#### 필요한 추가 변경사항

**CloudFront 설정**:
- AI 추천 요청 경로에 대한 새로운 Cache Behavior 추가
- 경로 패턴을 AI 전용 엔드포인트로 설정하여 Nginx로 라우팅
- 캐싱 비활성화 (개인화된 AI 응답이므로)

**Nginx 라우팅 설정**:
- AI 요청 경로에 대해 AI 서버의 사설 IP 및 포트로 프록시 패스 설정
- Host 헤더와 Real IP 헤더를 전달하여 요청 출처 추적 가능하도록 구성
- Health Check 엔드포인트 설정으로 AI 서버 상태 모니터링

**AI 서버 애플리케이션**:
- MySQL 연결 설정을 통합 메인 서버의 사설 IP로 추가 (데이터베이스 직접 접근)
- JPA Repository에 필요한 필드만 조회하는 Projection 인터페이스 정의
- 사용자 선호도, 식단 타입 등 AI 추천에 필요한 최소한의 필드만 SELECT하여 네트워크 효율성 향상

**보안 그룹 설정**:
- 통합 메인 서버의 MySQL(3306) 포트를 AI 서버 사설 IP에서 접근 허용
- AI 서버의 8082 포트를 Nginx 서버에서 접근 허용

---

## 4. 리팩토링 이점

### 4.1 비용 절감
- **EC2 인스턴스 비용**: 4개 → 3개 인스턴스로 감소
- **Elastic IP 비용**: 4개 → 1개로 감소 (월 $9 절감)
  - 기존: 메인, AI, MySQL, Redis 모두 EIP 보유
  - 개선: Nginx만 EIP 보유, 나머지는 사설 IP만 사용
- **NAT Gateway 비용 제거**: Nginx를 NAT 인스턴스로 활용 (월 $30-40 절감)
  - NAT Gateway: 시간당 $0.045 + 데이터 처리 비용
  - Nginx NAT: 기존 인스턴스 활용으로 추가 비용 없음
- **데이터 전송 비용**: 동일 호스트 내 통신으로 VPC 간 데이터 전송 비용 제거
- **총 비용 절감**: 월 $40-50 절감 예상

### 4.2 성능 향상
- **네트워크 레이턴시 감소**: MySQL, Redis, API 서버가 동일 호스트에서 localhost 통신
- **캐시 효율성**: Redis와 API 서버 간 네트워크 홉 제거
- **AI 추천 속도 개선**: AI 서버가 메인 서버를 거치지 않고 직접 응답 (30-40% 레이턴시 감소)
- **데이터베이스 조회 최적화**: Projection을 통한 필요한 필드만 조회로 네트워크 대역폭 절약

### 4.3 운영 효율성
- **통합 배포 파이프라인**: docker-compose로 모든 서비스를 한 번에 배포 가능
- **무중단 배포 지원**: Nginx를 통한 블루-그린 배포 전략 구현
- **단일 진입점**: Nginx 게이트웨이를 통한 SSH 접근으로 보안 감사 용이

### 4.4 보안 강화
- **SSH 접근 제어**: 모든 서버는 Nginx 게이트웨이를 통해서만 SSH 접근 가능
- **공격 표면 축소**: MySQL, Redis 포트가 외부로 노출되지 않음
- **중앙화된 로깅**: Nginx에서 모든 API 요청 로그 수집 가능

### 4.5 확장성
- **수평 확장 준비**: Nginx 로드 밸런서로 메인 서버 인스턴스 추가 용이
- **블루-그린 배포**: Nginx 설정 변경만으로 새 버전 인스턴스로 트래픽 전환 가능
- **Auto Scaling 가능**: 향후 메인 서버를 Auto Scaling Group으로 전환 가능

---

## 5. 마이그레이션 고려사항

### 5.1 Terraform 변경 범위
- **compute 모듈**: 4개 인스턴스 → 3개 인스턴스 리소스 정의 변경
- **security 모듈**: 보안 그룹 4개 → 3개로 조정, 규칙 변경
- **cloudfront 모듈**: AI 경로 추가, Origin 타겟을 Nginx 서버로 변경
- **VPC 모듈**: 라우트 테이블에 Nginx를 기본 게이트웨이로 추가 (NAT 설정)
- **Nginx 인스턴스 설정**:
  - Source/Destination Check 비활성화 (NAT 동작 필수)
  - Elastic IP 할당
  - 사용자 데이터 스크립트로 NAT 설정 자동화 (iptables, IP forwarding)

### 5.2 애플리케이션 변경 범위
- **메인 서버 레포지토리**: docker-compose.yml 생성 (MySQL, Redis, API 컨테이너 정의)
- **환경 변수 변경**: MySQL과 Redis 연결 호스트를 localhost 또는 컨테이너 이름으로 변경
- **Nginx 설정**:
  - 리버스 프록시 설정 (메인 서버 및 AI 서버로 라우팅)
  - 블루-그린 배포 설정 (upstream 전환)
  - NAT 설정 (iptables MASQUERADE 규칙)
  - IP forwarding 활성화 (sysctl net.ipv4.ip_forward=1)
- **AI 서버 애플리케이션**: MySQL 연결 설정 추가 (메인 서버의 사설 IP)

### 5.3 데이터 마이그레이션
- **MySQL 데이터**: 기존 MySQL 인스턴스에서 덤프 후 새 컨테이너로 복원
- **Redis 데이터**: 캐시 데이터는 휘발성이므로 마이그레이션 불필요 (자연 재생성)
- **다운타임 계획**: Nginx를 통한 블루-그린 배포로 최소 다운타임 목표

### 5.4 롤백 계획
- **Terraform State 백업**: 변경 전 state 파일 백업 필수
- **기존 인스턴스 유지**: 마이그레이션 완료 및 안정화까지 기존 인스턴스 중지만 하고 삭제 보류
- **DNS 전환**: CloudFront Origin 설정을 단계적으로 전환하여 롤백 가능성 확보

---

## 7. 리팩토링 실행 계획 및 역할분담

### 7.1 인프라 영역 (Terraform)

#### Phase 1: VPC 및 네트워크 설정(진아)
1. VPC 모듈에 Private Subnet 추가 또는 라우트 테이블 수정
2. Nginx NAT용 라우트 테이블 생성 (0.0.0.0/0 → Nginx ENI)
3. 메인/AI 서버용 서브넷에 위 라우트 테이블 연결

#### Phase 2: 보안 그룹 재설계(진아)
4. 기존 4개 보안 그룹 → 3개로 통합
5. 통합 메인 서버 보안 그룹 생성
   - HTTP/HTTPS: Nginx에서만 허용
   - SSH: Nginx에서만 허용
   - MySQL(3306): AI 서버에서 허용
6. Nginx 게이트웨이 보안 그룹 생성 (신규)
   - HTTP/HTTPS: 인터넷 전체 허용
   - SSH: 관리자 IP만 허용
7. AI 서버 보안 그룹 수정
   - SSH: Nginx에서만 허용
   - 8082: Nginx에서만 허용

#### Phase 3: Compute 리소스 재구성(진아)
8. MySQL/Redis 인스턴스 리소스 제거 (Terraform)
9. 통합 메인 서버 인스턴스 정의
   - 인스턴스 타입 상향 (t3.medium 이상 권장)
   - Private IP만 할당 (ENI에서 Public IP 비활성화)
   - IAM Role: SES 권한 유지
10. AI 서버 인스턴스 수정
    - Private IP만 할당
    - IAM Role: Bedrock 권한 유지
11. Nginx 게이트웨이 인스턴스 생성
    - 인스턴스 타입: t3.micro (동접 100명 이하 소규모 프로젝트에 적합)
    - Public IP + Elastic IP 할당
    - `source_dest_check = false` 설정
    - 사용자 데이터 스크립트로 NAT 초기 설정

#### Phase 4: CloudFront 재구성(진아)
12. CloudFront Origin을 Nginx Public DNS로 변경
13. AI 전용 경로 Cache Behavior 추가 ( recommend/*)
14. 기존 /api/* 경로(crud 전용)도 Nginx로 라우팅되도록 수정
15. S3 버킷 정책 유지 (변경 없음)

#### Phase 5: 배포 및 검증(진아)
16. Terraform plan 실행하여 변경사항 검토
17. 테스트 환경에서 먼저 적용 (가능한 경우)
18. Production 환경 적용 (단계적 배포)
19. CloudWatch 알람 설정으로 모니터링 강화
20. 기존 인스턴스 중지 (삭제는 안정화 후)

---

### 7.2 애플리케이션 영역

#### Phase 1: 메인 서버 애플리케이션(희주)
1. docker-compose.yml 작성
   - MySQL 컨테이너 정의 (데이터 볼륨 마운트)
   - Redis 컨테이너 정의 (영속성 설정)
   - API 서버 컨테이너 정의 (Spring Boot)
2. 환경 변수 파일 수정 (.env)
   - MySQL 호스트: `mysql` (컨테이너 이름) 또는 `localhost`
   - Redis 호스트: `redis` (컨테이너 이름) 또는 `localhost`
3. Docker 네트워크 설정 (bridge 네트워크)
4. 헬스체크 엔드포인트 추가 (/health)
5. 로그 설정 (stdout으로 출력하여 CloudWatch 연동 준비)

#### Phase 2: AI 서버 애플리케이션(진아?)
6. MySQL 연결 설정 추가
   - 데이터베이스 URL: 메인 서버의 Private IP
   - 읽기 전용 권한 계정 사용 권장
7. JPA Repository에 Projection 인터페이스 추가
   - 사용자 선호도, 식단 타입 등 필요한 필드만 SELECT
8. AI 추천 API 엔드포인트를 독립 실행 가능하도록 수정
   - 기존: 메인 서버에서 사용자 정보 받음
   - 개선: 사용자 ID만 받고 직접 DB 조회
9. 헬스체크 엔드포인트 추가 (/health)
10. Bedrock API 호출 로직 유지 (변경 없음)

- stomp 웹소켓, 레디스 캐싱 ai 추천 속도 개선을 위해 활용
- 추천 결과 저장은 비동기적으로 진행(kafka는 오버고 적당한 기술 찾아보기)
- 스케쥴러 과부하 개선 및 메인 서버에서 웹소켓 사용이 오버엔지니어링이라면 sse로 바꾸기

#### Phase 3: Nginx 서버 설정(희주)
11. Nginx 컨테이너 이미지 준비 또는 네이티브 설치
12. 리버스 프록시 설정 파일 작성 (nginx.conf)
    - /api/* → 메인 서버 Private IP:8080
    - /ai/* → AI 서버 Private IP:8082
    - 헬스체크 프록시 설정
13. 블루-그린 배포 설정
    - upstream blue/green 정의
    - 전환 스크립트 작성 (nginx reload)
14. NAT 설정 스크립트 작성
    - IP forwarding 활성화 (`sysctl -w net.ipv4.ip_forward=1`)
    - iptables MASQUERADE 규칙 (`iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE`)
    - 부팅 시 자동 적용 설정 (/etc/sysctl.conf, rc.local)
15. SSL/TLS 인증서 설정 (Let's Encrypt 또는 ACM)
16. 로그 로테이션 설정 (액세스 로그, 에러 로그)

#### Phase 4: 데이터 마이그레이션 (희주)
17. 기존 MySQL 데이터베이스 덤프 (mysqldump)
18. 새 통합 메인 서버의 MySQL 컨테이너로 복원
19. 데이터 무결성 검증 (레코드 수, 샘플 데이터 확인)
20. Redis 데이터는 마이그레이션 불필요 (캐시 자연 재생성)

#### Phase 5: 배포 및 테스트
21. 통합 메인 서버에 docker-compose up -d 실행
22. AI 서버 애플리케이션 재배포
23. Nginx 서버 설정 적용 및 시작
24. 엔드투엔드 테스트
    - API 요청 테스트 (/api/*)
    - AI 추천 요청 테스트 (/ai/*)
    - 이미지 로드 테스트 (/images/*)
    - 프론트엔드 로드 테스트
25. 부하 테스트 (JMeter, Locust 등)
26. 모니터링 대시보드 확인 (CloudWatch, 로그 분석)

#### Phase 6: 최적화 및 안정화
27. 성능 튜닝 (Nginx worker 수, 커넥션 풀 크기 등)
28. 캐시 전략 최적화 (Redis TTL, 캐시 히트율 분석)
29. 데이터베이스 쿼리 최적화 (슬로우 쿼리 분석)
30. 알림 설정 (Slack, 이메일 등 통합)
31. 문서화 (운영 매뉴얼, 장애 대응 가이드)
32. 기존 인스턴스 완전 삭제 (안정화 확인 후)

---

## 8. 참고 문서

- [기존 README.md](../README.md): 현재 인프라 구조 상세 설명
- [Terraform 모듈](../terraform/modules/): 각 모듈별 리소스 정의
- [Ansible Playbooks](../ansible/): 서버 초기 설정 자동화