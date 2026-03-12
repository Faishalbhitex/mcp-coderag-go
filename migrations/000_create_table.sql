-- Migration 000: Initial schema — buat tabel code_chunks dari nol
-- Aman dijalankan di database fresh maupun yang sudah ada (IF NOT EXISTS)

CREATE TABLE IF NOT EXISTS code_chunks (
    id          text PRIMARY KEY,
    name        text NOT NULL,
    package     text NOT NULL,
    file_path   text NOT NULL,
    start_line  integer NOT NULL,
    end_line    integer NOT NULL,
    chunk_type  text NOT NULL,
    doc_comment text,
    content     text NOT NULL,
    embedding   vector(1536),
    content_tsv tsvector
);

-- Index untuk semantic search (HNSW)
CREATE INDEX IF NOT EXISTS idx_code_chunks_embedding
    ON code_chunks USING hnsw (embedding vector_cosine_ops);

-- Index untuk filter
CREATE INDEX IF NOT EXISTS idx_code_chunks_package
    ON code_chunks (package);

CREATE INDEX IF NOT EXISTS idx_code_chunks_file
    ON code_chunks (file_path);

-- Index untuk hybrid full-text search
CREATE INDEX IF NOT EXISTS idx_code_chunks_tsv
    ON code_chunks USING GIN (content_tsv);
