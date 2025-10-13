#!/bin/bash

set -e

# 현재 시각 기반의 postfix 생성 (예: homeserver-20251011-153012)
LABEL="homeserver-$(date +%Y%m%d-%H%M%S)"

# 혹시 기존 homeserver-* 컨테이너가 있다면 제거
if docker ps -a --format '{{.Names}}' | grep -Eq '^homeserver-[0-9]{8}-[0-9]{6}$'; then
  echo "🧹 Removing old containers: homeserver-*"
  docker ps -a --format '{{.Names}}' \
    | grep -E '^homeserver-[0-9]{8}-[0-9]{6}$' \
    | xargs -r docker rm -f >/dev/null 2>&1 || true
fi

# 새 컨테이너 실행
echo "🚀 Running new container: ${LABEL}"

docker run -d \
  --name "${LABEL}" \
  -p 8080:80 \
  -v "$PWD/conf.d":/etc/nginx/conf.d:ro \
  -v "$PWD/html":/var/www/html:ro \
  -v "$PWD/nginx-log":/var/log/nginx:rw \
  nginx:alpine

echo "✅ Container '${LABEL}' is now running at http://localhost:8080"
