#!/bin/bash

# Tailscale 설치
if ! command -v tailscale &> /dev/null; then
  echo "Installing Tailscale..."
  brew install tailscale
else
  echo "Tailscale is already installed."
fi

# macOS에서 Tailscale 앱 실행 안내
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo ""
  echo "To start Tailscale service on macOS, run one of the following:"
  echo "  1. Open Tailscale app from Applications:"
  echo "     open -a Tailscale"
  echo ""
  echo "  2. Or start tailscaled manually:"
  echo "     sudo tailscaled"
fi
