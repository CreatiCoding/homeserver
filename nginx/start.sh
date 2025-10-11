#!/bin/bash

# 현재 시각 기반의 label 생성 (예: homeserver-20251011-153012)
LABEL="homeserver-$(date +%Y%m%d-%H%M%S)"

# 이미지 빌드
echo "🔨 Building Docker image: ${LABEL}"
docker build -t "${LABEL}" .

# 기존 컨테이너 중복 제거 (있을 경우)
if docker ps -a --format '{{.Names}}' | grep -q "^${LABEL}$"; then
  echo "🧹 Removing old container: ${LABEL}"
  docker rm -f "${LABEL}"
fi

# 새 컨테이너 실행
echo "🚀 Running container: ${LABEL}"
docker run -d --name "${LABEL}" -p 8080:80 "${LABEL}"

# 실행 확인
echo "✅ Container '${LABEL}' is now running at http://localhost:8080"
