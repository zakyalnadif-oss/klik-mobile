# Hasil pemeriksaan KLIK 0.4.3 — 15 November 2026

Versi: 0.4.3+7. Lingkungan: Flutter 3.50.0, Dart 3.14.0, JDK 21; runtime CI Ubuntu 24.04.

Repositori privat: https://github.com/zakyalnadif-oss/klik-mobile
Revisi aplikasi: 5023e3b7802972b3df889f8a1ff6be1b13d65f4f
Run berhasil: https://github.com/zakyalnadif-oss/klik-mobile/actions/runs/43699019059

| Pemeriksaan | Hasil |
| --- | --- |
| Analisis kode | Lulus, No issues found. |
| Aturan dan penyimpanan | 48 pemeriksaan lulus. |
| Unit dan widget | 38 tes lulus, termasuk 15 tes peran, hasil, migrasi dan contoh dua ketua. |
| Room Kasual/event | Tidak menyediakan input skor; pemanggilan logika dan tautan langsung ke form ditolak. |
| Peran | Kedua ID ketua terdaftar diizinkan meskipun bukan pemilik room. Anggota biasa dan pemilik yang bukan ketua ditolak, termasuk jika nama profil menyerupai ketua. |
| Waktu dan keikutsertaan | Kedua tim harus terdaftar, ketua harus bergabung, dan pertandingan harus selesai sebelum input skor. |
| Dua input | Input disimpan per ID ketua dengan urutan Tim A/Tim B. Satu input menunggu; berbeda menghasilkan Skor berbeda; sama menghasilkan Disahkan. |
| Penguncian | Skor yang disahkan tidak dapat diubah; pengiriman ulang identik tidak mengubah hasil. |
| Perbaikan skor | Sebelum disahkan, masing-masing ketua memperbarui inputnya sendiri. Input ketua lain dipertahankan. |
| Pendaftaran tim | Ketua/tim tidak dapat diganti melalui pendaftaran ulang; pendaftaran ditutup saat kickoff. Penarikan Tim B sebelum kickoff membuka slot lawan kembali. |
| Penyimpanan gagal | Persetujuan kedua tidak dianggap tersimpan; status sebelumnya dipertahankan dan dapat dicoba kembali. |
| Validasi data | Persetujuan dengan satu input atau input pihak luar ditolak. Data lama dipertahankan dan ID lokal stabil saat dimuat ulang. |
| Contoh dua ketua | Alur UI dua ketua menghasilkan Disahkan dan tidak mengubah hasil pada data utama. |
| Gambar layar | 74 PNG dihasilkan; form, pendaftaran tim, contoh ketua, hasil berbeda dan hasil disahkan ditinjau. |
| APK | Build berhasil, diunduh, delapan entri/aset wajib ditemukan. |
| Metadata APK | id.klik.klik_mobile; versionName 0.4.3; versionCode 7; minSdk 24; targetSdk 36; label KLIK. |
| Tanda tangan | apksigner: Verifies, APK Signature Scheme v2 valid, RSA 2048-bit, sertifikat debug sementara. |
| Perangkat pengguna | Belum diuji langsung pada HP pengguna setelah perubahan ini. |

APK: KLIK-0.4.3-Testing.apk
Ukuran: 172190284 byte
SHA-256: 831a8e2d740bdf706f215755e1fc80e75a5fd2abf9687ed24122533508fe60ed

## Batas implementasi

Identitas, tim dan hasil masih disimpan lokal per perangkat. Pembatasan client ini tidak menggantikan autentikasi dan otorisasi backend produksi. Dua HP belum bertukar input skor; sinkronisasi, validasi peran dengan akun terautentikasi, serta pengesahan server belum diaktifkan. Poin peringkat resmi tidak berubah.

Halaman Contoh input dua ketua menggunakan dataset terpisah. Peralihan peran contoh tidak mengganti identitas atau hak akses pada room asli. Data/hasil lama tetap dibaca tanpa dipromosikan menjadi persetujuan dua ketua.

QRIS pada versi ini tetap contoh alur lokal dengan payload JSON test_only; tidak menerima uang dan tidak menghubungi penyedia pembayaran.

Sertifikat debug berbeda dari APK sebelumnya, sehingga pemasangan ulang dapat mengharuskan pencopotan aplikasi lama dan menghapus data lokal. Pratinjau Chrome dapat dipakai untuk mencoba fitur tanpa memasang APK. Baca CARA-UJI-SKOR.md dan CARA-PRATINJAU.md.

Tes lulus tidak menjamin semua bug di semua perangkat sudah ditemukan. Kesamaan penuh seluruh prototipe Figma dan sistem multi-pengguna belum diverifikasi.
