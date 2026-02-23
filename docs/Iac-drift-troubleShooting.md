# 🧩 트러블슈팅 로그

## AI Server ↔ Main Server 통신 오류

### 📍 이슈 개요
AI 서버와 메인 서버 간 통신이 되지 않음.

---

### ⚙️ 원인
- Terraform IAC **드리프트 발생**
- AI 서버 포트가 `8081 → 8082`로 변경되었으나  
  Terraform 보안 그룹 설정에 해당 변경이 **반영되지 않음**
- 변경이 반영된 줄 알고 배포 진행 → 실제 인프라에는 업데이트되지 않아 통신 불가 상태 발생

---

### 🔍 해결 과정
1. Terraform 설정 검토 중, 보안 그룹의 포트 변경 누락 확인  
2. `dev/environment/output` 내 포트 번호 관리 로직 추가  
3. `group_vars`에도 서버별 포트 정보를 등록하여 일원화  
4. `terraform apply` 실행 시 포트 변경 내역이 시각적으로 드러나도록 구조 개선

---

### ✅ 최종 해결책
- Terraform 보안 그룹 및 output에 포트번호를 **명시적으로 관리**  
- `group_vars`에서 서버별 포트번호를 **중앙 관리**  
- `terraform apply` 시 변경사항이 **시각적으로 확인**되도록 절차 개선

---

### 💡 결론
Terraform IAC와 실제 인프라 간 설정 불일치(드리프트)가 통신 오류의 직접 원인이었음.
포트 정보를 코드 기반으로 중앙 집중 관리하도록 리팩토링하여 **재발 방지 조치 완료**.

---
---

## CloudFront Function + EC2 AMI Drift

### 📍 이슈 개요
`terraform plan` 실행 시 **EC2 인스턴스 3개 destroy/recreate** 및 **CloudFront 설정 변경**이 감지됨.
코드를 변경하지 않았는데도 `Plan: 3 to add, 4 to change, 3 to destroy`가 출력되는 상황.

---

### ⚙️ 원인

**1. CloudFront Function 미관리 (콘솔 수동 설정)**
- AWS 콘솔에서 `AddIndexHtml` CloudFront Function을 수동 생성하고 `/oauth2/callback/*` 경로에 연결
- Terraform 코드에는 `aws_cloudfront_function` 리소스와 `function_association` 블록이 **존재하지 않음**
- SPA에서 확장자 없는 경로(`/oauth2/callback`)를 `/oauth2/callback/index.html`로 rewrite하는 함수

**2. EC2 AMI 자동 갱신 (`most_recent = true`)**
- `data.aws_ami.ubuntu`에 `most_recent = true` 설정
- Canonical이 새 Ubuntu AMI를 출시하면, plan 시 최신 AMI가 조회됨
- EC2의 AMI는 변경 불가 속성이므로 **인스턴스 삭제 후 재생성(replace)** 으로 판단
- 코드를 아무것도 안 바꿔도 시간이 지나면 서버 3개가 날아가는 위험

---

### 🔍 해결 과정

**CloudFront Function:**
1. `modules/cloudfront/main.tf`에 `aws_cloudfront_function` 리소스 추가 (이름: `AddIndexHtml`)
2. `/oauth2/callback/*` behavior에 `function_association` 블록 추가
3. 기존 콘솔 리소스를 `terraform import`로 state에 등록
   ```bash
   terraform import 'module.cloudfront.aws_cloudfront_function.spa_url_rewrite' AddIndexHtml
   ```
4. 코드와 콘솔 간 trailing space 차이를 `terraform apply -target`으로 해소

**EC2 AMI:**
1. 3개 인스턴스의 `lifecycle` 블록에 `ignore_changes = [ami]` 추가
   ```hcl
   lifecycle {
     ignore_changes = [ami, network_interface]
   }
   ```
2. AMI가 변경되어도 기존 인스턴스를 유지하도록 설정

---

### ✅ 최종 결과
- `terraform plan` 실행 시 `No changes. Your infrastructure matches the configuration.` 확인
- CloudFront Function이 Terraform으로 관리되어 향후 drift 방지
- EC2 인스턴스가 AMI 업데이트로 인해 의도치 않게 재생성되는 위험 제거

---

### 💡 교훈
- AWS 콘솔에서 수동으로 변경한 리소스는 반드시 `terraform import`로 state에 반영할 것
- `most_recent = true`로 AMI를 조회하는 경우, 반드시 `ignore_changes = [ami]`를 함께 설정할 것
- 정기적으로 `terraform plan`을 실행하여 drift를 조기에 발견할 것
