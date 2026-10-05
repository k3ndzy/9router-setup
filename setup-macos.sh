#!/usr/bin/env bash

# ==============================================================================
# 9Router 1-Click Installer & Optimizer for macOS
# Tự động cài đặt, cấu hình chứng chỉ SSL, DNS và vá toàn bộ lỗi cho 9Router
# ==============================================================================

set -e

# Màu sắc hiển thị
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}${BOLD}======================================================${NC}"
echo -e "${CYAN}${BOLD}       🚀 9Router Auto-Setup & Fixer cho macOS        ${NC}"
echo -e "${CYAN}${BOLD}======================================================${NC}"
echo ""

# 1. Kiểm tra quyền sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}🔑 Script cần quyền Quản trị viên (sudo) để cấu hình SSL Keychain và cổng 443.${NC}"
  echo -e "${YELLOW}Vui lòng nhập mật khẩu máy Mac của bạn:${NC}"
  exec sudo bash "$0" "$@"
fi

CURRENT_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$CURRENT_USER")
ROUTER_DATA_DIR="$USER_HOME/.9router"
MITM_DIR="$ROUTER_DATA_DIR/mitm"

echo -e "${CYAN}👤 Đang cài đặt cho người dùng: ${BOLD}$CURRENT_USER${NC}"

# 2. Tìm Node.js và NPM
echo -e "${CYAN}🔍 Kiểm tra môi trường Node.js...${NC}"

NODE_BIN=""
NPM_BIN=""

# Thử tìm theo PATH của user
if sudo -u "$CURRENT_USER" which node >/dev/null 2>&1; then
  NODE_BIN=$(sudo -u "$CURRENT_USER" which node)
  NPM_BIN=$(sudo -u "$CURRENT_USER" which npm)
fi

# Thử tìm các vị trí NVM phổ biến
if [ -z "$NODE_BIN" ]; then
  for nvm_node in "$USER_HOME/.nvm/versions/node/"*/bin/node; do
    if [ -x "$nvm_node" ]; then
      NODE_BIN="$nvm_node"
      NPM_BIN="$(dirname "$nvm_node")/npm"
      break
    fi
  done
fi

# Thử Homebrew & /usr/local
if [ -z "$NODE_BIN" ]; then
  for p in /opt/homebrew/bin/node /usr/local/bin/node; do
    if [ -x "$p" ]; then
      NODE_BIN="$p"
      NPM_BIN="$(dirname "$p")/npm"
      break
    fi
  done
fi

if [ -z "$NODE_BIN" ]; then
  echo -e "${RED}❌ Không tìm thấy Node.js trên máy!${NC}"
  echo -e "${YELLOW}Vui lòng cài đặt Node.js (>= 18) trước tại: https://nodejs.org hoặc qua Homebrew: brew install node${NC}"
  exit 1
fi

echo -e "${GREEN}✔ Tìm thấy Node.js tại: $NODE_BIN ($($NODE_BIN -v))${NC}"
echo -e "${GREEN}✔ Tìm thấy NPM tại: $NPM_BIN${NC}"

# 3. Kiểm tra và cài đặt 9router qua NPM nếu chưa có
echo -e "${CYAN}📦 Kiểm tra package 9router...${NC}"
if ! sudo -u "$CURRENT_USER" PATH="$(dirname "$NODE_BIN"):$PATH" which 9router >/dev/null 2>&1; then
  echo -e "${YELLOW}Đang cài đặt 9router globally...${NC}"
  sudo -u "$CURRENT_USER" PATH="$(dirname "$NODE_BIN"):$PATH" "$NPM_BIN" install -g 9router
  echo -e "${GREEN}✔ Đã cài đặt 9router thành công!${NC}"
else
  echo -e "${GREEN}✔ 9router đã được cài đặt sẵn.${NC}"
fi

ROUTER_BIN=$(sudo -u "$CURRENT_USER" PATH="$(dirname "$NODE_BIN"):$PATH" which 9router)

# 4. Áp dụng các bản vá lỗi (Patcher)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHER_SCRIPT="$SCRIPT_DIR/patch-9router.js"

if [ -f "$PATCHER_SCRIPT" ]; then
  echo -e "${CYAN}🔧 Đang áp dụng các bản vá lỗi cho 9Router...${NC}"
  PATH="$(dirname "$NODE_BIN"):$PATH" "$NODE_BIN" "$PATCHER_SCRIPT"
fi

# 5. Khởi tạo thư mục mitm và sinh Root CA
echo -e "${CYAN}📁 Khởi tạo thư mục cấu hình MITM...${NC}"
mkdir -p "$MITM_DIR"
chown -R "$CURRENT_USER":staff "$ROUTER_DATA_DIR"

CERT_PATH="$MITM_DIR/rootCA.crt"
KEY_PATH="$MITM_DIR/rootCA.key"

if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
  echo -e "${YELLOW}🔐 Đang sinh cặp khóa SSL Root CA mới...${NC}"
  openssl req -x509 -new -nodes -keyout "$KEY_PATH" -sha256 -days 3650 -out "$CERT_PATH" \
    -subj "/C=US/O=9Router/CN=9Router MITM Root CA" 2>/dev/null
  chown "$CURRENT_USER":staff "$CERT_PATH" "$KEY_PATH"
  chmod 644 "$CERT_PATH"
  chmod 600 "$KEY_PATH"
  echo -e "${GREEN}✔ Đã tạo Root CA tại: $CERT_PATH${NC}"
fi

# 6. Cài đặt và Trust Certificate vào macOS System Keychain
echo -e "${CYAN}🔑 Cài đặt chứng chỉ vào macOS System Keychain...${NC}"
security delete-certificate -c "9Router MITM Root CA" /Library/Keychains/System.keychain 2>/dev/null || true
security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_PATH"
echo -e "${GREEN}✔ Chứng chỉ '9Router MITM Root CA' đã được tin cậy hoàn toàn trong Keychain!${NC}"

# Cấu hình biến môi trường launchctl cho ứng dụng GUI
launchctl setenv NODE_EXTRA_CA_CERTS "$CERT_PATH" 2>/dev/null || true

# 7. Cấu hình chuyển hướng DNS trong /etc/hosts cho Antigravity
echo -e "${CYAN}🌐 Cấu hình chuyển hướng DNS cho Antigravity IDE...${NC}"
HOSTS_FILE="/etc/hosts"
DOMAINS=("daily-cloudcode-pa.googleapis.com" "cloudcode-pa.googleapis.com")

for domain in "${DOMAINS[@]}"; do
  if ! grep -q "$domain" "$HOSTS_FILE"; then
    echo "127.0.0.1 $domain" >> "$HOSTS_FILE"
    echo -e "${GREEN}  ✔ Đã thêm: 127.0.0.1 $domain${NC}"
  else
    echo -e "${YELLOW}  - Domain $domain đã có trong /etc/hosts${NC}"
  fi
done

dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null || true
echo -e "${GREEN}✔ Đã làm mới DNS Cache của macOS.${NC}"

# 8. Cấu hình mặc định mapping model (aliases.json)
ALIASES_FILE="$MITM_DIR/aliases.json"
if [ ! -f "$ALIASES_FILE" ] || [ ! -s "$ALIASES_FILE" ] || [ "$(cat "$ALIASES_FILE" 2>/dev/null)" = "{}" ]; then
  cat << 'EOF' > "$ALIASES_FILE"
{
  "antigravity": {
    "gemini-3.8-flash-high": "ag/gemini-3.8-flash-high",
    "gemini-3.8-flash-medium": "ag/gemini-3.8-flash-medium",
    "gemini-3.8-flash-low": "ag/gemini-3.8-flash-low",
    "gemini-3.8-flash": "ag/gemini-3.8-flash-medium"
  }
}
EOF
  chown "$CURRENT_USER":staff "$ALIASES_FILE"
  echo -e "${GREEN}✔ Đã tạo file mapping model mặc định: $ALIASES_FILE${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}${BOLD}      🎉 CÀI ĐẶT & CẤU HÌNH HOÀN TẤT 100%!           ${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo ""
echo -e "${CYAN}Để chạy 9Router bất cứ lúc nào, bạn chỉ cần mở Terminal và gõ:${NC}"
echo -e "  ${BOLD}sudo \$(which 9router)${NC}"
echo -e "  (hoặc chạy file: ${BOLD}./start-macos.sh${NC})"
echo ""
echo -e "${YELLOW}Trang quản trị Dashboard: ${BOLD}http://localhost:20128${NC}"
echo ""
