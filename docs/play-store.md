# Panduan rilis Google Play

Semua bahan listing AutoCare sudah ada di repo. Dokumen ini memetakan tiap isian Play Console ke filenya, berisi jawaban untuk bagian *App content*, dan langkah rilis dari upload key sampai produksi.

| Isian | Nilai / file |
|---|---|
| Package name | `com.autocare.autocare` (permanen setelah upload pertama) |
| Versi | `pubspec.yaml` → `version: 1.0.0+1` (versionName 1.0.0, versionCode 1) |
| Target / min SDK | API 36 / API 24 (Android 7.0), mengikuti default Flutter |
| Kategori | Aplikasi → **Auto & Vehicles** (Otomotif & Kendaraan) |
| Harga | Gratis, tanpa iklan, tanpa pembelian dalam aplikasi |
| Bahasa default | Indonesia (`id`), terjemahan Inggris (`en-US`) |
| Email kontak | `octarezaruly@gmail.com` |
| Situs | `https://rulyoctareza.github.io/OBD-Scanner/` |
| Kebijakan privasi | `https://rulyoctareza.github.io/OBD-Scanner/privacy/` |

## 1. Sebelum upload pertama

Hal yang harus selesai dulu:

- [ ] **Izin di kebijakan privasi cocok dengan APK rilis final.** Jalankan `aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep uses-permission`, lalu samakan bagian "Izin yang dipakai" di `docs/privacy/index.html`.
- [ ] **Screenshot diambil ulang** bila UI berubah (task ui-ux-overhaul), lihat [Memperbarui aset listing](#7-memperbarui-aset-listing).
- [ ] **Upload key dibuat dan dicadangkan** (langkah 2).

## 2. Upload key dan build AAB

Play memakai *Play App Signing*: Google menyimpan kunci penandatanganan aplikasi, dan kamu menandatangani setiap upload dengan **upload key** milikmu sendiri.

1. Buat keystore sekali saja, simpan **di luar repo**, dan cadangkan beserta password-nya. Kehilangan upload key berarti harus mengajukan reset ke Google.

   ```bash
   keytool -genkey -v -keystore ~/keys/autocare-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Buat `android/key.properties`. File ini sudah di-ignore oleh `android/.gitignore` dan tidak boleh di-commit.

   ```properties
   storePassword=<password keystore>
   keyPassword=<password key>
   keyAlias=upload
   storeFile=/Users/<nama-user>/keys/autocare-upload.jks
   ```

   `storeFile` sebaiknya path absolut. Path relatif dihitung dari folder `android/app/`.

3. Build:

   ```bash
   tool/build_verified.sh appbundle --release
   # hasil: build/app/outputs/bundle/release/app-release.aab
   # baris terakhir: SRC_REV=<commit>-<waktu>
   ```

   > **Kenapa tidak `flutter build` biasa?** Path proyek berisi spasi (`OBD Scanner`), dan plugin Gradle Flutter salah membaca daftar file Dart di depfile. Akibatnya kompilasi Dart bisa dianggap *up-to-date* walau kode berubah, sehingga AAB memakai `libapp.so` lama. `tool/build_verified.sh` memaksa kompilasi dengan stempel `SRC_REV` unik (commit + waktu), lalu gagal kalau stempel itu tidak ada di setiap `libapp.so` dalam AAB. Saat app dibuka, logcat mencetak `AutoCare SRC_REV=…`, jadi build yang sedang berjalan di HP bisa dicocokkan. Commit dulu semua perubahan: stempel bertanda `-dirty` berarti AAB dibuat dari kode yang belum di-commit.

   Tanpa `key.properties`, build rilis ditandatangani debug key. Build seperti itu bisa dipasang lokal, tetapi ditolak Play. Cek tanda tangannya dengan:

   ```bash
   keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
   ```

Setiap upload berikutnya wajib menaikkan angka setelah `+` di `pubspec.yaml` (versionCode).

## 3. Store listing (Grow → Store presence → Main store listing)

Teks dan gambar mengikuti struktur [fastlane supply](https://docs.fastlane.tools/actions/supply/), jadi bisa ditempel manual atau diunggah dengan `fastlane supply`.

| Isian Play | Bahasa Indonesia (`id`) | English (`en-US`) |
|---|---|---|
| App name (≤ 30) | [`title.txt`](../fastlane/metadata/android/id/title.txt) | [`title.txt`](../fastlane/metadata/android/en-US/title.txt) |
| Short description (≤ 80) | [`short_description.txt`](../fastlane/metadata/android/id/short_description.txt) | [`short_description.txt`](../fastlane/metadata/android/en-US/short_description.txt) |
| Full description (≤ 4000) | [`full_description.txt`](../fastlane/metadata/android/id/full_description.txt) | [`full_description.txt`](../fastlane/metadata/android/en-US/full_description.txt) |
| App icon 512×512 | [`images/icon.png`](../fastlane/metadata/android/id/images/icon.png) | sama |
| Feature graphic 1024×500 | [`images/featureGraphic.png`](../fastlane/metadata/android/id/images/featureGraphic.png) | [`images/featureGraphic.png`](../fastlane/metadata/android/en-US/images/featureGraphic.png) |
| Phone screenshots (8 × 1080×1920) | [`images/phoneScreenshots/`](../fastlane/metadata/android/id/images/phoneScreenshots/) | [`images/phoneScreenshots/`](../fastlane/metadata/android/en-US/images/phoneScreenshots/) |
| Release notes (≤ 500) | [`changelogs/1.txt`](../fastlane/metadata/android/id/changelogs/1.txt) | [`changelogs/1.txt`](../fastlane/metadata/android/en-US/changelogs/1.txt) |

Terjemahan Inggris ditambahkan lewat *Manage translations → Add your own translation text*. Screenshot tablet tidak wajib, jadi dilewati.

## 4. App content (Policy and programs → App content)

### Privacy policy
`https://rulyoctareza.github.io/OBD-Scanner/privacy/`

### App access
Pilih **All or some functionality is restricted**, lalu tambahkan instruksi (tanpa username/password):

> No account or login is needed. Most features read data from a Bluetooth ELM327 OBD-II adapter plugged into a car. To review every screen without a car, turn on simulator mode: tap "Coba dengan simulator" on the first screen, or open the "Pengaturan" tab, section "Simulator", switch "Mode simulator". Its switches simulate an overheating engine, a weak battery and a Check Engine trouble code (P0138). Trouble-code scanning ("Diagnostik" tab, "Pindai") also works in simulator mode. Tabs: Beranda (health score), Live (gauges and sensors), Diagnostik (scan and code dictionary), Riwayat (trips, fuel, service), Pengaturan.

### Ads
**No, my app does not contain ads.**

### Content rating (kuesioner IARC)
- Kategori: *All other app types* (utility).
- Kekerasan, konten seksual, bahasa kasar, zat terlarang, judi, humor kasar: **No** semua.
- Pengguna dapat berinteraksi atau bertukar konten: **No**. Membagikan lokasi pengguna: **No**. Pembelian digital: **No**. Akses internet tak terbatas (browser): **No**.
- Hasil yang diharapkan: semua umur (IARC 3+ / Everyone).

### Target audience and content
- Kelompok umur: **18 and over** saja.
- Bisa menarik perhatian anak secara tidak sengaja: **No**.

### Data safety
- *Does your app collect or share any of the required user data types?* → **No**.
- Alasannya: AutoCare tidak punya izin INTERNET, tanpa SDK analitik/iklan, dan semua data (telemetri, VIN, perjalanan, BBM, servis, pengaturan, alamat adapter Bluetooth) hanya disimpan di database lokal. Menurut definisi Play, data yang tidak dikirim keluar dari perangkat tidak termasuk "dikumpulkan".
- Periksa ulang jawaban ini bila suatu saat ada library jaringan, crash reporting, atau analitik yang ditambahkan.

### Foreground service permissions
Deklarasikan tipe **Connected device** (`FOREGROUND_SERVICE_CONNECTED_DEVICE`).

- *Deskripsi penggunaan (EN):*
  > AutoCare reads live engine data from a Bluetooth Classic ELM327 OBD-II adapter that the user pairs and connects. While the adapter is connected, a connectedDevice foreground service keeps the Bluetooth RFCOMM link and the data polling alive when the user switches to another app (for example navigation while driving), and shows an ongoing notification. It starts only after the user connects an adapter and stops as soon as the adapter disconnects or the user taps "Putuskan" (Disconnect).
- *Dampak bila ditunda/dihentikan sistem (EN):*
  > The Bluetooth link to the adapter would drop when the app goes to the background, so live readings and trip recording would stop in the middle of a drive.
- *Video* (unggah ke YouTube sebagai *unlisted* atau Google Drive yang bisa diakses publik), rekam dengan adapter asli. Mode simulator tidak menyalakan foreground service.
  1. Buka AutoCare, ketuk **Hubungkan**, pilih adapter, tunggu status terhubung.
  2. Tarik panel notifikasi: notifikasi AutoCare terlihat.
  3. Tekan Home, buka Google Maps, tunggu beberapa detik.
  4. Kembali ke AutoCare: data sensor tetap berjalan.
  5. Ketuk **Putuskan**: notifikasi hilang.

### Lainnya
| Bagian | Jawaban |
|---|---|
| Advertising ID | Tidak memakai advertising ID |
| News apps | Bukan aplikasi berita |
| Government apps | Bukan aplikasi pemerintah |
| Financial features | Tidak ada fitur keuangan |
| Health apps | Tidak ada fitur kesehatan (skor "kesehatan" adalah kondisi mobil, bukan kesehatan manusia) |

## 5. Pengujian dan rilis

1. **Internal testing** (opsional, tercepat): unggah AAB, tambahkan email penguji, pasang dari tautan opt-in.
2. **Closed testing** (wajib untuk akun developer **personal** yang dibuat setelah 13 November 2023): minimal **12 penguji** harus ikut (opt-in) secara terus-menerus selama **14 hari** sebelum kamu bisa mengajukan akses produksi. Lihat [Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465).
3. **Production**: ajukan akses produksi, pilih negara (disarankan mulai dari Indonesia), tempel catatan rilis dari `changelogs/<versionCode>.txt`, lalu kirim untuk ditinjau.

## 6. Checklist upload

- [ ] Bagian 1 beres semua.
- [ ] `flutter analyze` dan `flutter test` hijau.
- [ ] AAB dibuat dengan `tool/build_verified.sh appbundle --release` dari tree yang sudah di-commit (stempel tanpa `-dirty`) dan ditandatangani upload key (`keytool -printcert -jarfile …`).
- [ ] APK rilis dicoba di HP dengan install bersih: app terbuka, mode simulator berjalan, daftar Bluetooth tampil, terhubung ke adapter dan notifikasi muncul.
- [ ] Listing `id` dan `en-US` lengkap: teks, ikon, feature graphic, 8 screenshot.
- [ ] Semua bagian App content berstatus selesai.

## 7. Memperbarui aset listing

Screenshot dan grafis dibuat ulang dengan dua skrip di [`tool/store_assets/`](../tool/store_assets/README.md): `capture.sh` mengambil screenshot mentah dari HP dengan mode simulator, lalu `render.py` membuat semua screenshot berbingkai, feature graphic, ikon, social preview GitHub, dan potongan untuk README.

## 8. Aset GitHub yang diunggah manual

GitHub tidak punya API untuk *social preview*. Unggah [`docs/assets/social-preview.png`](assets/social-preview.png) (1280×640) lewat **Settings → General → Social preview → Edit → Upload an image**.
