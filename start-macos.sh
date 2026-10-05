#!/usr/bin/env bash

# ==============================================================================
# 9Router Quick Starter cho macOS
# Khởi động 9Router với quyền root để tự động quản lý cổng 443 và DNS
# ==============================================================================

CURRENT_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$CURRENT_USER")

ROUTER_BIN=""

if which 9router >/dev/null 2>&1; then
  ROUTER_BIN=$(which 9router)
fi

if [ -z "$ROUTER_BIN" ]; then
  for p in "$USER_HOME/.nvm/versions/node/"*/bin/9router /opt/homebrew/bin/9router /usr/local/bin/9router; do
    if [ -x "$p" ]; then
      ROUTER_BIN="$p"
      break
    fi
  done
fi

if [ -z "$ROUTER_BIN" ]; then
  echo "❌ Không tìm thấy lệnh 9router! Hãy chạy ./setup-macos.sh trước."
  exit 1
fi

echo "🚀 Đang khởi động 9Router với quyền quản trị..."
exec sudo "$ROUTER_BIN" "$@"
