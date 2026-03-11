-- Migration 002: Tambah kolom content_tsv untuk hybrid full-text search
-- Jalankan: psql $DB_URL -f migrations/002_add_hybrid_search.sql

-- 1. Tambah kolom content_tsv
ALTER TABLE code_chunks 
ADD COLUMN IF NOT EXISTS content_tsv tsvector;

-- 2. Isi content_tsv untuk semua baris yang sudah ada
-- Weight: A = name+package (paling penting), B = doc_comment, C = content kode
UPDATE code_chunks SET content_tsv = 
    setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(package, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(doc_comment, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(content, '')), 'C');

-- 3. Buat GIN index untuk performa full-text search
CREATE INDEX IF NOT EXISTS idx_code_chunks_tsv 
ON code_chunks USING GIN (content_tsv);

-- Verifikasi
SELECT COUNT(*) as total_rows,
       COUNT(content_tsv) as rows_with_tsv
FROM code_chunks;
