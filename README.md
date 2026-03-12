# mcp-coderag-go

CodeRAG MCP Server — RAG-based code search untuk project Go via Model Context Protocol.
Cocok diintegrasikan dengan gemini-cli, claude-code, atau AI client lain yang support MCP.

## Fitur
- **Hybrid Search**: Semantic (pgvector) + Full-Text (tsvector) via algoritma RRF.
- **5 MCP Tools**: `search_code`, `get_chunk`, `list_packages`, `search_by_file`, `reindex`.
- **Transport**: Mendukung `stdio` (default) atau `HTTP`.
- **Lightweight**: Berjalan lancar di Termux (Android) tanpa Docker.

## Kebutuhan
- Go 1.21+
- PostgreSQL dengan ekstensi `pgvector`
- Google API Key (untuk Gemini embedding)

## Platform Support

| Platform | Status | Cara Setup |
|---|---|---|
| Termux (Android) | ✅ Native, tanpa Docker | Gunakan `scripts/termux/` |
| Linux / macOS | ✅ Asumsi sudah punya PostgreSQL + pgvector | Lihat bagian Manual Setup |
| Windows | ⚠️ Via WSL atau Docker | Belum ditest |

---

## Quick Start — Termux (Android)

Asumsi: Go, Git, Make sudah terinstall (`pkg install golang git make`).

```bash
# 1. Clone
git clone https://github.com/Faishalbhitex/mcp-coderag-go
cd mcp-coderag-go

# 2. Cek dependency
make setup-check

# 3. Install PostgreSQL + pgvector (jika belum ada)
make setup-postgres

# 4. Setup database + migration
make setup-db

# 5. Setup environment variables (~/.bashrc)
make setup-env
source ~/.bashrc

# 6. Build dan install binary
make install

# 7. Index project kamu
indexer --path /path/to/your/go/project/...

# 8. Konfigurasi AI client (gemini-cli / claude-code)
make configure-mcp
```

## Quick Start — Linux / macOS (Manual Setup)

Asumsi: PostgreSQL dan pgvector sudah terinstall dan running.

```bash
# 1. Clone dan setup .env
git clone https://github.com/Faishalbhitex/mcp-coderag-go
cd mcp-coderag-go
cp .env.example .env
# Edit .env: isi GOOGLE_API_KEY dan DB_URL

# 2. Buat database dan jalankan migration
createdb coderag
psql coderag -c "CREATE EXTENSION vector;"
make db-migrate

# 3. Install binary
make install

# 4. Index project
indexer --path /path/to/your/go/project/...

# 5. Konfigurasi AI client
make configure-mcp
```

## Instalasi

### 1. Clone dan setup environment
```bash
git clone https://github.com/Faishalbhitex/mcp-coderag-go
cd mcp-coderag-go
cp .env.example .env
# Edit .env: isi GOOGLE_API_KEY dan DB_URL
```

### 2. Setup database
```bash
# Pastikan PostgreSQL running
make db-migrate
```

### 3. Install binary
```bash
make install
# Binary tersedia secara global: mcp-coderag, indexer
```

### 4. Index project kamu
```bash
# Index project ini sendiri (untuk testing)
make index

# Atau index project lain
indexer --path /path/to/your/project/...
```

## Setup di gemini-cli

Edit `~/.gemini/settings.json` dan tambahkan server berikut:
```json
{
  "mcpServers": {
    "gocoderag": {
      "command": "mcp-coderag",
      "args": ["serve"],
      "cwd": "/path/to/project-yang-diindex",
      "env": {
        "GOOGLE_API_KEY": "your-api-key",
        "DB_URL": "postgres://user:pass@127.0.0.1:5432/coderag"
      },
      "trust": true
    }
  }
}
```

## MCP Tools

| Tool | Deskripsi |
|---|---|
| `search_code` | Hybrid search berdasarkan konsep atau nama fungsi eksak |
| `get_chunk` | Ambil satu fungsi/struct lengkap via ID (`package.Name`) |
| `list_packages` | Tampilkan semua package yang sudah terindex |
| `search_by_file` | Ambil semua potongan kode (chunk) dari satu file |
| `reindex` | Re-index path tertentu setelah kode berubah |

## Workflow di gemini-cli
1. `list_packages` → orientasi struktur project.
2. `search_code("query")` → temukan kode relevan.
3. `get_chunk("package.FunctionName")` → baca detail unit kode secara utuh.
