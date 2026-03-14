# Observasi: gocoderag Tools Behavior
**Tanggal**: 15 Mar 2026
**Project diobservasi**: mcp-coderag-go (dogfooding)
**Tools ditest**: list_packages, search_code, get_chunk, search_by_file, reindex

## Ringkasan Paket Terindex
Berdasarkan `list_packages`, project memiliki 6 package utama:
- `main`: 19 chunks (entry points, MCP handlers, indexer)
- `store`: 8 chunks (DB logic, pgvector, upsert)
- `rag`: 4 chunks (RRF logic, hybrid search)
- `service`, `handler`, `chunker`: masing-masing 3-4 chunks.

## Hasil Per Tool

### list_packages
- Behavior: Memberikan gambaran makro struktur project.
- Kapan paling berguna: Di awal sesi untuk memahami "peta" codebase dan paket apa saja yang tersedia.

### search_code
- Query konseptual: Berhasil menemukan logika relevan (skor RRF ~0.016). Contoh: 'embedding vector semantic search' menemukan `rag.Search`.
- Query nama fungsi eksak: Sangat presisi (skor RRF ~0.032). Contoh: 'UpsertChunk' langsung menempatkan `store.UpsertChunk` di posisi teratas.
- Range score yang ditemukan: ~0.015 (lemah/semantik luas) hingga ~0.033 (eksak).
- Pattern query yang efektif: Menggunakan nama fungsi/struct yang spesifik memberikan hasil yang jauh lebih baik daripada deskripsi natural language yang panjang.
- Pattern query yang kurang efektif: Query yang terlalu umum (misal: 'docker') pada project yang tidak memilikinya akan mengembalikan hasil dengan skor rendah berdasarkan kemiripan kata kunci teknis lainnya.

### get_chunk
- Behavior: Mengambil konten kode lengkap dari satu unit logis.
- Format ID: `package.Name` (contoh: `store.UpsertChunk`).
- Kapan lebih baik dari search_by_file: Saat kita sudah tahu fungsi spesifik yang ingin dipelajari dan hanya butuh konteks fungsi tersebut tanpa gangguan kode lain di file yang sama.

### search_by_file
- Behavior: Mengembalikan semua chunk dalam satu file secara berurutan berdasarkan baris.
- Kapan lebih baik dari get_chunk: Saat ingin memahami urutan eksekusi atau hubungan antar fungsi dalam satu file (misal: melihat `Searcher` struct dan `NewSearcher` constructor bersamaan).

### reindex
- Behavior: Memperbarui index untuk path tertentu secara manual.
- Kapan harus dipanggil: Segera setelah melakukan perubahan kode agar hasil `search_code` tetap akurat.

## Urutan Optimal yang Ditemukan
Alur paling efisien:
1. `list_packages` untuk orientasi.
2. `search_code` dengan kueri konseptual untuk menemukan titik awal.
3. `get_chunk` atau `search_by_file` untuk mendalami logika.

## Anti-Pattern yang Ditemukan
- Langsung melakukan `search_code` tanpa tahu isi project sering kali menghasilkan terlalu banyak pilihan jika kueri terlalu umum.
- Mengandalkan pencarian semantik murni untuk fungsi yang namanya sudah diketahui (lebih baik cari nama eksaknya).

## Catatan Khusus
- Skor RRF `0.01` adalah threshold yang baik untuk membuang hasil yang tidak relevan.
- ID chunk menggunakan format `package.Name` yang memudahkan pemanggilan `get_chunk` langsung dari hasil `search_code`.
