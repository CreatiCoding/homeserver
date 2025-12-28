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

# 사용자 ID 조회 (JSON 출력 우선 사용, 색상 코드 제거)
# JSON 출력 시도
USER_JSON=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list --output json 2>/dev/null)
if [ -n "$USER_JSON" ]; then
  # JSON에서 사용자 ID 추출 (grep/sed 사용)
  USER_ID=$(echo "$USER_JSON" | grep -i "\"name\":\"$USER\"" -A 2 | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)
fi

# JSON이 실패하면 테이블 형식에서 색상 코드 제거 후 파싱
if [ -z "$USER_ID" ] || [ "$USER_ID" = "" ]; then
  # NO_COLOR 환경 변수로 색상 코드 비활성화 시도
  USER_ID=$(kubectl exec -n headscale $HEADSCALE_NAME -- env NO_COLOR=1 headscale users list 2>/dev/null | grep -i "$USER" | awk '{print $1}' | tr -d ' ')
  # 여전히 색상 코드가 있으면 sed로 제거
  if [ -z "$USER_ID" ] || [[ "$USER_ID" =~ [[:cntrl:]] ]]; then
    USER_ID=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list 2>/dev/null | grep -i "$USER" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}' | tr -d ' ')
  fi
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