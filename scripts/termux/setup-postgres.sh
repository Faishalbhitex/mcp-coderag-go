#!/data/data/com.termux/files/usr/bin/bash
# setup-postgres.sh — Install PostgreSQL dan pgvector di Termux
# Idempotent: aman dijalankan berkali-kali.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()      { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${CYAN}ℹ${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
fail()    { echo -e "${RED}✗${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}▶ $1${NC}"; }
confirm() { echo -e "${YELLOW}?${NC} $1 [y/N] "; read -r ans; [[ "$ans" =~ ^[Yy]$ ]]; }

echo -e "\n${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Setup PostgreSQL + pgvector (Termux)    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}\n"

# ── Step 1: PostgreSQL ────────────────────────────────────────────────────────
step "1/3 — PostgreSQL"
if command -v psql &>/dev/null; then
    ok "PostgreSQL sudah terinstall ($(psql --version | awk '{print $3}'))"
else
    info "PostgreSQL belum ditemukan."
    confirm "Install PostgreSQL via pkg?" || { warn "Dilewati."; exit 0; }
    pkg install postgresql -y
    ok "PostgreSQL terinstall"
fi

# ── Step 2: Cek pgvector ──────────────────────────────────────────────────────
step "2/3 — pgvector"
PG_SHAREDIR=$(pg_config --sharedir)
PG_INCLUDEDIR=$(pg_config --includedir-server)

if [ -f "$PG_SHAREDIR/extension/vector.control" ]; then
    ok "pgvector sudah terinstall — dilewati"
else
    info "pgvector belum ditemukan."

    # Cek header postgres.h
    if [ ! -f "$PG_INCLUDEDIR/postgres.h" ]; then
        fail "postgres.h tidak ditemukan di $PG_INCLUDEDIR\nCoba: pkg install postgresql-dev"
    fi
    ok "postgres.h ditemukan di $PG_INCLUDEDIR"

    # Cek clang
    if ! command -v clang &>/dev/null; then
        fail "clang tidak ditemukan — install dulu: pkg install clang"
    fi
    ok "clang tersedia"

    confirm "Build dan install pgvector dari source?" || { warn "Dilewati."; exit 0; }

    TMPDIR_PGV=$(mktemp -d)
    info "Clone pgvector ke $TMPDIR_PGV..."
    git clone --depth 1 https://github.com/pgvector/pgvector.git "$TMPDIR_PGV/pgvector"
    cd "$TMPDIR_PGV/pgvector"

    info "Build pgvector (CC=clang)..."
    # Termux: gunakan clang, tambahkan -lm untuk math library
    make CC=clang OPTFLAGS="-lm"
    make install

    cd "$OLDPWD"
    rm -rf "$TMPDIR_PGV"
    ok "pgvector berhasil diinstall"

    # Verifikasi
    if [ -f "$PG_SHAREDIR/extension/vector.control" ]; then
        ok "Verifikasi: vector.control ditemukan di $PG_SHAREDIR/extension/"
    else
        fail "pgvector install gagal — vector.control tidak ada"
    fi
fi

# ── Step 3: Selesai ───────────────────────────────────────────────────────────
step "3/3 — Selesai"
echo ""
ok "PostgreSQL + pgvector siap!"
echo -e "Lanjutkan dengan: ${CYAN}make setup-db${NC}"
