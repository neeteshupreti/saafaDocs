# SafaaDocs

> **On-device document scanner,OCR, and PDF export for Android.**

A Flutter application that turns your phone into a document scanner. Capture
pages with the camera, detect edges, recognise text (OCR), crop, apply filters,
export to **PDF** / **JPEG**, and share or search your documents — all processed
**locally on device**, no cloud required.

| Platform | Status |
| -------- | ------ |
| Android  | ✅ Fully supported (ML Kit, AdMob, share sheet) |
| Web      | ✅ Supported (gallery picker, stub OCR, browser download) |

---

## ✨ Features

- **Scan** — live camera document scanner powered by
  `google_mlkit_document_scanner` with automatic edge detection.
- **OCR** — extract editable text with `google_mlkit_text_recognition`.
- **Edit** — crop, rotate, reorder pages, and apply image filters.
- **Export** — save documents as multi-page **PDF** or individual **JPEG**
  files.
- **Share** — send documents to any app via `share_plus`.
- **Search** — full-text search across all saved documents.
- **Folders** — organise documents into custom folders.
- **Monetization** — AdMob rewarded-video ads for watermark-free exports.

### Feature matrix

| Feature              | Android                          | Web                                   |
| -------------------- | --------------------------------- | ------------------------------------- |
| Scan documents       | ML Kit live camera scanner        | `image_picker` gallery multi-select   |
| View & edit pages    | Full editor (crop, filters, …)     | Full editor                           |
| OCR                  | ML Kit Text Recognition (Latin)   | No-op stub + UI message               |
| Export to PDF / JPEG | Share sheet                       | Browser download dialog             |
| Watermark removal    | AdMob rewarded video              | Auto-granted (no real ads on web)     |
| Search documents     | Yes                               | Yes                                   |
| Folders              | Yes                               | Yes                                   |

---

## 📱 Screenshots

<!-- Add screenshots to `screenshots/` and reference them here, e.g. -->
<!-- <img src="screenshots/app-icon.png" alt="App icon" width="80"/> -->
<!-- <img src="screenshots/home.png" alt="Home screen" width="240"/> -->
<!-- <img src="screenshots/editor.png" alt="Editor" width="240"/> -->

---

## 🚀 Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **3.47.1** (or newer,
  stable channel)
- Android SDK with **AGP 9.1.0** and **Kotlin 2.4.0** (configured via
  `android/settings.gradle.kts`)
- A physical Android device or an emulator (API ≥ 21)

### Install & run

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run on a connected device
flutter run -d U86DFA6XRCGQW4JJ

# Or run on any attached device / emulator
flutter run
```

---

## 📦 Building an APK

### Debug build

```bash
flutter build apk --debug
# or per-ABI:
flutter build apk --debug --split-per-abi
```

### Release build (recommended)

The app is configured to build a release APK split per ABI. This keeps each APK
small and is the recommended distribution format.

```bash
flutter build apk --release --split-per-abi
```

Built APKs are placed in `build/app/outputs/flutter-apk/`.

### Release checklist

- **AdMob** — replace test IDs with your own:
  - `android/app/src/main/AndroidManifest.xml` —
    `com.google.android.gms.ads.APPLICATION_ID`
  - `lib/core/ad_manager.dart` — ad unit IDs
- **App ID / package name** — `android/app/build.gradle.kts`
  (`applicationId`), currently `com.example.docscan_pro`.
- **Min SDK** — set to `23` in `android/app/build.gradle.kts`
  (`minSdk = flutter.minSdkVersion` → ensure the value is `23`).

> 💡 Fonts ([Inter](https://rsms.me/inter/)) are fetched by `google_fonts` at
> first run. To support fully offline first launches, bundle the fonts under
> `assets/fonts/` and pin them in `pubspec.yaml`.

---

## 📲 Download

A pre-built release APK is available in the
[`v1.0.0` Release](https://github.com/neeteshupreti/saafaDocs/releases/tag/v1.0.0)
section. Download the APK for your device's architecture and install it.

| Architecture | File                          | Direct link |
| ------------ | ----------------------------- | ----------- |
| arm64-v8a    | `app-arm64-v8a-release.apk`   | [download](https://github.com/neeteshupreti/saafaDocs/releases/download/v1.0.0/app-arm64-v8a-release.apk) |
| armeabi-v7a  | `app-armeabi-v7a-release.apk` | [download](https://github.com/neeteshupreti/saafaDocs/releases/download/v1.0.0/app-armeabi-v7a-release.apk) |
| x86_64       | `app-x86_64-release.apk`      | [download](https://github.com/neeteshupreti/saafaDocs/releases/download/v1.0.0/app-x86_64-release.apk) |

> 💡 Not sure which one you need? **arm64-v8a** is the most common for modern
> phones. See [this guide](https://github.com/neeteshupreti/saafaDocs/releases)
> for help identifying your device's architecture.

The latest source code is always on the `main` branch; release tags are used for
stable builds.
| armeabi-v7a  | `app-armeabi-v7a-release.apk` |
| x86_64       | `app-x86_64-release.apk`      |

> Universal single-APK builds are also published when needed.

---

## 🌐 Building for the web

```bash
flutter build web              # builds to build/web/

# Or with hot-reload for development:
flutter serve

# Serve the production build locally:
python3 -m http.server 8080 --directory build/web
```

Then open `http://localhost:8080`.

---

## 📁 Project structure

```
lib/
├── core/                # Storage, ad-manager, theme, palette
├── features/
│   ├── dashboard/       # Home / document grid / list
│   ├── document_viewer/ # Reader, editor, OCR, export sheet
│   ├── monetization/    # AdMob rewarded ads, paywall
│   └── scanner/         # Camera scanner, image engine
├── main.dart            # Entry point
└── ...                  # Conditional imports separate mobile & web codepaths

android/                 # Kotlin DSL Gradle build
assets/
└── safaaDocs.jpg        # App logo asset
test/
└── widget_test.dart
web/                     # Web build configuration
```

The shared `lib/` codebase uses **conditional imports / exports** so that
mobile-only packages (`google_mlkit_document_scanner`,
`google_mlkit_text_recognition`, `google_mobile_ads`) are never referenced in
the web compilation unit.

---

## 🛠️ Android notes

- Built with the **Kotlin DSL** (`build.gradle.kts`) and **Built-in Kotlin**
  (`android.builtInKotlin = true` in `android/gradle.properties`).
- Uses the **Flutter Gradle Plugin** (`dev.flutter.flutter-gradle-plugin`)
  alongside **AGP 9.1.0** and **Kotlin 2.4.0**.
- `share_plus` 13.x supports Built-in Kotlin; no manual KGP classpath is
  applied by any plugin's `build.gradle`.

---

## 📄 License

This project is provided as-is for educational and personal use. See the
`LICENSE` file (if present) for details.
