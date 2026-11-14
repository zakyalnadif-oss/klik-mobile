# Hasil pemeriksaan KLIK 0.4.1 — 14 November 2026

Versi sumber: 0.4.1+5. Lingkungan CI: Ubuntu 24.04, Flutter 3.50.0, Dart 3.14.0, JDK 21.

Repositori privat: https://github.com/zakyalnadif-oss/klik-mobile
Revisi aplikasi: 2a550386ad649997225895b672cc3c447a34b26a
Run berhasil: https://github.com/zakyalnadif-oss/klik-mobile/actions/runs/43585809249

| Pemeriksaan | Hasil |
| --- | --- |
| Analisis kode | Lulus, No issues found. |
| Aturan dan penyimpanan lokal | 47 pemeriksaan lulus: validasi, kapasitas, gabung/keluar berulang, kepemilikan, waktu kegiatan, skor, UTC, antrean penulisan dan rollback. |
| Konfigurasi dan widget | 12 tes lulus. Tiga tes baru menguji ukuran kartu event, kesamaan garis bawah tombol, perataan tombol/label ruang dan tampilan 320 x 568 dengan teks 200%. |
| Tangkapan layar | 59 gambar dihasilkan: 22 rute terang/gelap, Beranda bagian bawah, input/hasil skor dan 11 tampilan kecil dengan teks besar. Gambar utama diperiksa, termasuk perataan label/tombol, kategori Acara dan hasil 5–3 yang tersimpan. |
| Kartu event | Kartu dengan judul pendek/panjang memiliki ukuran sama dan tombol sejajar. Tinggi mengikuti isi terpanjang; isi tidak dipotong untuk menyamakan ukuran. |
| Kartu ruang | Tombol Gabung dan label Kasual/Berperingkat berada pada sisi kanan yang sama; jarak ke tepi kartu diperiksa otomatis. |
| APK Android | Build berhasil dan berkas diunduh. Delapan entri/aset wajib tersedia. |
| Metadata APK | aapt2: id.klik.klik_mobile, versionName 0.4.1, versionCode 5, minSdk 24, targetSdk 36, label KLIK. |
| Tanda tangan | apksigner: Verifies; APK Signature Scheme v2 valid, RSA 2048-bit, sertifikat debug sementara. |
| HP Android pengguna | Belum diuji langsung setelah perbaikan ini; perlu dicoba pada perangkat pengguna. |
| Supabase/server/RLS/multi-pengguna | Belum terhubung atau diuji; proyek Supabase belum tersedia. Data uji coba lokal. |

APK: KLIK-0.4.1-Testing.apk
Ukuran: 172057572 byte
SHA-256: 3848e61685ae8727b0734639c2a7b8ac5a04f5951f16a4c550a4b9a35ab3684f

Sertifikat debug berbeda dari APK 0.4.0 sebelumnya. Untuk mengganti versi lama dengan APK ini, aplikasi lama perlu dicopot; data lokalnya ikut dihapus. Pengguna telah memilih penggantian versi lama dan menyetujui reset data percobaan. Petunjuk tersedia di CARA-COBA.txt.

Tes yang lulus tidak menjamin seluruh bug di semua perangkat atau seluruh alur telah ditemukan. Kecocokan penuh seluruh prototipe Figma belum terverifikasi karena pembacaan Figma sebelumnya dibatasi kuota. Referensi perbaikan ini adalah tangkapan layar pengguna dan kode aplikasi saat ini.
