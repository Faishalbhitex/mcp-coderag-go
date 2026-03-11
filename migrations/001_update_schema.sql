-- Hapus data lama yang tidak valid
TRUNCATE TABLE code_chunks;

-- Tambah kolom baru jika belum ada
ALTER TABLE code_chunks
    ADD COLUMN IF NOT EXISTS end_line integer,
    ADD COLUMN IF NOT EXISTS chunk_type text,
    ADD COLUMN IF NOT EXISTS doc_comment text;

-- Drop index lama jika ada, buat ulang dengan HNSW
DROP INDEX IF EXISTS idx_code_chunks_embedding;
CREATE INDEX idx_code_chunks_embedding
    ON code_chunks USING hnsw (embedding vector_cosine_ops);

-- Index untuk filter
CREATE INDEX IF NOT EXISTS idx_code_chunks_package ON code_chunks(package);
CREATE INDEX IF NOT EXISTS idx_code_chunks_file ON code_chunks(file_path);
