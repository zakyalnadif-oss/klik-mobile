# Hasil pemeriksaan KLIK 0.4.2 — 15 November 2026

Versi: 0.4.2+6. Pemeriksaan runtime: GitHub Actions Ubuntu 24.04, Flutter 3.50.0, Dart 3.14.0, JDK 21.

Repositori privat: https://github.com/zakyalnadif-oss/klik-mobile
Revisi aplikasi: ceda60b333d1e5e72c953887d535cdb676c44985
Run berhasil: https://github.com/zakyalnadif-oss/klik-mobile/actions/runs/43691668961

| Pemeriksaan | Hasil |
| --- | --- |
| Analisis kode | Lulus, No issues found. |
| Aturan/penyimpanan | 47 pemeriksaan lulus. |
| Unit dan widget | 23 tes lulus, termasuk 11 tes checkout baru. |
| Alur checkout | Gabung ruang berbayar membuka QR langsung. Peserta belum bergabung ketika QR dibuka. Konfirmasi lokal menyimpan keikutsertaan dan status demo_confirmed bersama-sama. |
| Pembatalan dan kedaluwarsa | Tidak memasukkan peserta. Kode yang telah dibatalkan/kedaluwarsa ditolak dan dapat dibuat ulang. |
| Konfirmasi berulang | Tidak menambah peserta/slot dua kali. |
| Nominal, referensi dan kapasitas | Nominal mengikuti biaya pertandingan. Nominal berubah, referensi salah, atau pertandingan penuh menolak konfirmasi. |
| Kegagalan penyimpanan | Tidak menampilkan konfirmasi berhasil atau mengurangi slot; dapat dicoba kembali. |
| Tampilan QR | Putih dengan modul hitam di tema terang/gelap. Tidak menampilkan tulisan Simulasi. Nominal tetap utuh pada layar kecil dengan teks 200%. |
| Gambar layar | 66 PNG dihasilkan; halaman QR, hasil konfirmasi dan nominal besar ditinjau, bersama regresi layar utama. |
| APK | Build berhasil, diunduh dan diverifikasi. Delapan entri/aset wajib tersedia. |
| Metadata Android | id.klik.klik_mobile; versionName 0.4.2; versionCode 6; minSdk 24; targetSdk 36; label KLIK. |
| Tanda tangan | apksigner: Verifies, APK Signature Scheme v2 valid, RSA 2048-bit, sertifikat debug sementara. |
| HP pengguna | Belum dicoba langsung pada revisi ini. |
| Pembayaran asli/server | Tidak diaktifkan; fitur ini adalah contoh tampilan dan alur lokal. |

APK: KLIK-0.4.2-Testing.apk
Ukuran: 172162400 byte
SHA-256: a3133c2b12a5229673a8d03486f9bedea709c9531ae7c8e9590ad06e5b610ec2

QR berisi JSON contoh purpose checkout-preview dan test_only true, bukan payload QRIS pembayaran. Kode ini tidak menerima uang melalui bank/dompet digital. Konfirmasi pembayaran adalah aksi lokal untuk mencoba alur pendaftaran; tidak ada verifikasi transaksi dari Midtrans, bank atau server. Status contoh tidak dinamai paid/settlement. Tidak ada Server Key Midtrans yang dimasukkan ke aplikasi. Rincian ada di CHANGES-0.4.2.md.

Sertifikat debug berbeda dari APK sebelumnya. Android dapat menolak pembaruan langsung. Jika versi lama dicopot sebelum pemasangan, data lokal ikut terhapus; petunjuk dan penjelasan ada di CARA-COBA.txt.

Hasil tes tidak menjamin semua bug pada semua perangkat telah ditemukan. Backend Supabase, database bersama, akun online dan kesamaan penuh semua layar Figma belum diverifikasi pada pekerjaan ini.
