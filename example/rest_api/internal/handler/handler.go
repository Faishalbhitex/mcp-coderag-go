package handler

import (
	"encoding/json"
	"net/http"

	"mcp-coderag-go/example/rest_api/internal/service"
)

// APIHandler menyimpan dependensi ke service layer
type APIHandler struct {
	Service service.GreetingService
}

// NewAPIHandler membuat handler baru
func NewAPIHandler(svc service.GreetingService) *APIHandler {
	return &APIHandler{Service: svc}
}

// HelloHandler menangani endpoint /hello
func (h *APIHandler) HelloHandler(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	
	// Memanggil logika bisnis di service layer
	message := h.Service.Greet(name)

	response := map[string]string{
		"message": message,
		"source":  "modular-api",
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
