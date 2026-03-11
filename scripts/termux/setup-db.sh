#!/data/data/com.termux/files/usr/bin/bash
# setup-db.sh — Inisialisasi PostgreSQL, buat database coderag, jalankan migration
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
echo -e "${BOLD}║    Setup Database CodeRAG (Termux)       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}\n"

PGDATA="$HOME/.pgdata"
DB_NAME="coderag"
DB_USER="coderag"
DB_PASS="coderag"

# ── Step 1: Init pgdata ───────────────────────────────────────────────────────
step "1/5 — Inisialisasi pgdata"
if [ -d "$PGDATA" ]; then
    ok "pgdata sudah ada di $PGDATA — dilewati"
else
    info "Inisialisasi database cluster di $PGDATA..."
    initdb -D "$PGDATA" --no-locale --encoding=UTF8
    ok "pgdata berhasil diinisialisasi"
fi

# ── Step 2: Start PostgreSQL ──────────────────────────────────────────────────
step "2/5 — Start PostgreSQL"
if pg_ctl -D "$PGDATA" status &>/dev/null; then
    ok "PostgreSQL sudah running"
else
    info "Menjalankan PostgreSQL..."
    pg_ctl -D "$PGDATA" start -l "$PGDATA/postgres.log"
    sleep 2
    if pg_ctl -D "$PGDATA" status &>/dev/null; then
        ok "PostgreSQL berhasil distart"
    else
        fail "PostgreSQL gagal start — cek log: $PGDATA/postgres.log"
    fi
fi

# ── Step 3: Buat user & database ─────────────────────────────────────────────
step "3/5 — Buat user dan database"

# Di Termux: koneksi awal HARUS pakai -d postgres (bukan -U postgres)
# Karena role system user (bukan 'postgres') yang ada secara default

# Cek apakah user sudah ada
if psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    ok "User '$DB_USER' sudah ada"
else
    info "Membuat user '$DB_USER'..."
    psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    ok "User '$DB_USER' dibuat"
fi

# Cek apakah database sudah ada
if psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    ok "Database '$DB_NAME' sudah ada"
else
    info "Membuat database '$DB_NAME'..."
    psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    ok "Database '$DB_NAME' dibuat"
fi

# ── Step 4: Enable extension + Migration ─────────────────────────────────────
step "4/5 — Extension pgvector + Migration"

# Enable vector extension
psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null \
    && ok "Extension 'vector' aktif" \
    || warn "Gagal enable vector — pastikan pgvector sudah terinstall"

# Jalankan migration
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION_DIR="$SCRIPT_DIR/migrations"

if [ ! -d "$MIGRATION_DIR" ]; then
    fail "Directory migrations tidak ditemukan di $MIGRATION_DIR"
fi

DB_URL="postgres://$DB_USER:$DB_PASS@127.0.0.1:5432/$DB_NAME"

info "Menjalankan migration 001..."
psql "$DB_URL" -f "$MIGRATION_DIR/001_update_schema.sql" \
    && ok "Migration 001 selesai" \
    || warn "Migration 001 gagal (mungkin sudah pernah dijalankan)"

info "Menjalankan migration 002..."
psql "$DB_URL" -f "$MIGRATION_DIR/002_add_hybrid_search.sql" \
    && ok "Migration 002 selesai" \
    || warn "Migration 002 gagal (mungkin sudah pernah dijalankan)"

# ── Step 5: Verifikasi + Ringkasan ────────────────────────────────────────────
step "5/5 — Verifikasi"

# Test koneksi dengan DB_URL
if psql "$DB_URL" -c "SELECT 1;" &>/dev/null; then
    ok "Koneksi ke database berhasil"
    echo ""
    echo -e "${GREEN}${BOLD}Database siap!${NC}"
    echo -e "DB_URL: ${CYAN}$DB_URL${NC}"
    echo ""
    echo -e "Lanjutkan dengan: ${CYAN}make setup-env${NC}"
else
    fail "Koneksi ke database gagal\nCoba manual: psql $DB_URL"
fi
