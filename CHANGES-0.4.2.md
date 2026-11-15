# Perubahan KLIK 0.4.2

Halaman QRIS untuk contoh alur bergabung pada pertandingan berbayar.

- Tombol Gabung pada kartu ruang berbayar langsung membuka QR; tombol Daftar Event pada detail event berbayar membuka halaman yang sama.
- Nominal mengikuti biaya pertandingan. QR ditampilkan di atas bidang putih pada tema terang maupun gelap.
- Kode berlaku 15 menit, dapat dibuka kembali selama masih berlaku, dan dapat dibuat ulang setelah kedaluwarsa.
- Peserta baru bergabung setelah menekan Konfirmasi pembayaran. Pembatalan tidak menambah peserta.
- Konfirmasi dan keikutsertaan disimpan dalam satu penulisan data lokal. Konfirmasi berulang tidak menambah slot dua kali; kegagalan penyimpanan tidak dianggap berhasil.
- Pertandingan gratis tetap menggunakan alur gabung tanpa pembayaran.
- Halaman pembayaran tidak menampilkan tulisan Simulasi sesuai kebutuhan tampilan uji coba.

## Batas fitur contoh

QR berisi JSON contoh dengan purpose checkout-preview dan test_only true, bukan format QRIS pembayaran EMV. Kode ini tidak dapat dipakai menerima uang melalui aplikasi bank/dompet digital. Tombol Konfirmasi pembayaran adalah konfirmasi lokal, bukan verifikasi transaksi dari bank/Midtrans. Status internal bernama demo_confirmed, bukan paid/settlement. Fitur ini tidak terhubung ke Midtrans dan tidak memerlukan akun atau Server Key.

Untuk pembayaran sungguhan, sumber QR, nominal, status pembayaran, kapasitas peserta dan pendaftaran harus ditentukan serta diverifikasi server yang terhubung ke penyedia pembayaran; konfirmasi pada client ini bukan pengganti verifikasi tersebut.

## Kode utama

- lib/features/payments/presentation/checkout_screen.dart: halaman QR, batas waktu, pembatalan dan hasil konfirmasi.
- lib/features/payments/logic/checkout_rules.dart: aturan contoh pembayaran dan gabung.
- lib/data/models/checkout_preview.dart: rekaman lokal dan isi QR contoh.
- test/checkout_test.dart: 11 tes baru untuk nominal, masa berlaku, pembatalan, konfirmasi berulang, kapasitas, kegagalan penyimpanan dan alur layar.

Hasil pemeriksaan aktual dan APK dicatat dalam VALIDATION.md.

