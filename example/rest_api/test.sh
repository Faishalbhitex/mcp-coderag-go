#!/bin/bash

# 1. Jalankan Go Server di background
echo "Starting server..."
./server &

# Simpan PID (Process ID) server yang baru saja dijalankan
SERVER_PID=$!

# Tunggu sebentar agar server benar-benar siap
sleep 2

# 2. Jalankan test menggunakan curl
echo -e "
Running tests..."
RESPONSE=$(curl -s "http://localhost:8080/hello?name=Gemini")
echo "Response: $RESPONSE"

# Contoh test lagi dengan parameter kosong
RESPONSE_GUEST=$(curl -s "http://localhost:8080/hello")
echo "Guest Response: $RESPONSE_GUEST"

# 3. Matikan server setelah selesai
echo -e "
Stopping server (PID: $SERVER_PID)..."
kill $SERVER_PID

echo "Done!"
