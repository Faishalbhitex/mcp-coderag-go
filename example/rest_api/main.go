package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
)

// Interface sebagai kontrak
type GreetingService interface {
	Greet(name string) string
}

// Struct yang mengimplementasikan interface
type SimpleGreeter struct {
	Prefix string
}

// Fungsi yang memenuhi interface
func (s SimpleGreeter) Greet(name string) string {
	if name == "" {
		name = "Guest"
	}
	return fmt.Sprintf("%s, %s!", s.Prefix, name)
}

// Handler untuk API
type APIHandler struct {
	Service GreetingService
}

func (h APIHandler) HelloHandler(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	message := h.Service.Greet(name)

	response := map[string]string{"message": message}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	greeter := SimpleGreeter{Prefix: "Hello"}
	handler := APIHandler{Service: greeter}

	http.HandleFunc("/hello", handler.HelloHandler)

	fmt.Println("Server starting on port 8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
