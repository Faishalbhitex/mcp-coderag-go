// Package rag menyediakan fungsi pencarian hybrid (semantic + full-text)
// menggunakan algoritma Reciprocal Rank Fusion (RRF).
package rag

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	pgvector "github.com/pgvector/pgvector-go"
	"google.golang.org/genai"
)

// Result merepresentasikan satu chunk kode hasil pencarian.
type Result struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Package   string  `json:"package"`
	FilePath  string  `json:"file_path"`
	StartLine int     `json:"start_line"`
	EndLine   int     `json:"end_line"`
	ChunkType string  `json:"chunk_type"`
	Content   string  `json:"content"`
	Score     float64 `json:"similarity"` // RRF score, range ~0.016-0.033
}

const rrfSQL = `
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
	       c.chunk_type, c.content, r.score
	FROM rrf r JOIN code_chunks c ON r.id = c.id
	ORDER BY r.score DESC
	LIMIT $3`

// Searcher mengelola operasi pencarian hybrid ke database.
type Searcher struct {
	conn       *pgx.Conn
	genai      *genai.Client
	embedModel string
}

// NewSearcher membuat Searcher baru.
// Menerima koneksi pgx yang sudah ada (dari store atau langsung).
func NewSearcher(conn *pgx.Conn, genaiClient *genai.Client, embedModel string) *Searcher {
	return &Searcher{conn: conn, genai: genaiClient, embedModel: embedModel}
}

// Search melakukan hybrid RRF search dan mengembalikan top-K hasil.
// query: natural language atau nama fungsi eksak
// topK: jumlah hasil maksimal
// threshold: hasil dengan score < threshold dibuang (0 = ambil semua)
func (s *Searcher) Search(ctx context.Context, query string, topK int, threshold float64) ([]Result, error) {
	// Embed query untuk semantic search
	qContent := genai.NewContentFromText(query, genai.RoleUser)
	dim := int32(1536)
	qResult, err := s.genai.Models.EmbedContent(ctx, s.embedModel,
		[]*genai.Content{qContent},
		&genai.EmbedContentConfig{
			TaskType:             "CODE_RETRIEVAL_QUERY",
			OutputDimensionality: &dim,
		})
	if err != nil {
		return nil, fmt.Errorf("rag: embed query gagal: %w", err)
	}
	queryVector := pgvector.NewVector(qResult.Embeddings[0].Values)

	rows, err := s.conn.Query(ctx, rrfSQL, queryVector, query, topK)
	if err != nil {
		return nil, fmt.Errorf("rag: query database gagal: %w", err)
	}
	defer rows.Close()

	var results []Result
	for rows.Next() {
		var r Result
		if err := rows.Scan(&r.ID, &r.Name, &r.Package, &r.FilePath,
			&r.StartLine, &r.EndLine, &r.ChunkType, &r.Content, &r.Score); err != nil {
			return nil, fmt.Errorf("rag: scan row gagal: %w", err)
		}
		if threshold > 0 && r.Score < threshold {
			continue
		}
		results = append(results, r)
	}
	return results, nil
}
