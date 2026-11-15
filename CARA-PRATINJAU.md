# Melihat KLIK tanpa memasang APK

## Melalui VS Code

1. Buka folder LOMBA/KLIK-Flutter dengan File > Open Folder.
2. Tekan Ctrl+Shift+D untuk membuka Run and Debug.
3. Pilih profil KLIK · Chrome pada daftar di bagian atas.
4. Tekan F5. Flutter menyiapkan aplikasi dan membuka Chrome.
5. Pilih Coba tanpa akun untuk mencoba alurnya.

Selama sesi F5 berjalan, menyimpan perubahan widget Dart dengan Ctrl+S akan meminta hot reload. Pengaturan proyek mengaktifkan hot reload untuk penyimpanan otomatis maupun manual. Jika perubahan membutuhkan restart, gunakan tombol Hot Restart pada toolbar debug. Untuk berhenti, tekan Shift+F5.

Pratinjau memakai alamat http://127.0.0.1:7357. Alamat ini dapat dibuka setelah proses Flutter berhasil berjalan. Chrome, terminal atau sesi debug harus tetap berjalan. Jalankan satu sesi pratinjau saja pada port tersebut.

## Pintasan

Klik dua kali BUKA-DI-BROWSER.cmd dalam folder proyek. Pintasan menjalankan flutter pub get lalu flutter run -d chrome. Biarkan jendela yang terbuka tetap berjalan. Saat kode berubah, tekan r di jendela tersebut untuk hot reload; tekan q untuk berhenti.

## Tampilan seperti HP

Di Chrome, tekan F12 lalu Ctrl+Shift+M untuk mengaktifkan ukuran perangkat. Pilih ukuran telepon atau atur sekitar 402 x 874. Ini membantu memeriksa tampilan; perilaku Android yang khusus tetap perlu diuji melalui APK pada HP.

## Jika belum terbuka

- Tunggu penyiapan pertama selesai; Flutter mungkin perlu mengunduh paket yang belum ada.
- Jika port 7357 sedang dipakai, hentikan sesi KLIK sebelumnya dengan Shift+F5 atau q pada terminal sebelumnya.
- Jika Flutter SDK tidak ditemukan, pilih SDK Flutter yang sudah terpasang di komputer melalui pengaturan extension Dart/Flutter.
- Jika alat Flutter ditolak oleh pengaturan komputer, simpan pesan kesalahannya untuk diperiksa. Jangan menonaktifkan perlindungan perangkat.

Data browser terpisah dari data APK. Data tersimpan pada profil browser dan alamat pratinjau tersebut; menghapus data situs dapat menghapus data percobaan.

Referensi: https://docs.flutter.dev/platform-integration/web/building
