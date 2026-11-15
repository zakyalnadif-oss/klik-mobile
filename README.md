# KLIK Mobile — versi uji coba 0.4.3

## A. Tujuan dan fitur

Aplikasi Flutter/Dart untuk mencoba alur KLIK di Android atau Chrome. Lima tab utama: **Beranda, Sosial, Buat, Tanding, Profil**. Pencarian merupakan halaman terpisah.

Versi ini menyediakan pencarian kegiatan/rekan/lapangan, detail kegiatan, gabung dan keluar ruang, pembuatan ruang/acara, perubahan profil, pilihan tema yang tersimpan, komunitas lokal, dan pengajuan skor dengan status menunggu konfirmasi. Data contoh dan peringkat contoh diberi penjelasan di aplikasi.

Belum tersedia sinkronisasi antarpengguna, pengiriman permintaan teman sungguhan, konfirmasi skor oleh lawan, peringkat resmi, tim lengkap, pembayaran, pemesanan lapangan, peta langsung, atau notifikasi push. Mengisi konfigurasi Supabase menyiapkan Auth; itu belum menghubungkan data kegiatan ke database.

## B. File utama

| File/folder | Fungsi |
| --- | --- |
| `lib/main.dart`, `lib/app.dart` | Memulai aplikasi, memuat data, tema dan router. |
| `lib/core/routes/` | Navigasi lima tab dan halaman sekunder. |
| `lib/core/theme/` | Tema terang, gelap dan mengikuti perangkat. |
| `lib/data/models/` | Model kegiatan dan validasi format data lokal. |
| `lib/data/repositories/` | Penyimpanan lokal dan antrean penulisan. |
| `lib/data/providers/` | Keadaan aplikasi dengan Riverpod, client Supabase opsional. |
| `lib/features/` | Halaman serta aturan fitur. |
| `lib/shared/` | Kartu, tombol, ikon dan navigasi bersama. |
| `assets/figma/` | Aset asli Figma dan manifest asal aset. |
| `assets/demo/` | Data contoh untuk percobaan tanpa akun. |
| `tool/check_rules.dart` | 47 pemeriksaan aturan dan penyimpanan. |
| `test/` | Tes konfigurasi, widget dan pengambilan gambar layar. |
| `.github/workflows/android-testing.yml` | Build dan tes Android di GitHub Actions, dijalankan manual. |

## C. Struktur dan bahasa

Bahasa aplikasi: **Dart**, framework **Flutter**. Riverpod mengatur keadaan, go_router mengatur navigasi, shared_preferences menyimpan data lokal, flutter_svg menampilkan ikon, dan supabase_flutter menyiapkan layanan akun opsional. Komponen Material memakai paket material_ui pada Flutter 3.50. Font Inter disertakan lokal beserta lisensinya.

Kode fitur berada di `lib/features/{home,social,events,tanding,profile,auth,venues,leaderboard}`. Widget menyesuaikan tinggi isi dan memakai area aman perangkat. Aplikasi Flutter ini menggambar antarmuka langsung.

## D. Membuka kode di VS Code

Buka folder **KLIK-Flutter** melalui File → Open Folder. Sumber lengkap disertakan, bukan cuplikan. Mulai dari `lib/main.dart`, lalu `lib/app.dart`, router, dan halaman fitur.

Extension yang diperlukan: **Flutter** dan **Dart** dari Dart Code. Extension tersebut sudah terpasang pada komputer saat pemeriksaan. Pilih perangkat di status bar, lalu tekan F5 dengan profil **KLIK · Uji coba** atau **KLIK · Chrome**. Simpan perubahan widget untuk hot reload selama sesi debug. Live Preview HTML proyek lama tidak menjalankan Flutter.

## E. Data disimpan di mana?

Data uji coba disimpan melalui **SharedPreferences** pada penyimpanan aplikasi di perangkat/browser, sebagai JSON dengan kunci `klik.local.testing.v2`. Isinya profil lokal, tema, kegiatan, keikutsertaan dan pengajuan skor. Data tidak dibagikan ke HP lain. Menghapus data aplikasi atau mencopot aplikasi dapat menghapus data lokal; versi ini belum menyediakan cadangan/ekspor pengguna.

Perubahan ditulis secara berurutan. Tampilan baru diperbarui setelah penyimpanan berhasil; kegagalan tidak ditampilkan sebagai sukses. Rekaman yang tidak dapat dibaca dipertahankan dan menampilkan pesan gagal, bukan dihapus diam-diam. Kata sandi tidak disimpan dalam rekaman data lokal ini.

Proyek Supabase pengguna belum tersedia. Belum ada database, migrasi, RLS atau bucket yang diterapkan. Untuk tahap akun berikutnya, salin `config.example.json` menjadi `config.local.json`, isi URL dan publishable/anon key, lalu gunakan profil **KLIK · Supabase**. File lokal itu diabaikan Git. Jangan memasukkan secret key atau service_role. SDK mengelola sesi Auth terpisah; alur lengkap pemulihan kata sandi/deep link mobile masih perlu diselesaikan dan diuji.

## F. Menjalankan dan membuat APK

Lingkungan pemeriksaan: Flutter **3.50.0**, Dart **3.14.0**, JDK **21**. Android membutuhkan platform **36**, Build Tools **36.0.0**, dan NDK **28.2.13676358**. Gunakan lokasi Android SDK tanpa spasi. Ikuti versi dalam pubspec.lock.

Dari terminal folder proyek:

```powershell
flutter pub get
flutter run -d chrome
```

Untuk HP Android, aktifkan USB debugging, sambungkan kabel, setujui dialog pada HP, lalu:

```powershell
flutter devices
flutter run
```

Untuk membuat APK percobaan:

```powershell
dart tool/check_rules.dart
flutter analyze
flutter test
flutter build apk --debug
```

Hasil hanya tersedia jika build berhasil: `build/app/outputs/flutter-apk/app-debug.apk`. File `BUAT-APK.cmd` menjalankan pemeriksaan tersebut dan berhenti jika ada kegagalan. APK debug untuk testing; rilis publik memerlukan signing dan pemeriksaan tambahan.

## G. Build melalui GitHub

Repositori privat berada di https://github.com/zakyalnadif-oss/klik-mobile. Build sudah dijalankan; status aktual dicatat di VALIDATION.md. Untuk menjalankan ulang: buka Actions → KLIK Android testing APK → Run workflow. Workflow menjalankan analisis, pemeriksaan aturan, tes layar terang/gelap dan build APK. Artefak APK dan gambar pemeriksaan disimpan 7 hari. Pemakaian mengikuti kuota Actions akun GitHub.

Unduh artefak APK dari run yang **berhasil**, ekstrak ZIP, lalu pindahkan APK ke HP Android. Izinkan pemasangan dari aplikasi pengelola file yang dipakai jika Android memintanya. APK proyek WebView lama merupakan versi berbeda; jangan menganggapnya hasil build Flutter terbaru.

## H. Pengujian dan kecocokan Figma

Status aktual ada di VALIDATION.md. Analisis kode, 48 pemeriksaan aturan/penyimpanan dan 38 tes konfigurasi/widget/layar telah lulus di GitHub. Pengujian lokal Windows terhalang Application Control; pemeriksaan runtime dilanjutkan di GitHub dengan izin pengguna. Status APK dan pemeriksaan gambar terbaru dicatat di VALIDATION.md.

Beranda dibandingkan dengan konteks Figma yang berhasil dibaca, memakai aset aslinya. Pembacaan layar Figma lain terhenti karena batas penggunaan layanan; sumber Figma yang sudah tersimpan digunakan sebagai referensi tambahan. Seluruh layar belum dapat dinyatakan sama persis dan seluruh bug belum dapat dinyatakan selesai.

Setelah build tersedia, periksa seluruh tab, pencarian, buat/gabung/keluar ruang, profil, tema, ukuran tulisan besar, keyboard dan penyimpanan setelah aplikasi dibuka ulang. Pengujian dua akun, kebijakan database dan perangkat nyata memerlukan tahap tersendiri.

## I. Masalah umum

| Masalah | Tindakan |
| --- | --- |
| Flutter tidak dikenali | Tambahkan flutter/bin ke PATH, buka ulang terminal. |
| Android SDK memiliki spasi | Gunakan lokasi SDK tanpa spasi dan perbarui konfigurasi Flutter/Android Studio. |
| HP tidak terdeteksi | Periksa USB debugging, persetujuan HP, kabel dan driver. |
| Windows memblokir alat resmi | Minta pengelola perangkat memeriksa izin, atau gunakan build GitHub yang disetujui. Jangan menonaktifkan perlindungan perangkat. |
| Login belum aktif | Proyek Supabase dan konfigurasi publik belum tersedia; gunakan Coba tanpa akun. |
| Data tidak muncul di HP lain | Penyimpanan saat ini lokal, belum tersinkron ke server. |
| Paket APK belum terlihat | Periksa hasil build; sumber ZIP bukan APK yang dapat dipasang. |




## Contoh halaman QRIS

Pada pertandingan berbayar, Gabung membuka halaman QR terlebih dahulu. Tekan Konfirmasi pembayaran untuk mencoba pendaftaran. Data kode dan konfirmasi tersimpan lokal pada checkoutPreviews. QR tersebut adalah contoh berisi JSON test_only, bukan kode QRIS untuk menerima uang. Midtrans dan server pembayaran belum terhubung. Tampilan ini tidak diberi tulisan Simulasi; batas teknis tetap dicatat dalam CHANGES-0.4.2.md.



## Hasil room Berperingkat

Input skor kini hanya diberikan kepada kedua ketua tim terdaftar, setelah pertandingan selesai. Kedua ketua mengisi skor Tim A/Tim B; hasil disahkan jika sama. Room Kasual dan event tidak menyediakan input skor. Untuk mencoba dua ketua pada perangkat ini, buka Profil > Pengaturan > Coba input dua ketua. Ini merupakan alur lokal, bukan sinkronisasi dua akun antar-HP. Baca CARA-UJI-SKOR.md dan CHANGES-0.4.3.md.

