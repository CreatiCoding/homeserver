#!/bin/bash

# 환경 변수 확인
if [ -z "$TAILSCALE_SERVER" ] || [ -z "$TAILSCALE_AUTH_KEY" ]; then
  echo "Error: TAILSCALE_SERVER and TAILSCALE_AUTH_KEY environment variables must be set"
  echo "Usage: export TAILSCALE_SERVER=https://headscale.creco.dev"
  echo "       export TAILSCALE_AUTH_KEY=<your-auth-key>"
  exit 1
fi

# macOS에서 Tailscale 서비스가 실행 중인지 확인하고, 없으면 자동으로 시작
if [[ "$OSTYPE" == "darwin"* ]]; then
  # tailscaled 프로세스 확인
  if ! pgrep -x "tailscaled" > /dev/null; then
    echo "Tailscale service is not running. Starting tailscaled..."
    sudo tailscaled > /dev/null 2>&1 &
    # 서비스가 시작될 때까지 잠시 대기
    sleep 2
    
    # 여전히 실행되지 않으면 에러
    if ! pgrep -x "tailscaled" > /dev/null; then
      echo "Error: Failed to start tailscaled. Please run manually:"
      echo "  sudo tailscaled"
      exit 1
    fi
    echo "Tailscale service started successfully."
  fi
fi

# Tailscale 연결
sudo tailscale up --login-server=$TAILSCALE_SERVER --authkey=$TAILSCALE_AUTH_KEY