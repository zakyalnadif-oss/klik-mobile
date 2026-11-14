# Hasil pemeriksaan — 14 November 2026

Versi sumber 0.4.0+4. Lokal: Windows, Flutter 3.50.0, Dart 3.14.0, JDK 21. Pemeriksaan runtime: GitHub Actions Ubuntu 24.04, Flutter 3.50.0, JDK 21.

Repositori privat: https://github.com/zakyalnadif-oss/klik-mobile
Revisi yang diperiksa: 8a1c48b0a79017ed5bc13fc253497f5056dc8aa9
Run: https://github.com/zakyalnadif-oss/klik-mobile/actions/runs/43574184972

| Pemeriksaan | Hasil aktual |
| --- | --- |
| Resolusi paket | Berhasil; versi dikunci dalam pubspec.lock. |
| Analisis kode | Lulus lokal dan GitHub: No issues found. |
| Aturan bisnis dan penyimpanan | 47 pemeriksaan lulus lokal dan GitHub. |
| Tes konfigurasi/widget/layar | 9 tes lulus di GitHub, termasuk lima tab, pencarian sekunder, tema, teks 200% pada layar kecil, kegagalan penyimpanan dan penangkapan layar rute utama. |
| Regresi yang ditemukan | Menu bawah terpotong 2 px saat tulisan besar; tinggi menu diperbaiki dan tes ulang lulus. Ikon lokasi/chevron mengikuti tema. Gaya tulisan pilihan memakai Inter dan warna eksplisit. |
| Pemeriksaan visual | Gambar run pertama ditinjau; gambar revisi terbaru masih menunggu artefak build untuk ditinjau. Penangkapan meliputi 22 rute terang/gelap, input/hasil skor dan 11 tampilan kecil dengan teks besar. |
| Build APK lokal | Gagal karena Application Control memblokir Android CLI (os error 4551). Tidak menonaktifkan perlindungan Windows. |
| Build APK GitHub | Sedang berlangsung setelah semua tes lulus. Belum dinyatakan siap hingga APK diunduh dan diperiksa. |
| Supabase Auth/database/RLS/Storage | Belum terhubung atau diuji; pengguna belum memiliki proyek Supabase. |
| Perangkat Android nyata | Belum diuji pada versi Flutter ini. |
| iOS | Belum dibangun atau diuji; memerlukan macOS/Xcode/signing. |

Pemeriksaan aturan mencakup validasi, kapasitas, gabung/keluar berulang, waktu kegiatan, pemilik, skor menunggu konfirmasi, serialisasi UTC, penulisan bersamaan, rollback dan pemulihan setelah kegagalan penyimpanan.

Referensi Figma: konteks Beranda 76:402 berhasil dibaca; pembacaan layar berikutnya terhenti oleh kuota layanan. Aset asli disimpan lokal. Kecocokan penuh seluruh prototipe belum terverifikasi. Tes lulus bukan jaminan tidak ada bug pada seluruh perangkat atau seluruh alur.

Data contoh/peringkat contoh dilabeli. Fitur sosial dan kegiatan saat ini lokal, tidak melakukan transaksi atau sinkronisasi antarpengguna. Penambahan URL/key Supabase saja belum mengaktifkan database kegiatan.
