# CodeRAG Go — Makefile
# Build dari source, install global, setup database
.PHONY: help build install dev db-migrate index clean uninstall

SHELL     := /bin/bash
BIN_DIR   := bin
GOBIN     ?= $(shell go env GOPATH)/bin

# Di Termux, GOPATH/bin biasanya sudah ada di PATH
# Kalau belum: tambahkan `export PATH=$PATH:$(go env GOPATH)/bin` di ~/.bashrc

# ─────────────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  CodeRAG Go — Build dari source"
	@echo ""
	@echo "  Setup awal:"
	@echo "    make db-migrate   Jalankan SQL migration ke database"
	@echo "    make install      Build + install binary ke GOPATH/bin"
	@echo "    make index        Index project saat ini ke database"
	@echo ""
	@echo "  Development:"
	@echo "    make build        Build binary ke ./bin/ (tanpa install)"
	@echo "    make dev          Jalankan MCP server langsung (stdio)"
	@echo "    make clean        Hapus binary di ./bin/"
	@echo ""
	@echo "  Uninstall:"
	@echo "    make uninstall    Hapus binary dari GOPATH/bin"
	@echo ""
	@echo "  Setup Termux (jalankan berurutan untuk device baru):"
	@echo "    make setup-check    Cek semua dependency"
	@echo "    make setup-postgres Install PostgreSQL + pgvector"
	@echo "    make setup-db       Init database, user, migration"
	@echo "    make setup-env      Setup environment variables"
	@echo "    make configure-mcp  Tampilkan config untuk gemini-cli/claude-code"
	@echo "    make setup          Semua setup di atas sekaligus"
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Build ke ./bin/ (untuk testing lokal)
build:
	@mkdir -p $(BIN_DIR)
	go build -o $(BIN_DIR)/mcp-coderag ./cmd/mcp-coderag/
	go build -o $(BIN_DIR)/indexer ./cmd/indexer/
	@echo "✓ Binary tersedia di ./bin/"

# Install global ke GOPATH/bin
install:
	go install ./cmd/mcp-coderag/
	go install ./cmd/indexer/
	@echo "✓ Installed: mcp-coderag, indexer → $(GOBIN)/"
	@echo "  Pastikan $(GOBIN) ada di PATH kamu."

# Uninstall dari GOPATH/bin
uninstall:
	rm -f $(GOBIN)/mcp-coderag $(GOBIN)/indexer
	@echo "✓ Uninstalled"

# ─────────────────────────────────────────────────────────────────────────────
# Setup (khusus Termux — lihat README untuk platform lain)
setup-check:
	@bash scripts/termux/check-deps.sh

setup-postgres:
	@bash scripts/termux/setup-postgres.sh

setup-db:
	@bash scripts/termux/setup-db.sh

setup-env:
	@bash scripts/termux/setup-env.sh

configure-mcp:
	@bash scripts/termux/configure-mcp.sh

# Setup lengkap end-to-end (jalankan urutan ini untuk setup baru)
setup: setup-check setup-postgres setup-db setup-env
	@echo ""
	@echo "Setup Termux selesai! Lanjutkan:"
	@echo "  make install     — build dan install binary global"
	@echo "  make index       — index project ini ke database"
	@echo "  make configure-mcp — tampilkan konfigurasi AI client"

# ─────────────────────────────────────────────────────────────────────────────
# Jalankan MCP server langsung (development mode, stdio)
dev: build
	./$(BIN_DIR)/mcp-coderag serve

# Jalankan MCP server HTTP (untuk testing client)
dev-http: build
	./$(BIN_DIR)/mcp-coderag serve --transport http --port 8082

# ─────────────────────────────────────────────────────────────────────────────
# Database migration
db-migrate:
	@if [ -z "$$DB_URL" ]; then \
		export $$(grep -v '^#' .env | xargs) 2>/dev/null; \
	fi; \
	psql $$DB_URL -f migrations/001_update_schema.sql && \
	psql $$DB_URL -f migrations/002_add_hybrid_search.sql
	@echo "✓ Migration selesai"

# Index project ini sendiri (atau set INDEX_PATH di .env)
index:
	@if [ -f $(GOBIN)/indexer ]; then \
		indexer --path $${INDEX_PATH:-./...} --exclude $${INDEX_EXCLUDE:-}; \
	else \
		./$(BIN_DIR)/indexer --path $${INDEX_PATH:-./...} --exclude $${INDEX_EXCLUDE:-}; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
clean:
	@rm -rf $(BIN_DIR)
	@echo "✓ ./bin/ dibersihkan"

# ─────────────────────────────────────────────────────────────────────────────
# Demo: index sample project rest_api
index-demo:
	@if [ -f $(GOBIN)/indexer ]; then \
		indexer --path ./example/rest_api/... --exclude example/rest_api/main.go; \
	else \
		./$(BIN_DIR)/indexer --path ./example/rest_api/... --exclude example/rest_api/main.go; \
	fi
	@echo "✓ Demo project terindex"
