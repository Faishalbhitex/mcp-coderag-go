package chunker

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/printer"
	"go/token"
	"log"
	"path/filepath"
	"strings"

	"golang.org/x/tools/go/packages"
)

// Chunk dengan metadata lengkap
type Chunk struct {
	ID        string
	Name      string
	Type      string
	Package   string
	FilePath  string
	StartLine int
	EndLine   int
	Content   string
	Doc       string
}

// ExtractChunks mengekstraksi kode Go dari path tertentu menjadi beberapa chunk semantik.
func ExtractChunks(path string, excludes []string) []Chunk {
	cfg := &packages.Config{
		Mode: packages.NeedSyntax | packages.NeedTypes | packages.NeedName | packages.NeedFiles | packages.NeedCompiledGoFiles,
	}

	pkgs, err := packages.Load(cfg, path)
	if err != nil {
		log.Printf("Error loading packages: %v", err)
		return nil
	}

	var chunks []Chunk
	cwd, _ := filepath.Abs(".")

	for _, pkg := range pkgs {
		// Filter berdasarkan excludes
		skip := false
		for _, ex := range excludes {
			if ex != "" && strings.Contains(pkg.PkgPath, ex) {
				skip = true
				break
			}
		}
		if skip {
			continue
		}

		for _, fileAST := range pkg.Syntax {
			fset := pkg.Fset
			fileName := fset.File(fileAST.Pos()).Name()
			relPath, _ := filepath.Rel(cwd, fileName)
			if relPath == "." || relPath == "" {
				relPath = filepath.Base(fileName)
			}

			for _, decl := range fileAST.Decls {
				switch d := decl.(type) {
				case *ast.FuncDecl:
					content := PrintNode(fset, d)
					doc := d.Doc.Text()
					startPos := fset.Position(d.Pos())
					endPos := fset.Position(d.End())

					chunkType := "Function"
					if d.Recv != nil {
						chunkType = "Method"
					}

					chunks = append(chunks, Chunk{
						ID:        fmt.Sprintf("%s.%s", pkg.Name, d.Name.Name),
						Name:      d.Name.Name,
						Type:      chunkType,
						Package:   pkg.Name,
						FilePath:  relPath,
						StartLine: startPos.Line,
						EndLine:   endPos.Line,
						Content:   content,
						Doc:       strings.TrimSpace(doc),
					})
				case *ast.GenDecl:
					if d.Tok == token.TYPE {
						for _, spec := range d.Specs {
							ts, ok := spec.(*ast.TypeSpec)
							if !ok {
								continue
							}
							content := PrintNode(fset, d)
							doc := d.Doc.Text()
							if doc == "" && ts.Comment != nil {
								doc = ts.Comment.Text()
							}
							startPos := fset.Position(d.Pos())
							endPos := fset.Position(d.End())

							chunkType := "Type"
							switch ts.Type.(type) {
							case *ast.StructType:
								chunkType = "Struct"
							case *ast.InterfaceType:
								chunkType = "Interface"
							}

							chunks = append(chunks, Chunk{
								ID:        fmt.Sprintf("%s.%s", pkg.Name, ts.Name.Name),
								Name:      ts.Name.Name,
								Type:      chunkType,
								Package:   pkg.Name,
								FilePath:  relPath,
								StartLine: startPos.Line,
								EndLine:   endPos.Line,
								Content:   content,
								Doc:       strings.TrimSpace(doc),
							})
						}
					}
				}
			}
		}
	}
	return chunks
}

// PrintNode mengubah node AST kembali menjadi representasi teks kode sumber.
func PrintNode(fset *token.FileSet, node ast.Node) string {
	var buf bytes.Buffer
	if err := printer.Fprint(&buf, fset, node); err != nil {
		return ""
	}
	return buf.String()
}
