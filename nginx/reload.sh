#!/bin/bash
set -e

# 가장 최근 homeserver-* 컨테이너 찾기
LATEST=$(docker ps --filter "name=^homeserver-" --format "{{.Names}}" | head -n1)

if [ -z "$LATEST" ]; then
  echo "❌ homeserver-* 컨테이너를 찾을 수 없습니다."
  exit 1
fi

echo "🔁 Reloading nginx in container: $LATEST"

# 1. 설정 문법 검사
docker exec "$LATEST" nginx -t

# 2. 설정 반영 (무중단 reload)
docker exec "$LATEST" nginx -s reload

echo "✅ nginx reload 완료 (${LATEST})"