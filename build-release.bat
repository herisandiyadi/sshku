@echo off
REM ============================================================
REM  SSHKU - Build APK Release
REM  Jalankan dari root project (double-click atau via terminal).
REM  Opsi:  build-release.bat            -> build biasa
REM         build-release.bat clean      -> flutter clean dulu
REM         build-release.bat split      -> APK per-ABI (ukuran lebih kecil)
REM ============================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ============================================
echo   SSHKU - Build APK Release
echo ============================================
echo.

REM --- Pastikan Flutter tersedia ---
where flutter >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Flutter tidak ditemukan di PATH.
    echo         Pasang Flutter dan tambahkan ke PATH lalu coba lagi.
    exit /b 1
)

REM --- Peringatan signing ---
if exist "android\keystore.properties" (
    echo [INFO] keystore.properties ditemukan -> APK akan di-sign RELEASE.
) else (
    echo [WARN] android\keystore.properties TIDAK ada.
    echo        APK akan di-sign dengan DEBUG key ^(tidak untuk distribusi Play Store^).
)
echo.

REM --- Optional flutter clean ---
if /i "%~1"=="clean" (
    echo [STEP] flutter clean...
    call flutter clean || goto :failed
)

echo [STEP] flutter pub get...
call flutter pub get || goto :failed

echo.
echo [STEP] Build APK release...
if /i "%~1"=="split" (
    call flutter build apk --release --split-per-abi || goto :failed
) else (
    call flutter build apk --release || goto :failed
)

echo.
echo ============================================
echo   BUILD SELESAI
echo ============================================
echo Output:
for %%F in ("build\app\outputs\flutter-apk\*.apk") do (
    echo   %%~fF  ^(%%~zF bytes^)
)
echo.
endlocal
exit /b 0

:failed
echo.
echo [ERROR] Build gagal. Lihat pesan di atas.
endlocal
exit /b 1
