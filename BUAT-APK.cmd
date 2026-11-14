@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 goto missing
echo Memasang dependensi KLIK...
call flutter pub get
if errorlevel 1 goto failed
echo Memeriksa aturan kegiatan dan penyimpanan...
call dart tool/check_rules.dart
if errorlevel 1 goto failed
echo Memeriksa kode...
call flutter analyze
if errorlevel 1 goto failed
echo Memeriksa tampilan dan navigasi...
call flutter test
if errorlevel 1 goto failed
echo Membuat APK Android untuk pengujian...
call flutter build apk --debug
if errorlevel 1 goto failed
echo.
echo APK berhasil dibuat: build\app\outputs\flutter-apk\app-debug.apk
start "" "%~dp0build\app\outputs\flutter-apk"
pause
exit /b 0
:missing
echo Flutter belum ditemukan di PATH. Buka kembali VS Code setelah SDK disiapkan.
pause
exit /b 1
:failed
echo.
echo Proses berhenti karena pemeriksaan atau build gagal. Simpan pesan error di atas.
echo APK baru belum dinyatakan siap.
pause
exit /b 1
