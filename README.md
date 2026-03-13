# mcp-coderag-go

CodeRAG MCP Server — RAG-based code search untuk project Go via Model Context Protocol.

Diintegrasikan dengan gemini-cli, qwen-code, claude-code, atau AI client lain yang support MCP.
Dirancang untuk berjalan di **Termux (Android)** tanpa Docker.

## Fitur

- **Hybrid Search** — Semantic (pgvector) + Full-Text (tsvector) via algoritma RRF
- **5 MCP Tools** — `search_code`, `get_chunk`, `list_packages`, `search_by_file`, `reindex`
- **Transport** — `stdio` (default) atau `HTTP`
- **Lightweight** — Go binary tunggal, jalan di Termux tanpa Docker

## Kebutuhan

- Go 1.21+
- PostgreSQL 14+ dengan ekstensi `pgvector`
- Google API Key (Gemini embedding)

---

## Platform Support

| Platform | Status | Cara Setup |
|---|---|---|
| Termux (Android) | ✅ Native | Gunakan `make setup` |
| Linux / macOS | ✅ Manual | Lihat Quick Start Linux |
| Windows | ⚠️ Via WSL | Belum ditest |

---

## Quick Start — Termux (Android)

Prasyarat: `pkg install golang git make clang`

```bash
# 1. Clone
git clone https://github.com/Faishalbhitex/mcp-coderag-go
cd mcp-coderag-go

# 2. Cek dependency
make setup-check

# 3. Setup PostgreSQL + pgvector (skip jika sudah ada)
make setup-postgres

# 4. Buat database + jalankan migration
make setup-db

# 5. Setup environment variables ke ~/.bashrc
make setup-env
source ~/.bashrc

# 6. Install binary global
make install

# 7. Index project Go kamu
indexer --path ./internal/...      # per subdirektori (lebih stabil)
indexer --path ./cmd/...
# atau sekaligus jika dependency lengkap:
# indexer --path ./...

# 8. Lihat konfigurasi AI client
make configure-mcp
```

---

## Quick Start — Linux / macOS

Prasyarat: PostgreSQL + pgvector sudah terinstall dan running.

```bash
git clone https://github.com/Faishalbhitex/mcp-coderag-go
cd mcp-coderag-go
cp .env.example .env
# Edit .env: isi GOOGLE_API_KEY dan DB_URL

# Buat database
createdb coderag
psql coderag -c "CREATE EXTENSION vector;"
make db-migrate

# Install dan index
make install
indexer --path /path/to/your/project/...

# Lihat konfigurasi AI client
make configure-mcp
```

---

## Konfigurasi AI Client

### gemini-cli

Edit `~/.gemini/settings.json`, tambahkan di dalam `"mcpServers"`:

```json
"gocoderag": {
  "command": "mcp-coderag",
  "args": ["serve"],
  "cwd": "/path/to/project-yang-diindex",
  "env": {
    "GOOGLE_API_KEY": "$GOOGLE_API_KEY",
    "DB_URL": "$DB_URL"
  },
  "trust": true
}
```

### qwen-code

Edit `~/.qwen/settings.json`, tambahkan di dalam `"mcpServers"`:

```json
"gocoderag": {
  "command": "mcp-coderag",
  "args": ["serve"],
  "cwd": "/path/to/project-yang-diindex",
  "env": {
    "GOOGLE_API_KEY": "$GOOGLE_API_KEY",
    "DB_URL": "$DB_URL"
  }
}
```

### claude-code

```bash
claude mcp add gocoderag \
  --scope user \
  -e GOOGLE_API_KEY=$GOOGLE_API_KEY \
  -e DB_URL=$DB_URL \
  -- mcp-coderag serve
```

> **Catatan `cwd`**: `cwd` menentukan working directory MCP server, yang digunakan tool `reindex`
> untuk resolve path relatif. Data yang bisa dicari ditentukan oleh apa yang sudah diindex
> via `indexer` — bukan oleh `cwd`.

---

## MCP Tools

| Tool | Kapan Digunakan |
|---|---|
| `list_packages` | **Selalu mulai dari sini** — lihat apa saja yang sudah terindex |
| `search_code` | Cari berdasarkan konsep, nama fungsi, atau behavior |
| `get_chunk` | Baca satu fungsi/struct lengkap via ID (`package.Name`) |
| `search_by_file` | Baca semua chunk dari satu file secara berurutan |
| `reindex` | Re-index setelah menulis atau mengedit file Go |

### Workflow yang Disarankan untuk AI Agent

```
1. list_packages          → orientasi: package apa yang terindex?
2. search_code("query")   → temukan kode relevan
3. get_chunk("pkg.Name")  → baca detail lengkap satu fungsi/struct
4. search_by_file("path") → baca konteks satu file penuh
5. reindex (jika perlu)   → setelah edit file, sebelum lanjut coding
```

### Tips Indexing

```bash
# Jika ./... gagal (dependency eksternal tidak lengkap),
# index per subdirektori:
indexer --path ./internal/...
indexer --path ./cmd/...
indexer --path ./config

# Exclude file noise (monolitik, generated):
indexer --path ./... --exclude main.go,vendor

# Cek apa yang sudah terindex:
psql $DB_URL -c "SELECT package, COUNT(*) FROM code_chunks GROUP BY package ORDER BY 2 DESC;"
```

---

## Makefile Targets

```bash
make setup-check    # cek dependency
make setup-postgres # install PostgreSQL + pgvector (Termux)
make setup-db       # init database + migration
make setup-env      # setup ~/.bashrc
make setup          # semua setup sekaligus
make install        # build + install binary global
make index          # index project ini sendiri
make configure-mcp  # tampilkan konfigurasi AI client
make build          # build ke ./bin/ (tanpa install)
make dev            # jalankan MCP server stdio (development)
make dev-http       # jalankan MCP server HTTP di port 8082
make db-migrate     # jalankan migration SQL
make clean          # hapus ./bin/
make uninstall      # hapus binary dari GOPATH/bin
```

---

## Environment Variables

| Variable | Wajib | Default | Keterangan |
|---|---|---|---|
| `GOOGLE_API_KEY` | ✅ | — | Gemini API key |
| `DB_URL` | ✅ | — | PostgreSQL connection string |
| `GEMINI_EMBED_MODEL` | ❌ | `gemini-embedding-001` | Model embedding |
| `INDEX_PATH` | ❌ | `./...` | Path default untuk `make index` |
| `INDEX_EXCLUDE` | ❌ | — | Comma-separated excludes |
| `RAG_THRESHOLD` | ❌ | `0.01` | Minimum RRF score |

---

## Arsitektur

```
cmd/
  mcp-coderag/    ← MCP server binary (serve --transport stdio|http)
  indexer/        ← Indexer binary (--path, --exclude)
internal/
  chunker/        ← AST extractor: Go source → Chunks
  store/          ← PostgreSQL + pgvector upsert
  rag/            ← Hybrid RRF search (semantic + full-text)
migrations/
  000_create_table.sql   ← schema awal (vector(1536))
  001_update_schema.sql  ← update kolom + HNSW index
  002_add_hybrid_search.sql ← content_tsv + GIN index
scripts/termux/   ← setup scripts khusus Termux
example/rest_api/ ← demo project untuk testing indexer
```

Database menggunakan **MRL (Matryoshka Representation Learning)** dengan dimensi `1536`
dari `gemini-embedding-001` — sweet spot antara kualitas embedding dan kompatibilitas
pgvector HNSW index (limit < 2000 dimensi).
