package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"github.com/modelcontextprotocol/go-sdk/mcp"
	"github.com/spf13/cobra"
	"google.golang.org/genai"

	"mcp-coderag-go/internal/chunker"
	"mcp-coderag-go/internal/rag"
	"mcp-coderag-go/internal/store"
)

// ── Global state untuk MCP handlers ──────────────────────────────────────────

var (
	globalStore    *store.Store
	globalSearcher *rag.Searcher
)

// ── Cobra CLI ─────────────────────────────────────────────────────────────────

var (
	flagTransport string
	flagPort      int
)

var rootCmd = &cobra.Command{
	Use:   "mcp-coderag",
	Short: "CodeRAG MCP Server — RAG-based code search via Model Context Protocol",
}

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Jalankan MCP server (default: stdio)",
	RunE:  runServe,
}

func init() {
	serveCmd.Flags().StringVar(&flagTransport, "transport", "stdio",
		"Transport mode: stdio | http")
	serveCmd.Flags().IntVar(&flagPort, "port", 8082,
		"Port untuk HTTP transport (hanya berlaku jika --transport http)")
	rootCmd.AddCommand(serveCmd)
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

func runServe(cmd *cobra.Command, args []string) error {
	_ = godotenv.Load()

	// Setup logging ke file agar tidak mengganggu stdio
	logFile, err := os.OpenFile("mcp_server.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err == nil {
		log.SetOutput(logFile)
		defer logFile.Close()
	}

	apiKey := os.Getenv("GOOGLE_API_KEY")
	dbURL := os.Getenv("DB_URL")
	embedModel := os.Getenv("GEMINI_EMBED_MODEL")
	if apiKey == "" || dbURL == "" {
		return fmt.Errorf("GOOGLE_API_KEY dan DB_URL wajib diset")
	}
	if embedModel == "" {
		embedModel = "gemini-embedding-001"
	}

	ctx := context.Background()

	genaiClient, err := genai.NewClient(ctx, &genai.ClientConfig{APIKey: apiKey})
	if err != nil {
		return fmt.Errorf("gagal init genai: %w", err)
	}

	globalStore, err = store.New(ctx, dbURL, genaiClient, embedModel)
	if err != nil {
		return fmt.Errorf("gagal koneksi database: %w", err)
	}
	defer globalStore.Close(ctx)

	globalSearcher = rag.NewSearcher(globalStore.Conn, genaiClient, embedModel)

	// Daftarkan MCP server + tools
	server := buildServer()

	switch flagTransport {
	case "http":
		addr := fmt.Sprintf("localhost:%d", flagPort)
		log.Printf("MCP server HTTP listening on %s", addr)
		fmt.Printf("MCP server HTTP listening on %s\n", addr)

		handler := mcp.NewStreamableHTTPHandler(func(r *http.Request) *mcp.Server {
			return server
		}, nil)

		return http.ListenAndServe(addr, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if strings.HasPrefix(r.URL.Path, "/mcp") {
				handler.ServeHTTP(w, r)
				return
			}
			http.NotFound(w, r)
		}))
	default: // stdio
		log.Println("MCP server started (stdio)")
		return server.Run(ctx, &mcp.StdioTransport{})
	}
}

// ── MCP Server + Tool Registration ───────────────────────────────────────────

func buildServer() *mcp.Server {
	server := mcp.NewServer(
		&mcp.Implementation{
			Name:    "mcp-coderag",
			Version: "1.0.0",
		},
		nil,
	)

	// search_code
	mcp.AddTool(server, &mcp.Tool{
		Name: "search_code",
		Description: "Cari kode berdasarkan konsep atau nama fungsi eksak menggunakan Hybrid Search (Semantic + Full-Text RRF).",
	}, handleSearch)

	// get_chunk
	mcp.AddTool(server, &mcp.Tool{
		Name: "get_chunk",
		Description: "Ambil satu chunk kode secara lengkap berdasarkan ID eksak (format: package.Name).",
	}, handleGetChunk)

	// list_packages
	mcp.AddTool(server, &mcp.Tool{
		Name: "list_packages",
		Description: "Tampilkan semua package Go yang sudah terindex beserta jumlah chunk dan file-nya.",
	}, handleListPackages)

	// search_by_file
	mcp.AddTool(server, &mcp.Tool{
		Name: "search_by_file",
		Description: "Ambil semua potongan kode (chunk) dalam satu file, berurutan. Gunakan jika perlu konteks lengkap satu file.",
	}, handleSearchByFile)

	// reindex
	mcp.AddTool(server, &mcp.Tool{
		Name: "reindex",
		Description: "Re-index path Go tertentu ke database. Gunakan setelah menulis atau mengedit file Go.",
	}, handleReindex)

	return server
}

// ── Tool Handlers ─────────────────────────────────────────────────────────────

type SearchInput struct {
	Query string `json:"query" jsonschema:"Pertanyaan natural language atau nama fungsi eksak"`
}

type GetChunkInput struct {
	ID string `json:"id" jsonschema:"ID chunk (contoh: handler.NewAPIHandler)"`
}

type SearchByFileInput struct {
	FilePath string `json:"file_path" jsonschema:"Path file relatif dari root project"`
}

type ReindexInput struct {
	Path string `json:"path" jsonschema:"Go path yang akan di-reindex (contoh: ./internal/...)"`
}

func handleSearch(ctx context.Context, req *mcp.CallToolRequest, input SearchInput) (*mcp.CallToolResult, any, error) {
	log.Printf("search_code: %q", input.Query)

	threshold := 0.01 // RRF threshold dari PR #13
	results, err := globalSearcher.Search(ctx, input.Query, 5, threshold)
	if err != nil {
		return nil, nil, fmt.Errorf("search gagal: %w", err)
	}

	return nil, map[string]any{"results": results}, nil
}

func handleGetChunk(ctx context.Context, req *mcp.CallToolRequest, input GetChunkInput) (*mcp.CallToolResult, any, error) {
	log.Printf("get_chunk: %q", input.ID)

	var r rag.Result
	err := globalStore.Conn.QueryRow(ctx, `
		SELECT id, name, package, file_path, start_line, end_line, chunk_type, content
		FROM code_chunks WHERE id = $1`, input.ID).
		Scan(&r.ID, &r.Name, &r.Package, &r.FilePath,
			&r.StartLine, &r.EndLine, &r.ChunkType, &r.Content)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil, fmt.Errorf("chunk %q tidak ditemukan", input.ID)
		}
		return nil, nil, fmt.Errorf("database query gagal: %w", err)
	}
	return nil, r, nil
}

func handleListPackages(ctx context.Context, req *mcp.CallToolRequest, _ struct{}) (*mcp.CallToolResult, any, error) {
	log.Println("list_packages")
	rows, err := globalStore.Conn.Query(ctx, `
		SELECT package, COUNT(*) as chunk_count, ARRAY_AGG(DISTINCT file_path) as files
		FROM code_chunks
		GROUP BY package
		ORDER BY package ASC`)
	if err != nil {
		return nil, nil, fmt.Errorf("list packages gagal: %w", err)
	}
	defer rows.Close()

	type PackageInfo struct {
		Package    string   `json:"package"`
		ChunkCount int      `json:"chunk_count"`
		Files      []string `json:"files"`
	}
	var packages []PackageInfo
	for rows.Next() {
		var p PackageInfo
		if err := rows.Scan(&p.Package, &p.ChunkCount, &p.Files); err != nil {
			continue
		}
		packages = append(packages, p)
	}
	return nil, map[string]any{"packages": packages}, nil
}

func handleSearchByFile(ctx context.Context, req *mcp.CallToolRequest, input SearchByFileInput) (*mcp.CallToolResult, any, error) {
	log.Printf("search_by_file: %q", input.FilePath)

	rows, err := globalStore.Conn.Query(ctx, `
		SELECT id, name, package, file_path, start_line, end_line, chunk_type, content
		FROM code_chunks WHERE file_path = $1
		ORDER BY start_line`, input.FilePath)
	if err != nil {
		return nil, nil, fmt.Errorf("search_by_file gagal: %w", err)
	}
	defer rows.Close()

	var results []rag.Result
	for rows.Next() {
		var r rag.Result
		if err := rows.Scan(&r.ID, &r.Name, &r.Package, &r.FilePath,
			&r.StartLine, &r.EndLine, &r.ChunkType, &r.Content); err != nil {
			continue
		}
		results = append(results, r)
	}
	return nil, map[string]any{"results": results}, nil
}

func handleReindex(ctx context.Context, req *mcp.CallToolRequest, input ReindexInput) (*mcp.CallToolResult, any, error) {
	log.Printf("reindex: %q", input.Path)

	path := input.Path
	if path == "" {
		path = os.Getenv("INDEX_PATH")
	}
	if path == "" {
		path = "./..."
	}

	// Pastikan path pakai "./" prefix (packages.Load requirement)
	if !strings.HasPrefix(path, "./") && !strings.HasPrefix(path, "/") {
		path = "./" + path
	}

	indexExclude := os.Getenv("INDEX_EXCLUDE")
	excludes := strings.Split(indexExclude, ",")

	chunks := chunker.ExtractChunks(path, excludes)
	result := globalStore.UpsertChunks(ctx, chunks)
	log.Printf("reindex selesai: indexed=%d errors=%d", result.Indexed, result.Errors)

	return nil, map[string]any{
		"indexed": result.Indexed,
		"errors":  result.Errors,
		"skipped": result.Skipped,
	}, nil
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
