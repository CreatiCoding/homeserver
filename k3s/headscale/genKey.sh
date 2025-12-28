#!/bin/bash

HEADSCALE_NAME=$(kubectl get pods -n headscale -o jsonpath='{.items[0].metadata.name}')
USER=$1

if [ -z "$USER" ]; then
  echo "Usage: $0 <user>"
  exit 1
fi

# 사용자가 존재하는지 확인하고, 없으면 생성
EXISTING_USER=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list 2>/dev/null | grep -w "$USER" || echo "")

if [ -z "$EXISTING_USER" ]; then
  echo "User '$USER' not found. Creating user..."
  kubectl exec -n headscale $HEADSCALE_NAME -- headscale users create "$USER"
fi

# 사용자 ID 조회 (첫 번째 컬럼이 ID라고 가정)
USER_ID=$(kubectl exec -n headscale $HEADSCALE_NAME -- headscale users list 2>/dev/null | grep -w "$USER" | awk '{print $1}')

if [ -z "$USER_ID" ]; then
  echo "Error: Failed to get user ID for '$USER'"
  exit 1
fi

# 사용자 ID로 preauthkey 생성
kubectl exec -it -n headscale $HEADSCALE_NAME -- headscale preauthkeys create --user $USER_ID --reusable --expiration 24h