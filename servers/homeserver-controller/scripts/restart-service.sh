#!/bin/bash

set -e

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

SERVICE_NAME=$(node -p "require('./services.json')['$1'].name")
PORT=$(node -p "require('./services.json')['$1'].port")
CWD_PATH=$(node -p "require('./services.json')['$1'].cwd")
DOCKERFILE_PATH=$(node -p "require('./services.json')['$1'].dockerfile")

LABEL="$SERVICE_NAME-$(date +%Y%m%d-%H%M%S)"
REGEX_LABEL="$SERVICE_NAME-[0-9]{8}-[0-9]{6}"

# 혹시 실행중인 컨테이너가 있다면 중지
if docker ps --format '{{.Names}}' | grep -Eq "^${REGEX_LABEL}$"; then
  echo "🧹 Stopping running container(s): $SERVICE_NAME-*"
  docker ps --format '{{.Names}}' | grep -E "^${REGEX_LABEL}$" \
    | xargs -r docker stop >/dev/null 2>&1 || true
fi

# 혹시 동일 이름 컨테이너가 이미 있다면 제거
if docker ps -a --format '{{.Names}}' | grep -Eq "^${REGEX_LABEL}$"; then
  echo "🧹 Removing old container(s): $SERVICE_NAME-*"
  docker ps -a --format '{{.Names}}' | grep -E "^${REGEX_LABEL}$" \
    | xargs -r docker rm -f >/dev/null 2>&1 || true
fi

# 새 컨테이너 실행
echo "🚀 Running new container: ${LABEL}"

cd $CWD_PATH

git pull origin HEAD

docker build --build-arg PORT=$PORT -t "${LABEL}" . -f $DOCKERFILE_PATH

docker run -d \
  --name "${LABEL}" \
  -p $PORT:$PORT \
  "${LABEL}"

echo "✅ Container '${LABEL}' is now running at http://localhost:$PORT"
