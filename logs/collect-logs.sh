#!/bin/bash

# 로그 수집 스크립트
# 서버의 로그들을 로컬 mechuragi-infra/logs 디렉토리로 수집합니다.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"
INVENTORY="$ANSIBLE_DIR/inventory/hosts.yml"

echo "========================================="
echo "메추라기 서비스 로그 수집 시작"
echo "========================================="

# MySQL 로그 수집
echo "📊 MySQL 로그 수집 중..."
ansible mysql-server -i "$INVENTORY" -m fetch -a "src=/var/log/mysql/error.log dest=$SCRIPT_DIR/mysql/ flat=yes" --become 2>/dev/null || echo "MySQL 에러 로그 수집 실패"
ansible mysql-server -i "$INVENTORY" -m fetch -a "src=/var/log/mysql/slow.log dest=$SCRIPT_DIR/mysql/ flat=yes" --become 2>/dev/null || echo "MySQL 슬로우 로그 수집 실패"

# Redis 로그 수집
echo "💾 Redis 로그 수집 중..."
ansible redis-server -i "$INVENTORY" -m fetch -a "src=/var/log/redis/redis-server.log dest=$SCRIPT_DIR/redis/ flat=yes" --become 2>/dev/null || echo "Redis 로그 수집 실패"

# Docker 컨테이너 로그 수집
echo "🐳 애플리케이션 로그 수집 중..."
ansible main-service-server -i "$INVENTORY" -m shell -a "docker logs mechuragi-main-service --tail 100 > /tmp/main-service.log 2>&1" --become 2>/dev/null || echo "메인 서비스 로그 생성 실패"
ansible main-service-server -i "$INVENTORY" -m fetch -a "src=/tmp/main-service.log dest=$SCRIPT_DIR/main-service/ flat=yes" --become 2>/dev/null || echo "메인 서비스 로그 수집 실패"

ansible ai-service-server -i "$INVENTORY" -m shell -a "docker logs mechuragi-ai-service --tail 100 > /tmp/ai-service.log 2>&1" --become 2>/dev/null || echo "AI 서비스 로그 생성 실패"
ansible ai-service-server -i "$INVENTORY" -m fetch -a "src=/tmp/ai-service.log dest=$SCRIPT_DIR/ai-service/ flat=yes" --become 2>/dev/null || echo "AI 서비스 로그 수집 실패"

echo ""
echo "✅ 로그 수집 완료!"
echo "수집된 로그 확인:"
echo "- MySQL: $SCRIPT_DIR/mysql/"
echo "- Redis: $SCRIPT_DIR/redis/"
echo "- 메인 서비스: $SCRIPT_DIR/main-service/"
echo "- AI 서비스: $SCRIPT_DIR/ai-service/"

# 타임스탬프 파일 생성
echo "$(date)" > "$SCRIPT_DIR/last_collected.txt"