# SEGER App

Aplikasi mobile PLTU Run — dibangun dengan Flutter.

**Package name:** `id.co.pln.seger`  
**Versi:** 1.0.0+1

---

## Prasyarat

Pastikan sudah terinstall:

| Tool | Versi minimum |
|------|---------------|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.7+ |
| Dart SDK | ^3.7.2 |
| Android Studio / Android SDK | compileSdk 36 |
| Xcode (khusus iOS, macOS saja) | 15+ |

Cek instalasi:

```bash
flutter doctor
```

Semua item yang relevan harus berstatus ✓ sebelum build.

---

## Setup Proyek

### 1. Clone & install dependency

```bash
git clone <url-repo>
cd seger-app
flutter pub get
```

### 2. Konfigurasi environment (`.env`)

Aplikasi membaca konfigurasi API dari file `.env`. File ini **tidak** di-commit ke git.

```bash
cp .env.example .env
```

Edit `.env` sesuai environment yang dipakai:

```env
API_BASE_URL=http://31.97.107.17:3001/api/v1
```

| Variabel | Deskripsi |
|----------|-----------|
| `API_BASE_URL` | Base URL backend API (wajib) |

> Setelah mengubah `.env`, **restart aplikasi** (hot reload tidak cukup).

---

## Menjalankan Aplikasi (Development)

### Lihat perangkat yang tersedia

```bash
flutter devices
```

### Android (emulator / device fisik)

```bash
flutter run
# atau tentukan device ID:
flutter run -d <device-id>
```

### iOS Simulator (macOS)

1. Buka Simulator dari Xcode, atau:
   ```bash
   open -a Simulator
   ```
2. Jalankan aplikasi:
   ```bash
   flutter run -d <simulator-id>
   ```

**Catatan macOS:** Jika simulator iOS tidak terdeteksi, arahkan Xcode ke path yang benar:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Atau set sementara per sesi terminal:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter run -d <simulator-id>
```

### Perintah saat app berjalan

| Tombol | Fungsi |
|--------|--------|
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Quit |

---

## Build Android

### APK (debug — untuk testing)

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### APK (release)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (untuk Google Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Install langsung ke device Android

```bash
flutter install --release
```

> **Release signing:** Saat ini release build memakai debug keystore. Untuk production, konfigurasi signing di `android/app/build.gradle.kts` sebelum publish ke Play Store.

---

## Build iOS

> Hanya bisa dilakukan di **macOS** dengan Xcode terinstall.

### Debug (Simulator)

```bash
flutter run -d <simulator-id>
```

### Release (Simulator)

```bash
flutter build ios --simulator --release
```

### Release (Device fisik / App Store)

1. Buka project di Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Atur **Signing & Capabilities** (Team, Bundle ID: `id.co.pln.seger`).
3. Build via Flutter:
   ```bash
   flutter build ios --release
   ```
4. Atau archive langsung dari Xcode: **Product → Archive**.

Output build: `build/ios/iphoneos/Runner.app`

### IPA (distribusi)

Gunakan Xcode **Product → Archive → Distribute App**, atau integrasikan dengan CI/CD sesuai kebutuhan tim.

---

## Troubleshooting

### Build iOS gagal — shader compilation error

```bash
flutter clean
flutter pub get
flutter run -d <simulator-id>
```

### `.env` tidak terbaca / API error

- Pastikan file `.env` ada di root project (sejajar dengan `pubspec.yaml`).
- Pastikan `.env` terdaftar di `pubspec.yaml` bagian `assets`.
- Restart aplikasi setelah mengubah `.env`.

### Simulator iOS tidak muncul di `flutter devices`

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
flutter doctor
```

---

## Struktur Penting

```
seger-app/
├── .env                 # Konfigurasi lokal (git-ignored)
├── .env.example         # Template konfigurasi
├── lib/
│   ├── main.dart        # Entry point
│   └── helpers/
│       └── api_helper.dart  # Base URL dari .env
├── android/             # Konfigurasi Android
└── ios/                 # Konfigurasi iOS
```

---

## Powered By

KOMBALA — PLN Indonesia Power UBP Jawa Tengah 2 Adipala
