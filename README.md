# 📄 Foxit Scanner - Scanner Dokumen Profesional

Aplikasi scanner dokumen Android yang lengkap dengan fitur OCR, export PDF, dan monetisasi AdMob.

## ✨ Fitur Utama

| Fitur | Keterangan |
|-------|-----------|
| 📷 Auto Edge Detection | Deteksi tepi kertas otomatis |
| 📄 Batch Scan | Scan banyak halaman sekaligus |
| 🎨 Smart Filters | Magic, B&W, Grayscale, Original |
| 📑 Export PDF | Simpan semua halaman jadi 1 PDF |
| 🔤 OCR | Ubah gambar ke teks (Google ML Kit) |
| 📤 Share | WhatsApp, Email, Google Drive |
| 📱 AdMob | Interstitial, Native, App Open, Rewarded |

## 💰 Monetisasi AdMob

| Tipe Iklan | Unit ID | Penempatan |
|-----------|---------|-----------|
| App Open | `1410971972` | Saat buka app |
| Interstitial | `2368830428` | Setelah simpan/share PDF |
| Native | `4420278697` | Di antara daftar dokumen |
| Rewarded | `8619288869` | Unlock OCR 1 jam |

## 🚀 Cara Deploy via GitHub Actions

### Langkah 1: Fork / Upload ke GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/USERNAME/foxitscanner.git
git push -u origin main
```

### Langkah 2: Buat Keystore untuk Signing APK

```bash
keytool -genkey -v -keystore foxitscanner.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias foxitscanner
```

### Langkah 3: Encode Keystore ke Base64

```bash
# Linux/Mac:
base64 -i foxitscanner.jks | tr -d '\n'

# Windows PowerShell:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("foxitscanner.jks"))
```

### Langkah 4: Tambahkan GitHub Secrets

Buka repo GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret Name | Isi |
|------------|-----|
| `KEY_STORE_BASE64` | Output base64 dari keystore |
| `KEY_ALIAS` | Alias keystore (contoh: `foxitscanner`) |
| `KEY_PASSWORD` | Password key |
| `STORE_PASSWORD` | Password keystore |

### Langkah 5: Trigger Build

**Cara 1 - Push ke main:**
```bash
git push origin main
# GitHub Actions otomatis jalan
```

**Cara 2 - Manual:**
1. Buka tab **Actions** di GitHub
2. Pilih workflow **"Build & Release APK"**
3. Klik **"Run workflow"**

**Cara 3 - Release otomatis dengan tag:**
```bash
git tag v1.0.0
git push origin v1.0.0
# APK otomatis tersedia di Releases
```

### Langkah 6: Download APK

1. Buka tab **Actions** → pilih workflow yang sukses
2. Scroll ke bawah, lihat **Artifacts**
3. Download **Foxit Scanner-Release-APK**

## 📁 Struktur Project

```
foxitscanner/
├── lib/
│   ├── main.dart                 # Entry point + App Open Ad
│   ├── screens/
│   │   ├── home_screen.dart      # Daftar dokumen + Native Ad
│   │   ├── scan_screen.dart      # Kamera + Edge Detection
│   │   ├── preview_screen.dart   # Filter + Simpan PDF
│   │   └── document_detail_screen.dart  # Detail + OCR
│   ├── services/
│   │   ├── ad_service.dart       # Semua AdMob
│   │   ├── scanner_service.dart  # Scan + PDF
│   │   ├── ocr_service.dart      # Google ML Kit OCR
│   │   ├── ocr_unlock_service.dart # Timer OCR reward
│   │   └── database_service.dart # SQLite
│   ├── models/
│   │   └── document_model.dart
│   └── utils/
│       ├── ad_constants.dart     # AdMob IDs
│       └── app_theme.dart
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml   # AdMob App ID
├── .github/
│   └── workflows/
│       └── build_apk.yml         # CI/CD GitHub Actions
└── pubspec.yaml
```

## ⚙️ Persyaratan

- Flutter 3.22.0+
- Dart 3.0.0+
- Android minSdk 23 (Android 6.0+)
- Google AdMob account

## 🔧 Run Lokal

```bash
flutter pub get
flutter run
```

## 📝 Lisensi

MIT License - bebas digunakan untuk komersial.
