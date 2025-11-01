# VPC 내부 통신 문제 해결 가이드

## 문제 상황

EC2 인스턴스 (10.0.1.76)에서 MySQL 서버 (43.203.80.62)와 Redis 서버 (13.209.135.59)로 접근이 차단됩니다.

## 원인 분석

### 핵심 문제

**같은 VPC 내부에서는 반드시 Private IP를 사용해야 합니다!**

현재 애플리케이션 설정에서 MySQL과 Redis의 **Public IP**를 사용하려고 하는데, Security Group이 이를 차단하고 있습니다.

## 요약

### 문제의 핵심
- ❌ Public IP 
- ✅ Private IP 사용

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
