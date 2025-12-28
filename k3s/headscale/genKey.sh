#!/bin/bash

HEADSCALE_NAME=$(kubectl get pods -n headscale -o jsonpath='{.items[0].metadata.name}')
USER=$1

if [ -z "$USER" ]; then
  echo "Usage: $0 <user>"
  exit 1
fi

# 사용자가 존재하는지 확인하고, 없으면 생성 (이미 존재해도 에러 무시)
EXISTING_USER=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list 2>/dev/null | grep -i "$USER" || echo "")

if [ -z "$EXISTING_USER" ]; then
  echo "User '$USER' not found. Creating user..."
  kubectl exec -n headscale $HEADSCALE_NAME -- headscale users create "$USER" 2>/dev/null || true
fi

# 사용자 ID 조회 (JSON 출력 사용 또는 테이블 형식 파싱)
# headscale users list의 출력 형식에 따라 조정 필요
USER_ID=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list 2>/dev/null | grep -i "$USER" | awk '{print $1}')

# JSON 출력을 시도해보기
if [ -z "$USER_ID" ]; then
  USER_ID=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list --output json 2>/dev/null | grep -i "\"name\":\"$USER\"" -A 5 | grep -i "\"id\"" | head -1 | sed 's/.*"id":\([0-9]*\).*/\1/' | tr -d ' ,')
fi

# 여전히 찾지 못하면 에러
if [ -z "$USER_ID" ]; then
  echo "Error: Failed to get user ID for '$USER'"
  echo "Available users:"
  kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list 2>/dev/null || true
  exit 1
fi

# 사용자 ID로 preauthkey 생성
kubectl exec -it -n headscale $HEADSCALE_NAME -- headscale preauthkeys create --user $USER_ID --reusable --expiration 24h