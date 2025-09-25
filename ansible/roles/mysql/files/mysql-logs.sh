#!/bin/bash
# MySQL 로그 확인 스크립트

LOG_DIR="/var/log/mysql"

echo "========================================="
echo "MySQL 로그 확인 스크립트"
echo "========================================="

echo ""
echo "1. MySQL 에러 로그 (최근 20줄):"
echo "-----------------------------------------"
if [ -f "$LOG_DIR/error.log" ]; then
    tail -20 "$LOG_DIR/error.log"
else
    echo "에러 로그 파일이 없습니다: $LOG_DIR/error.log"
fi

echo ""
echo "2. MySQL 슬로우 쿼리 로그 (최근 10줄):"
echo "-----------------------------------------"
if [ -f "$LOG_DIR/slow.log" ]; then
    tail -10 "$LOG_DIR/slow.log"
else
    echo "슬로우 쿼리 로그 파일이 없습니다: $LOG_DIR/slow.log"
fi

echo ""
echo "3. MySQL 서비스 상태:"
echo "-----------------------------------------"
systemctl status mysql --no-pager

echo ""
echo "4. MySQL 포트 리스닝 상태:"
echo "-----------------------------------------"
ss -tlnp | grep 3306 || echo "MySQL이 3306 포트에서 리스닝하지 않습니다"

echo ""
echo "5. MySQL 연결 테스트:"
echo "-----------------------------------------"
if [ -f "/root/.my.cnf" ]; then
    mysql -e "SELECT 'MySQL 연결 성공!' as status;" 2>/dev/null || echo "MySQL 연결 실패"
else
    echo "/root/.my.cnf 파일이 없습니다"
fi