# KLIK 0.4.3

Input skor dibatasi pada ketua kedua tim terdaftar di room Berperingkat, setelah pertandingan selesai. Kepemilikan room atau kesamaan nama profil tidak memberikan akses skor.

Dua input disimpan terpisah menurut ID ketua. Keduanya menggunakan urutan skor Tim A dan Tim B. Hasil pertama berstatus Menunggu konfirmasi; skor berbeda berstatus Skor berbeda; skor yang sama berstatus Disahkan dan terkunci. Sebelum disahkan, masing-masing ketua dapat memperbarui inputnya sendiri. Konfirmasi identik yang diulang tidak mengubah hasil.

Pendaftaran dua tim dilakukan sebelum kickoff. Ketua Tim B dapat menarik timnya sebelum kickoff dengan keluar dari room; setelah kickoff peran ketua tidak dapat diganti melalui pendaftaran ulang. Nama dan ID tim/ketua pada pertandingan disimpan sebagai snapshot. Pengubahan nama profil tidak memindahkan hak input skor.

Identitas lokal ditambahkan secara persisten ketika membaca data lama. Data dan hasil versi sebelumnya tetap dipertahankan; hasil lama hanya dapat dibaca, tidak dianggap sebagai persetujuan dua ketua.

Pengaturan menyediakan Coba input dua ketua. Halaman ini menggunakan data terpisah, sehingga peralihan peran contoh tidak memberi hak baru pada room asli.

Penyimpanan tetap lokal. Otorisasi dan sinkronisasi dua pengguna pada HP berbeda belum tersedia; backend harus menggunakan identitas akun terautentikasi dan memvalidasi ulang peran/hasil secara atomik. Tidak ada pembaruan poin peringkat resmi. Petunjuk penggunaan tersedia di CARA-UJI-SKOR.md. Hasil pengujian aktual dicatat di VALIDATION.md.
