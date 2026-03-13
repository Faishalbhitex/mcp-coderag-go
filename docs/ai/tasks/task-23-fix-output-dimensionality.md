# Lesson: Fix Output Dimensionality #23

## Penemuan
- **Masalah**: Meskipun database sudah menggunakan `vector(1536)` (hasil dari PR #20), kode Go masih mengirimkan permintaan embedding tanpa menentukan dimensi output. Secara default, Gemini API mengembalikan 3072 dimensi, yang menyebabkan PostgreSQL menolak data tersebut dengan error: `ERROR: expected 1536 dimensions, not 3072`.
- **Implementasi SDK**: Field `OutputDimensionality` di `genai.EmbedContentConfig` bertipe `*int32`. Oleh karena itu, kita harus memberikan alamat memori dari sebuah variabel `int32` (misalnya `&dim`), bukan nilai literal secara langsung.
- **Solusi**: Menambahkan `OutputDimensionality: &dim` (di mana `dim := int32(1536)`) di kedua tempat di mana embedding dilakukan:
    1. `internal/store/store.go` (saat indexing/upsert)
    2. `internal/rag/rag.go` (saat melakukan query search)

## Dampak
- Proses indexing sekarang berjalan lancar tanpa error dimensi di PostgreSQL.
- Pencarian hybrid (semantic) sekarang berfungsi kembali karena dimensi vektor query sudah sinkron dengan dimensi vektor di database.
- Performa HNSW tetap optimal di Termux karena tetap berada di bawah batas 2000 dimensi.
