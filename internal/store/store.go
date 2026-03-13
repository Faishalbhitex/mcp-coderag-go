// Package store mengelola koneksi dan operasi database PostgreSQL + pgvector.
package store

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	pgvector "github.com/pgvector/pgvector-go"
	"google.golang.org/genai"

	"mcp-coderag-go/internal/chunker"
)

// Store menyimpan koneksi database dan genai client.
type Store struct {
	Conn       *pgx.Conn
	GenAI      *genai.Client
	EmbedModel string
}

// New membuat Store baru dengan koneksi ke database.
func New(ctx context.Context, dbURL string, genaiClient *genai.Client, embedModel string) (*Store, error) {
	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		return nil, fmt.Errorf("store: koneksi gagal: %w", err)
	}
	return &Store{Conn: conn, GenAI: genaiClient, EmbedModel: embedModel}, nil
}

// Close menutup koneksi database.
func (s *Store) Close(ctx context.Context) {
	s.Conn.Close(ctx)
}

// UpsertResult adalah hasil batch upsert.
type UpsertResult struct {
	Indexed int
	Skipped int
	Errors  int
}

// UpsertChunk meng-embed satu Chunk lalu upsert ke database.
// Idempotent: aman dipanggil berkali-kali untuk ID yang sama.
func (s *Store) UpsertChunk(ctx context.Context, chunk chunker.Chunk) error {
	// Format teks yang lebih kaya untuk embedding (mengikuti pola di pgvector example)
	textToEmbed := fmt.Sprintf(
		"Package: %s\nName: %s\nType: %s\nFile: %s\nDoc: %s\nCode:\n%s",
		chunk.Package, chunk.Name, chunk.Type, chunk.FilePath, chunk.Doc, chunk.Content,
	)

	content := genai.NewContentFromText(textToEmbed, genai.RoleUser)
	dim := int32(1536)
	result, err := s.GenAI.Models.EmbedContent(ctx, s.EmbedModel,
		[]*genai.Content{content},
		&genai.EmbedContentConfig{
			TaskType:             "RETRIEVAL_DOCUMENT",
			Title:                fmt.Sprintf("Code Chunk: %s", chunk.ID),
			OutputDimensionality: &dim,
		})
	if err != nil {
		return fmt.Errorf("store: embed gagal (%s): %w", chunk.ID, err)
	}
	vector := pgvector.NewVector(result.Embeddings[0].Values)

	_, err = s.Conn.Exec(ctx, fmt.Sprintf(`
		INSERT INTO code_chunks
			(id, name, package, file_path, start_line, end_line,
			 chunk_type, doc_comment, content, embedding, content_tsv)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, %s)
		ON CONFLICT (id) DO UPDATE SET
			file_path   = EXCLUDED.file_path,
			start_line  = EXCLUDED.start_line,
			end_line    = EXCLUDED.end_line,
			chunk_type  = EXCLUDED.chunk_type,
			doc_comment = EXCLUDED.doc_comment,
			content     = EXCLUDED.content,
			embedding   = EXCLUDED.embedding,
			content_tsv = EXCLUDED.content_tsv`,
		buildTSVector(chunk.Name, chunk.Package, chunk.Doc, chunk.Content),
	),
		chunk.ID, chunk.Name, chunk.Package, chunk.FilePath,
		chunk.StartLine, chunk.EndLine, chunk.Type, chunk.Doc,
		chunk.Content, vector)
	if err != nil {
		return fmt.Errorf("store: upsert gagal (%s): %w", chunk.ID, err)
	}
	return nil
}

// UpsertChunks memproses slice Chunk secara batch.
// Chunk yang gagal dicatat di Errors, proses tetap lanjut.
func (s *Store) UpsertChunks(ctx context.Context, chunks []chunker.Chunk) UpsertResult {
	var res UpsertResult
	for _, c := range chunks {
		if c.FilePath == "" {
			res.Skipped++
			continue
		}
		if err := s.UpsertChunk(ctx, c); err != nil {
			res.Errors++
			continue
		}
		res.Indexed++
	}
	return res
}

// buildTSVector membuat weighted tsvector untuk hybrid search.
// Prioritas: A = name+package (identifier eksak), B = doc_comment, C = content.
// Config 'simple' dipilih karena identifier Go tidak perlu stemming.
func buildTSVector(name, pkg, doc, content string) string {
	return fmt.Sprintf(
		"setweight(to_tsvector('simple', %s), 'A') || "+
			"setweight(to_tsvector('simple', %s), 'A') || "+
			"setweight(to_tsvector('simple', %s), 'B') || "+
			"setweight(to_tsvector('simple', %s), 'C')",
		pgQuoteLiteral(name),
		pgQuoteLiteral(pkg),
		pgQuoteLiteral(doc),
		pgQuoteLiteral(content),
	)
}

// pgQuoteLiteral mengamankan string untuk SQL literal.
func pgQuoteLiteral(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}
