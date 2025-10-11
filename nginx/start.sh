#!/bin/bash

set -e

# 현재 시각 기반의 postfix 생성 (예: homeserver-20251011-153012)
LABEL="homeserver-$(date +%Y%m%d-%H%M%S)"

# 혹시 동일 이름 컨테이너가 이미 있다면 제거
if docker ps -a --format '{{.Names}}' | grep -q "^${LABEL}$"; then
  echo "🧹 Removing old container: ${LABEL}"
  docker rm -f "${LABEL}" >/dev/null 2>&1 || true
fi

# 새 컨테이너 실행
echo "🚀 Running new container: ${LABEL}"

docker run -d \
  --name "${LABEL}" \
  -p 8080:80 \
  -v "$PWD/configs":/etc/nginx:ro \
  -v "$PWD/html":/var/www/html:ro \
  nginx:alpine

echo "✅ Container '${LABEL}' is now running at http://localhost:8080"
