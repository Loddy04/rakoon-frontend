# Rakoon Frontend

Aplikasi mobile berbasis Flutter untuk platform **Rakoon** (Rak Pintar & Komparasi Harga Belanja Cerdas). Mendukung pemindaian rak belanja via kamera (*smart shelf scanning*), komparasi harga antar-gerai ritel dengan visual peta OpenStreetMap, asisten alokasi anggaran belanja harian, serta portal dasbor mitra pemilik toko (*merchant dashboard*).

## Cara Menjalankan

1. **Instalasi Dependensi:**
   ```bash
   flutter pub get
   ```

2. **Konfigurasi Environment:**
   Salin berkas template dan sesuaikan nilainya:
   ```bash
   cp .env.example .env
   ```

3. **Jalankan Aplikasi:**
   > **PENTING:** Seluruh eksekusi aplikasi **WAJIB** menyertakan parameter `--dart-define-from-file=.env`:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

4. **Pengujian & Analisis:**
   ```bash
   flutter analyze
   flutter test
   ```

Panduan setup koneksi emulator/perangkat fisik dan konfigurasi detail mengacu pada [SETUP.md](../SETUP.md) di root proyek.
