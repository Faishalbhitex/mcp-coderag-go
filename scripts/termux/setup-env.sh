#!/data/data/com.termux/files/usr/bin/bash
# setup-env.sh — Tambahkan environment variables ke ~/.bashrc jika belum ada

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
step() { echo -e "\n${BOLD}▶ $1${NC}"; }

echo -e "\n${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Setup Environment Variables (Termux)   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}\n"

BASHRC="$HOME/.bashrc"

add_if_missing() {
    local line="$1"
    local desc="$2"
    if grep -qF "$line" "$BASHRC" 2>/dev/null; then
        ok "$desc sudah ada di .bashrc"
    else
        echo "$line" >> "$BASHRC"
        ok "$desc ditambahkan ke .bashrc"
    fi
}

# ── Step 1: Go paths ──────────────────────────────────────────────────────────
step "1/3 — Go PATH"
add_if_missing 'export GOPATH=$HOME/go' "GOPATH"
add_if_missing 'export PATH=$PATH:$GOPATH/bin' "GOPATH/bin di PATH"

# ── Step 2: API Key ───────────────────────────────────────────────────────────
step "2/3 — Google API Key"
if grep -q "GOOGLE_API_KEY" "$BASHRC" 2>/dev/null; then
    ok "GOOGLE_API_KEY sudah ada di .bashrc"
else
    echo -e "${YELLOW}?${NC} Masukkan Google API Key kamu (kosongkan untuk skip): "
    read -r api_key
    if [ -n "$api_key" ]; then
        echo "export GOOGLE_API_KEY=$api_key" >> "$BASHRC"
        ok "GOOGLE_API_KEY ditambahkan"
    else
        warn "GOOGLE_API_KEY dilewati — tambahkan manual ke ~/.bashrc nanti"
    fi
fi

# ── Step 3: DB_URL ────────────────────────────────────────────────────────────
step "3/3 — Database URL"
DEFAULT_DB_URL="postgres://coderag:coderag@127.0.0.1:5432/coderag"
if grep -q "DB_URL" "$BASHRC" 2>/dev/null; then
    ok "DB_URL sudah ada di .bashrc"
else
    info "Default DB_URL: $DEFAULT_DB_URL"
    echo -e "${YELLOW}?${NC} Gunakan default DB_URL? [Y/n] "
    read -r ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}?${NC} Masukkan DB_URL: "
        read -r db_url
        echo "export DB_URL=$db_url" >> "$BASHRC"
    else
        echo "export DB_URL=$DEFAULT_DB_URL" >> "$BASHRC"
    fi
    ok "DB_URL ditambahkan ke .bashrc"
fi

# ── Selesai ───────────────────────────────────────────────────────────────────
echo ""
ok "Environment variables siap!"
echo -e "${CYAN}ℹ${NC} Jalankan ${BOLD}source ~/.bashrc${NC} agar perubahan berlaku di sesi ini."
echo ""
echo -e "Lanjutkan dengan: ${CYAN}make configure-mcp${NC}"
