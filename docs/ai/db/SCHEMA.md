# Source of Truth: CodeRAG Database Schema

Dokumen ini adalah referensi utama untuk struktur database PostgreSQL (pgvector).
Selalu rujuk file ini sebelum menulis SQL query atau mengubah pipeline indexing.

## 1. Table: `code_chunks`

| Column | Type | Nullable | Description |
|:---|:---|:---|:---|
| `id` | `text` | NOT NULL (PK) | Format: `package.Name` (e.g., `handler.HelloHandler`) |
| `name` | `text` | NOT NULL | Nama entitas: fungsi, struct, interface, method |
| `package` | `text` | NOT NULL | Nama Go package |
| `file_path` | `text` | NOT NULL | Path relatif dari root project |
| `start_line` | `integer` | NOT NULL | Baris awal di file |
| `end_line` | `integer` | NOT NULL | Baris akhir di file |
| `chunk_type` | `text` | NOT NULL | Nilai: `Function`, `Method`, `Struct`, `Interface` |
| `content` | `text` | NOT NULL | Source code asli |
| `doc_comment` | `text` | | Komentar dokumentasi Go di atas deklarasi |
| `embedding` | `vector(1536)` | | Vektor dari `gemini-embedding-001` (Dimensi diturunkan agar index HNSW pgvector < 2000) |
| `content_tsv` | `tsvector` | | Full-text search index (ditambahkan di migration 002) |

## 2. Indexes

| Name | Type | Column | Keterangan |
|:---|:---|:---|:---|
| `code_chunks_pkey` | btree | `id` | Primary key |
| `idx_code_chunks_package` | btree | `package` | Filter by package |
| `idx_code_chunks_file` | btree | `file_path` | Filter by file |
| `idx_code_chunks_embedding` | HNSW | `embedding` | Semantic similarity search |
| `idx_code_chunks_tsv` | GIN | `content_tsv` | Full-text search (migration 002) |

## 3. content_tsv: Cara Generate

Kolom `content_tsv` diisi saat indexing dengan weighted tsvector:

```sql
setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
setweight(to_tsvector('simple', COALESCE(package, '')), 'A') ||
setweight(to_tsvector('simple', COALESCE(doc_comment, '')), 'B') ||
setweight(to_tsvector('simple', COALESCE(content, '')), 'C')
```

Weight priority: **A** = nama fungsi + package (paling penting untuk code search),
**B** = doc comment, **C** = isi kode.

Gunakan config `'simple'` (bukan `'english'`) karena identifier Go tidak perlu stemming.

## 4. SQL Examples (Few-Shot)

### A. Semantic Search (sudah ada)
```sql
SELECT id, name, package, file_path, start_line, end_line, chunk_type, content,
       1 - (embedding <=> $1) AS similarity
FROM code_chunks
ORDER BY embedding <=> $1
LIMIT 5;
```

### B. Full-Text Search saja
```sql
SELECT id, name, package, file_path,
       ts_rank(content_tsv, query) AS fts_score
FROM code_chunks, plainto_tsquery('simple', $1) query
WHERE content_tsv @@ query
ORDER BY fts_score DESC
LIMIT 5;
```

### C. Hybrid Search via RRF (dipakai di PR #13)
```sql
WITH semantic AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> $1) AS rank
  FROM code_chunks
  LIMIT 20
),
fulltext AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank(content_tsv, query) DESC) AS rank
  FROM code_chunks, plainto_tsquery('simple', $2) query
  WHERE content_tsv @@ query
  LIMIT 20
),
rrf AS (
  SELECT
    COALESCE(s.id, f.id) AS id,
    (COALESCE(1.0/(60+s.rank), 0) + COALESCE(1.0/(60+f.rank), 0)) AS score
  FROM semantic s FULL OUTER JOIN fulltext f ON s.id = f.id
)
SELECT c.id, c.name, c.package, c.file_path, c.start_line, c.end_line,
       c.chunk_type, c.content, r.score AS similarity
FROM rrf r JOIN code_chunks c ON r.id = c.id
ORDER BY r.score DESC
LIMIT 5;
```

### D. Filter + Stats
```sql
-- By package
SELECT id, chunk_type FROM code_chunks WHERE package = 'handler';

-- By file
SELECT * FROM code_chunks WHERE file_path LIKE 'internal/%';

-- Stats
SELECT package, COUNT(*) AS total FROM code_chunks
GROUP BY package ORDER BY total DESC;
```

## 5. Maintenance

- **Upsert**: Gunakan `ON CONFLICT (id) DO UPDATE SET ...` — idempotent, aman untuk reindex
- **Reset bersih**: `TRUNCATE TABLE code_chunks;`
- **Koneksi**: `psql $DB_URL`
- **Migration files**: `migrations/001_update_schema.sql`, `migrations/002_add_hybrid_search.sql`
