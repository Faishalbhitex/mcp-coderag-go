# Lesson: Fix setup-env.sh PATH Duplicate #21

## Penemuan
- **Masalah**: Skema pengecekan string eksak sebelumnya gagal mendeteksi baris PATH yang fungsional sama tapi berbeda penulisan (misal `$HOME/go/bin` vs `$GOPATH/bin`), menyebabkan entri duplikat di `.bashrc`.
- **Solusi**: Menggunakan `grep -qF` dengan pattern yang lebih spesifik (`export PATH=$PATH:$GOPATH/bin`) untuk memastikan baris tersebut hanya ditambahkan satu kali secara idempotent.
- **Pelajaran**: Selalu sertakan prefix operasional seperti `export` dalam pengecekan string di `.bashrc` untuk menghindari false negative saat pengecekan keberadaan baris.

## Dampak
- `.bashrc` pengguna tetap bersih dari duplikasi variabel lingkungan meskipun skema setup dijalankan berkali-kali.
