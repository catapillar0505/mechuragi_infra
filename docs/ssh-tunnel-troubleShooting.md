🔧 트러블슈팅 로그 정리
1️⃣ MySQL Workbench에서 SSH 터널 연결 실패

에러 메시지:
Authentication failed, access denied

원인:

실제 키 파일 이름은 mechuragi-dev-key.pem 인데,
Workbench 설정에서는 mechuragi-key.pem 으로 잘못 지정함.

그래서 계속 “권한 문제”로 오해했지만, 실제 문제는 잘못된 파일명(경로 불일치) 이었음.

2️⃣ Windows에서 chmod 명령어가 적용되지 않음

배경:

Windows 환경에서는 chmod가 동작하지 않아, Workbench가 PEM 키를 읽지 못함.

따라서 NTFS 권한 도구인 icacls를 이용해 권한 수동 설정.

해결 과정 (PowerShell 명령어):

cd "C:\Users\catap\.ssh"
icacls "mechuragi-dev-key.pem" /inheritance:r
icacls "mechuragi-dev-key.pem" /grant:r "catap:(R)"
icacls "mechuragi-dev-key.pem" /remove "Users" "Authenticated Users" "Everyone"


결과:

파일 권한이 catap 사용자만 Read 권한을 가지도록 정리됨.

Workbench에서 PEM 파일 정상 인식.

3️⃣ Workbench SSH 터널 설정 오류

정상(정답) 설정:

메인 서버가 Jump Host (SSH Gateway) 역할을 하기 때문에,
SSH는 메인 서비스 서버로, DB는 내부 사설망 IP로 접근해야 함.

항목	설정값
SSH Hostname	메인 서비스 서버 Public IP
SSH Username	ubuntu
SSH Key File	C:\Users\catap\.ssh\mechuragi-dev-key.pem
MySQL Hostname	DB 서버 Private IP (10.0.x.x)

잘못된(오답) 설정:

항목	설정값
SSH Hostname	DB 서버 Public IP
SSH Username	ubuntu
SSH Key File	C:\Users\catap\.ssh\mechuragi-dev-key.pem
MySQL Hostname	127.0.0.1

원인 요약:

메인 서버가 SSH 게이트웨이 역할을 하는데,
DB 서버로 바로 SSH를 연결하려다 실패함.

따라서 SSH Host를 메인 서버로 지정하고, DB는 내부 IP로 접근해야 함.

✅ 최종 결론

파일명 혼동(mechuragi vs mechuragi-dev) → SSH 인증 실패

Windows chmod 무효 → icacls로 권한 직접 설정

SSH 터널 경로 오해 → 올바른 Jump Host(메인 서버) 지정 필요

결국, “권한 문제”로 보였던 모든 원인은
파일명 착오 + 잘못된 SSH 설정 조합 때문이었다.