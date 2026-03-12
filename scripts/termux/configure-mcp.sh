#!/data/data/com.termux/files/usr/bin/bash
# configure-mcp.sh — Tampilkan snippet konfigurasi MCP untuk gemini-cli dan claude-code

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
step() { echo -e "\n${BOLD}▶ $1${NC}"; }

# Cek binary tersedia
if ! command -v mcp-coderag &>/dev/null; then
    echo -e "${RED}✗${NC} mcp-coderag tidak ditemukan di PATH."
    echo -e "  Jalankan dulu: ${CYAN}make install${NC}"
    exit 1
fi

echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Konfigurasi MCP Client untuk mcp-coderag-go   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"

echo -e "\n${CYAN}?${NC} Path project Go yang akan diindex (default: $PWD): "
read -r project_path
project_path="${project_path:-$PWD}"

# ── Gemini-CLI ────────────────────────────────────────────────────────────────
step "1/2 — gemini-cli (~/.gemini/settings.json)"
echo ""
echo -e "Tambahkan blok berikut ke dalam ${BOLD}\"mcpServers\"${NC} di ${CYAN}~/.gemini/settings.json${NC}:"
echo ""
cat << EOF
    "coderag": {
      "command": "mcp-coderag",
      "args": ["serve"],
      "cwd": "$project_path",
      "env": {
        "GOOGLE_API_KEY": "\$GOOGLE_API_KEY",
        "DB_URL": "\$DB_URL",
        "GEMINI_EMBED_MODEL": "gemini-embedding-001"
      },
      "trust": true
    }
EOF

# ── Claude Code ───────────────────────────────────────────────────────────────
step "2/2 — Claude Code (claude mcp add)"
echo ""
echo "Jalankan perintah berikut untuk menambahkan MCP server ke Claude Code:"
echo ""
printf 'claude mcp add coderag \\\n'
printf '  --scope user \\\n'
printf '  -e GOOGLE_API_KEY=$GOOGLE_API_KEY \\\n'
printf '  -e DB_URL=$DB_URL \\\n'
printf '  -e GEMINI_EMBED_MODEL=gemini-embedding-001 \\\n'
printf '  -- mcp-coderag serve\n'
echo ""
echo -e "Atau tambahkan ke ${CYAN}~/.claude.json${NC} di dalam ${BOLD}\"mcpServers\"${NC}:"
echo ""
cat << 'EOF'
    "coderag": {
      "command": "mcp-coderag",
      "args": ["serve"],
      "env": {
        "GOOGLE_API_KEY": "$GOOGLE_API_KEY",
        "DB_URL": "$DB_URL"
      }
    }
EOF

# ── Selesai ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Setup selesai!${NC} Langkah berikutnya:"
echo -e "  1. Salin config di atas ke AI client kamu"
echo -e "  2. Jalankan: ${CYAN}make index${NC}  (index project kamu)"
echo -e "  3. Restart gemini-cli / claude-code lalu cek: ${CYAN}/mcp list${NC}"
echo ""
