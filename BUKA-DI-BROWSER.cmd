@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter belum ditemukan. Buka proyek dari VS Code dan periksa pengaturan Flutter SDK.
  pause
  exit /b 1
)
echo Menyiapkan KLIK untuk browser...
call flutter pub get
if errorlevel 1 goto gagal
echo.
echo Chrome akan terbuka. Biarkan jendela ini tetap berjalan.
echo Setelah mengubah kode, tekan r di jendela ini untuk memperbarui tampilan.
echo Tekan q untuk menghentikan pratinjau.
echo.
call flutter run -d chrome --web-hostname=127.0.0.1 --web-port=7357
if errorlevel 1 goto gagal
exit /b 0
:gagal
echo.
echo Pratinjau belum berhasil dimulai. Periksa pesan kesalahan di atas.
pause
exit /b 1
