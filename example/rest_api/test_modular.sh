#!/bin/bash

# Build dan Jalankan Modular Go Server di background
echo "Building modular server..."
go build -o modular_server example/rest_api/cmd/api/main.go

echo "Starting modular server..."
./modular_server &
SERVER_PID=$!

# Tunggu sebentar
sleep 2

# Test API
echo -e "
Running tests on port 8081..."
RESPONSE=$(curl -s "http://localhost:8081/hello?name=ModularUser")
echo "Response: $RESPONSE"

# Matikan server
echo -e "
Stopping server (PID: $SERVER_PID)..."
kill $SERVER_PID

# Bersihkan binary
rm modular_server

echo "Done!"
