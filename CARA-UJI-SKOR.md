# Mencoba input skor dua ketua tim

## Cara cepat pada satu perangkat

1. Buka proyek KLIK-Flutter di VS Code. Hentikan sesi lama dengan Shift+F5, pilih KLIK · Chrome, lalu tekan F5.
2. Di KLIK, buka Profil > Pengaturan > Coba input dua ketua.
3. Pilih Ketua Tim Merah, isi skor Tim Merah 5 dan Tim Biru 3, lalu Kirim skor ketua.
4. Status menjadi Menunggu konfirmasi.
5. Pilih Ketua Tim Biru, isi urutan yang sama: Tim Merah 5 dan Tim Biru 3.
6. Kirim. Status menjadi Disahkan dan skor terkunci.

Untuk menguji perbedaan, tekan Ulangi contoh. Isi 5–3 dari ketua pertama dan 4–3 dari ketua kedua. Status menjadi Skor berbeda. Ketua yang mengisi angka keliru dapat memperbaiki inputnya sampai kedua skor sama.

Halaman contoh memakai data terpisah dan tidak mengubah peran, hasil, atau peserta pada room kamu.

## Aturan pada room

- Hanya room dengan mode Berperingkat yang menyediakan input skor. Room Kasual dan event tidak menyediakan fitur ini.
- Pembuat room Berperingkat mengisi nama timnya dan didaftarkan sebagai ketua Tim A.
- Ketua lawan harus bergabung ke room, lalu membuka Tim dan ketua pertandingan untuk mendaftarkan timnya sebagai Tim B.
- Kedua ketua harus berbeda, dan pendaftaran tim ditutup saat pertandingan dimulai.
- Setelah pertandingan selesai, hanya kedua ketua terdaftar yang memperoleh tombol input skor.
- Isikan skor menurut urutan Tim A dan Tim B yang tampil di layar, termasuk ketika kamu ketua Tim B.
- Input pertama menunggu ketua lawan; dua input sama disahkan; dua input berbeda belum disahkan. Masing-masing ketua hanya memperbarui inputnya sendiri.
- Skor yang telah disahkan terkunci. Poin peringkat resmi belum diperbarui pada versi lokal.

## Batas versi saat ini

Data dan identitas pemain masih lokal per perangkat. Dua HP belum saling mengirim input skor. Gunakan halaman contoh untuk menguji dua ketua pada satu perangkat. Untuk penggunaan sungguhan antar-HP, identitas ketua, keanggotaan tim, waktu pertandingan, kedua input dan pengesahan harus diverifikasi pada backend dengan akun terautentikasi. Aturan client ini bukan otorisasi server produksi.
