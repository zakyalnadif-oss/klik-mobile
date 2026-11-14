# Hasil pemeriksaan — 14 November 2026

Versi sumber 0.4.0+4. Lokal: Windows, Flutter 3.50.0, Dart 3.14.0, JDK 21. Pemeriksaan runtime: GitHub Actions Ubuntu 24.04, Flutter 3.50.0, JDK 21.

Repositori privat: https://github.com/zakyalnadif-oss/klik-mobile
Revisi yang diperiksa: e3ee3756e2536b561427cfdfff592898d6dfd26c
Run: https://github.com/zakyalnadif-oss/klik-mobile/actions/runs/43575754086

| Pemeriksaan | Hasil aktual |
| --- | --- |
| Resolusi paket | Berhasil; versi dikunci dalam pubspec.lock. |
| Analisis kode | Lulus lokal dan GitHub: No issues found. |
| Aturan bisnis dan penyimpanan | 47 pemeriksaan lulus lokal dan GitHub. |
| Tes konfigurasi/widget/layar | 9 tes lulus di GitHub, termasuk lima tab, pencarian sekunder, tema, teks 200% pada layar kecil, kegagalan penyimpanan dan penangkapan layar rute utama. |
| Regresi yang ditemukan | Menu bawah terpotong 2 px saat tulisan besar; tinggi menu diperbaiki dan tes ulang lulus. Ikon lokasi/chevron mengikuti tema. Gaya tulisan pilihan memakai Inter dan warna eksplisit. Lokasi Beranda berpindah ke baris lebar pada layar kecil/teks besar. Kategori pencarian mengikuti perubahan parameter navigasi; tes memverifikasi kategori Acara dan skor 5–3 benar-benar tersimpan. |
| Pemeriksaan visual | 59 gambar berhasil dihasilkan. Gambar utama terang/gelap serta perubahan Beranda, kategori Acara dan hasil skor ditinjau. Penangkapan meliputi 22 rute terang/gelap, input/hasil skor dan 11 tampilan kecil dengan teks besar. |
| Build APK lokal | Gagal karena Application Control memblokir Android CLI (os error 4551). Tidak menonaktifkan perlindungan Windows. |
| Build APK GitHub | Berhasil. APK diunduh dan diperiksa: delapan entri/aset wajib tersedia; apksigner menyatakan Verifies, APK Signature Scheme v2 valid. APK debug untuk percobaan. |
| Supabase Auth/database/RLS/Storage | Belum terhubung atau diuji; pengguna belum memiliki proyek Supabase. |
| Perangkat Android nyata | Belum diuji pada versi Flutter ini. |
| iOS | Belum dibangun atau diuji; memerlukan macOS/Xcode/signing. |

Pemeriksaan aturan mencakup validasi, kapasitas, gabung/keluar berulang, waktu kegiatan, pemilik, skor menunggu konfirmasi, serialisasi UTC, penulisan bersamaan, rollback dan pemulihan setelah kegagalan penyimpanan.

Referensi Figma: konteks Beranda 76:402 berhasil dibaca; pembacaan layar berikutnya terhenti oleh kuota layanan. Aset asli disimpan lokal. Kecocokan penuh seluruh prototipe belum terverifikasi. Tes lulus bukan jaminan tidak ada bug pada seluruh perangkat atau seluruh alur.

Data contoh/peringkat contoh dilabeli. Fitur sosial dan kegiatan saat ini lokal, tidak melakukan transaksi atau sinkronisasi antarpengguna. Penambahan URL/key Supabase saja belum mengaktifkan database kegiatan.

APK: KLIK-Flutter-Testing.apk; 172055140 byte.
SHA-256: bdc356d289f37cde22094d9f9e9ceb2ebe6c577a85cddf344ff0a18510e1a927

