---
name: gocoderag
description: >
  Expertise in searching and navigating Go codebases using semantic RAG search.
  Use when the user asks to understand how something works in the codebase,
  find a function or struct by concept or name, or needs to explore code relationships
  across packages without reading every file manually.
---

# gocoderag — CodeRAG MCP Server Skill

Skill ini memandu penggunaan tool `gocoderag` untuk eksplorasi codebase Go secara semantik dan efisien.

## Kapan Menggunakan Skill Ini
- Saat baru pertama kali masuk ke project Go yang belum dikenal.
- Saat mencari implementasi fitur tertentu berdasarkan konsep (misal: "authentication", "database connection").
- Saat mencari fungsi atau struct dengan nama yang sudah diketahui (misal: "<FunctionName>").
- Saat ingin memahami hubungan antar komponen tanpa harus membuka banyak file sekaligus.

## Urutan Tool yang Disarankan
Untuk eksplorasi yang efektif, ikuti alur berikut:
1. **`list_packages`**: Gunakan di awal untuk melihat "peta" project (paket apa saja yang ada).
2. **`search_code`**: Gunakan kueri (konseptual atau nama eksak) untuk menemukan titik awal logika.
3. **`get_chunk`**: Gunakan ID dari hasil pencarian (format `<package>.<FunctionName>`) untuk membaca detail implementasi.
4. **`search_by_file`**: Gunakan jika butuh melihat semua fungsi/struct dalam satu file secara berurutan.

## Panduan Per Tool

### list_packages
Memberikan gambaran makro. Fokus pada jumlah chunk dan daftar file untuk menilai kompleksitas suatu paket.

### search_code
- **Kueri Konseptual**: Gunakan kalimat deskriptif untuk mencari logika (skor RRF normal ~0.016).
- **Nama Eksak**: Jika sudah tahu nama fungsi/struct, masukkan langsung kuerinya untuk akurasi maksimal (skor RRF ~0.032).
- **Threshold**: Abaikan hasil dengan skor di bawah 0.01 karena kemungkinan besar tidak relevan (false positive semantik).

### get_chunk
Cara tercepat untuk membaca kode satu fungsi tanpa noise. Gunakan ID `<package>.<FunctionName>` yang didapat dari `search_code`.
**Note**: ID selalu berasal dari hasil `search_code`, jangan mencoba menebak format ID secara manual.

### search_by_file
Berguna untuk memahami struktur satu file secara utuh (misal: melihat struct dan constructor-nya sekaligus). Contoh path: `internal/<package>/<file>.go`.

### reindex
WAJIB dipanggil segera setelah melakukan modifikasi file (`write_file` atau `replace`) agar database tetap sinkron dengan file fisik.
**Note**: Jika `./...` gagal (terlalu besar atau timeout), pecah pemanggilan per subdirektori (misal: `./internal/store/...`).

## Interpretasi Hasil
- **Skor RRF tinggi (> 0.03)**: Sangat akurat, biasanya kecocokan nama eksak.
- **Skor RRF menengah (~0.016)**: Relevan secara semantik atau konseptual.
- **Hasil Null atau Skor < 0.01**: Kueri tidak ditemukan atau tidak relevan. Coba gunakan istilah lain atau cek apakah project sudah di-index.

## Anti-Pattern — Hindari Ini
- Menggunakan kueri yang terlalu umum (misal: "setup") tanpa konteks tambahan.
- Membaca file mentah (cat/ReadFile) secara berlebihan jika satu unit logis sudah tersedia via `get_chunk`.
- Lupa melakukan `reindex` setelah mengedit kode.

## Kombinasi dengan Tools Lain
- Gunakan `gocoderag` untuk **pencarian luas dan konseptual**.
- Gunakan `gopls` (Go Language Server) untuk **navigasi tipe data, referensi, dan definisi simbol** yang lebih presisi (type-safe).
- Gunakan `grep` hanya untuk pencarian teks mentah (misal: mencari string literal atau konstanta).
