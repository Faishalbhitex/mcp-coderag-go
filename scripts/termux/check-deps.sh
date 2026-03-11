#!/data/data/com.termux/files/usr/bin/bash
# check-deps.sh — Periksa semua dependency yang dibutuhkan mcp-coderag-go
# Tidak install apapun, hanya laporan.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }

echo -e "\n${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   mcp-coderag-go — Cek Dependency   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}\n"

MISSING=0

# ── Go ────────────────────────────────────────────────────────────────────────
if command -v go &>/dev/null; then
    GO_VER=$(go version | awk '{print $3}' | sed 's/go//')
    GO_MAJOR=$(echo "$GO_VER" | cut -d. -f1)
    GO_MINOR=$(echo "$GO_VER" | cut -d. -f2)
    if [ "$GO_MAJOR" -ge 1 ] && [ "$GO_MINOR" -ge 21 ]; then
        ok "Go $GO_VER (>= 1.21 ✓)"
    else
        warn "Go $GO_VER ditemukan tapi butuh >= 1.21"
        MISSING=$((MISSING+1))
    fi
else
    fail "Go tidak ditemukan — install: pkg install golang"
    MISSING=$((MISSING+1))
fi

# ── Git ───────────────────────────────────────────────────────────────────────
if command -v git &>/dev/null; then
    ok "Git $(git --version | awk '{print $3}')"
else
    fail "Git tidak ditemukan — install: pkg install git"
    MISSING=$((MISSING+1))
fi

# ── Make ──────────────────────────────────────────────────────────────────────
if command -v make &>/dev/null; then
    ok "Make $(make --version | head -1 | awk '{print $3}')"
else
    fail "Make tidak ditemukan — install: pkg install make"
    MISSING=$((MISSING+1))
fi

# ── Clang (untuk build pgvector) ──────────────────────────────────────────────
if command -v clang &>/dev/null; then
    ok "Clang $(clang --version | head -1 | awk '{print $3}')"
else
    fail "Clang tidak ditemukan — install: pkg install clang"
    MISSING=$((MISSING+1))
fi

# ── PostgreSQL ────────────────────────────────────────────────────────────────
if command -v psql &>/dev/null; then
    PG_VER=$(psql --version | awk '{print $3}')
    PG_MAJOR=$(echo "$PG_VER" | cut -d. -f1)
    if [ "$PG_MAJOR" -ge 14 ]; then
        ok "PostgreSQL $PG_VER (>= 14 ✓)"
    else
        warn "PostgreSQL $PG_VER — disarankan >= 14"
    fi
    # Cek pgvector
    PG_SHAREDIR=$(pg_config --sharedir 2>/dev/null)
    if [ -f "$PG_SHAREDIR/extension/vector.control" ]; then
        ok "pgvector extension ditemukan"
    else
        warn "pgvector belum terinstall — jalankan: make setup-postgres"
    fi
else
    fail "PostgreSQL tidak ditemukan — jalankan: make setup-postgres"
    MISSING=$((MISSING+1))
fi

# ── psql tersedia ─────────────────────────────────────────────────────────────
if command -v pg_config &>/dev/null; then
    ok "pg_config tersedia ($(pg_config --version))"
fi

# ── Ringkasan ─────────────────────────────────────────────────────────────────
echo ""
if [ "$MISSING" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Semua dependency tersedia!${NC}"
    echo -e "Lanjutkan dengan: ${CYAN}make setup-db${NC}"
else
    echo -e "${RED}${BOLD}$MISSING dependency kurang.${NC}"
    echo -e "Install yang kurang dulu, lalu jalankan script ini lagi."
    exit 1
fi
