# Lesson: Fix configure-mcp.sh & README #22

## Penemuan
- **Masalah 1**: Penggunaan `echo -e` dengan variabel yang mengandung warna ANSI menyebabkan kode reset `\033[0m` tercetak secara literal pada beberapa terminal/shell saat di-copy.
- **Masalah 2**: URL repositori di README masih menggunakan placeholder `user` bukan username yang benar.
- **Solusi**: 
    1. Menggunakan `printf` murni tanpa warna untuk blok perintah yang ditujukan untuk di-copy user agar bersih dari karakter kontrol.
    2. Menggunakan `cat << 'EOF'` (dengan kutipan) untuk blok JSON/config agar variabel seperti `$DB_URL` tidak di-expand prematur oleh shell saat ditampilkan.
    3. Memperbarui URL repositori di README menjadi `github.com/Faishalbhitex/mcp-coderag-go`.

## Dampak
- Pengalaman pengguna lebih baik karena perintah yang ditampilkan bisa langsung di-copy-paste tanpa error karakter ilegal.
- Dokumentasi README sekarang merujuk ke repositori yang benar.
