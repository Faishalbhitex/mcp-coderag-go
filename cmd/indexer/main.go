package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
	"github.com/spf13/cobra"
	"google.golang.org/genai"

	"mcp-coderag-go/internal/chunker"
	"mcp-coderag-go/internal/store"
)

var (
	flagPath    string
	flagExclude string
)

var rootCmd = &cobra.Command{
	Use:   "indexer",
	Short: "CodeRAG Indexer — index Go codebase ke PostgreSQL + pgvector",
	Long: `Indexer membaca source code Go, membuat chunk per fungsi/struct/interface,
lalu menyimpan embedding-nya ke database untuk digunakan MCP server.`,
	RunE: runIndex,
}

func init() {
	rootCmd.Flags().StringVar(&flagPath, "path", "",
		"Path Go yang akan diindex (contoh: ./... atau ./internal/...)")
	rootCmd.Flags().StringVar(&flagExclude, "exclude", "",
		"Comma-separated file/pattern yang dikecualikan (contoh: vendor,rest_api/main.go)")
}

func runIndex(cmd *cobra.Command, args []string) error {
	// Load .env jika ada
	_ = godotenv.Load()

	// Path: flag > env > default
	indexPath := flagPath
	if indexPath == "" {
		indexPath = os.Getenv("INDEX_PATH")
	}
	if indexPath == "" {
		indexPath = "./..."
	}

	// Excludes: flag > env
	excludeStr := flagExclude
	if excludeStr == "" {
		excludeStr = os.Getenv("INDEX_EXCLUDE")
	}
	var excludes []string
	if excludeStr != "" {
		for _, e := range strings.Split(excludeStr, ",") {
			if t := strings.TrimSpace(e); t != "" {
				excludes = append(excludes, t)
			}
		}
	}

	// Validasi env
	apiKey := os.Getenv("GOOGLE_API_KEY")
	dbURL := os.Getenv("DB_URL")
	embedModel := os.Getenv("GEMINI_EMBED_MODEL")
	if apiKey == "" || dbURL == "" {
		return fmt.Errorf("GOOGLE_API_KEY dan DB_URL wajib diset di .env atau environment")
	}
	if embedModel == "" {
		embedModel = "gemini-embedding-001"
	}

	ctx := context.Background()

	// Init genai client
	genaiClient, err := genai.NewClient(ctx, &genai.ClientConfig{APIKey: apiKey})
	if err != nil {
		return fmt.Errorf("gagal init genai client: %w", err)
	}

	// Init store
	s, err := store.New(ctx, dbURL, genaiClient, embedModel)
	if err != nil {
		return fmt.Errorf("gagal koneksi database: %w", err)
	}
	defer s.Close(ctx)

	// Extract chunks
	log.Printf("Indexing path: %s (excludes: %v)", indexPath, excludes)
	chunks := chunker.ExtractChunks(indexPath, excludes)
	if len(chunks) == 0 {
		log.Println("Tidak ada chunk ditemukan. Periksa --path dan --exclude.")
		return nil
	}
	log.Printf("Ditemukan %d chunks, mulai upsert...", len(chunks))

	// Upsert ke database
	result := s.UpsertChunks(ctx, chunks)
	log.Printf("Selesai — Indexed: %d, Errors: %d, Skipped: %d", result.Indexed, result.Errors, result.Skipped)
	return nil
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
