package main

import (
	"fmt"
	"log"
	"net/http"

	"mcp-coderag-go/example/rest_api/internal/handler"
	"mcp-coderag-go/example/rest_api/internal/service"
)

func main() {
	// Inisialisasi Service
	greeter := service.NewSimpleGreeter("Hello from Modular API")
	
	// Inisialisasi Handler dengan Dependency Injection
	h := handler.NewAPIHandler(greeter)

	// Routing
	http.HandleFunc("/hello", h.HelloHandler)

	fmt.Println("Modular Server starting on port 8081...")
	// Menggunakan port 8081 agar tidak bentrok dengan server sebelumnya jika belum mati
	log.Fatal(http.ListenAndServe(":8081", nil))
}
