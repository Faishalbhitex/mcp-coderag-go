# Lesson: Fix Migration #20

## Penemuan
- **Masalah**: Migration awal (`001`, `002`) mengasumsi tabel sudah ada, sehingga gagal pada instalasi baru (fresh install).
- **Limitasi pgvector (HNSW)**: Index HNSW di lingkungan ini memiliki batas maksimal 2000 dimensi. Menggunakan `vector(3072)` dari model Gemini menyebabkan error saat pembuatan index.
- **Solusi**: 
    1. Membuat `000_create_table.sql` untuk inisialisasi awal.
    2. Menurunkan dimensi embedding menjadi `1536` agar kompatibel dengan index HNSW (batas 2000).
    3. Mengupdate `setup-db.sh` dan `Makefile` untuk memastikan migrasi dijalankan secara berurutan.

## Dampak
- Setup di device baru sekarang lebih andal karena skema tabel dibuat dari nol jika belum ada.
- Dokumentasi `SCHEMA.md` sekarang akurat dengan implementasi fisik database.
