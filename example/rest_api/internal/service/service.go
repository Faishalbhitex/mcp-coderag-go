package service

import (
	"fmt"
)

// GreetingService sebagai kontrak logika bisnis
type GreetingService interface {
	Greet(name string) string
}

// SimpleGreeter mengimplementasikan GreetingService
type SimpleGreeter struct {
	Prefix string
}

// NewSimpleGreeter membuat instance baru dari SimpleGreeter
func NewSimpleGreeter(prefix string) *SimpleGreeter {
	return &SimpleGreeter{Prefix: prefix}
}

// Greet menghasilkan pesan sapaan
func (s *SimpleGreeter) Greet(name string) string {
	if name == "" {
		name = "Guest"
	}
	return fmt.Sprintf("%s, %s!", s.Prefix, name)
}
