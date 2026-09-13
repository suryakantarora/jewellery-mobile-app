# jewellery_erp

Jewellery ERP staff mobile application (Flutter 3.44, Riverpod 2, go_router, Dio).

## Building

The app ships in three flavours on both platforms — `dev`, `staging`, `prod` —
each with its own bundle id / application id and display name, so all three
can be installed side by side on one device:

| flavour   | Android application id                     | iOS bundle id                              | display name        |
|-----------|--------------------------------------------|--------------------------------------------|---------------------|
| `dev`     | `com.finotechsoftware.jewelleryapp.dev`     | `com.finotechsoftware.jewelleryapp.dev`     | Jewellery ERP Dev   |
| `staging` | `com.finotechsoftware.jewelleryapp.staging` | `com.finotechsoftware.jewelleryapp.staging` | Jewellery ERP STG   |
| `prod`    | `com.finotechsoftware.jewelleryapp`         | `com.finotechsoftware.jewelleryapp`         | Jewellery ERP       |

The flavour selects the native identity only. The backend the app talks to is a
`--dart-define`, so a `dev` build can be pointed at any server:

| define         | meaning                                            | default                          |
|----------------|----------------------------------------------------|----------------------------------|
| `API_BASE_URL` | backend origin, no path (`/api/v1` is appended)    | `http://10.0.2.2:8081` (Android emulator) / `http://localhost:8081` (iOS simulator) |
| `ENV`          | `dev`, `staging` or `prod` — picks defaults, hides developer tools in `prod` | `dev` |
| `USE_DEV_AUTH` | in-memory sign-in without a backend; ignored in `prod` | `false` |

### Run on a device

```bash
# Android — `adb reverse` lets a physical device reach localhost:8081
adb reverse tcp:8081 tcp:8081
flutter run --flavor dev     --dart-define=API_BASE_URL=http://localhost:8081
flutter run --flavor staging --dart-define=ENV=staging --dart-define=API_BASE_URL=https://staging-api.example.com
flutter run --flavor prod    --dart-define=ENV=prod    --dart-define=API_BASE_URL=https://api.example.com

# iOS — same flags; `-d` picks the simulator or device
flutter run --flavor dev -d "iPhone 16" --dart-define=API_BASE_URL=http://localhost:8081
```

### Build

```bash
# Android
flutter build apk       --flavor dev     --dart-define=API_BASE_URL=http://localhost:8081
flutter build appbundle --flavor staging --dart-define=ENV=staging --dart-define=API_BASE_URL=https://staging-api.example.com
flutter build appbundle --flavor prod    --dart-define=ENV=prod    --dart-define=API_BASE_URL=https://api.example.com

# iOS (needs a signing team; `--no-codesign` for CI archives)
flutter build ios --flavor dev     --dart-define=API_BASE_URL=http://localhost:8081
flutter build ios --flavor staging --dart-define=ENV=staging --dart-define=API_BASE_URL=https://staging-api.example.com
flutter build ipa --flavor prod    --dart-define=ENV=prod    --dart-define=API_BASE_URL=https://api.example.com
```

### How the flavours are wired

- **Android**: `productFlavors` in `android/app/build.gradle.kts`.
- **iOS**: Flutter maps `--flavor <name>` to the Xcode scheme `<name>` and the
  build configurations `Debug-<name>` / `Release-<name>` / `Profile-<name>`.
  - Schemes: `ios/Runner.xcodeproj/xcshareddata/xcschemes/{dev,staging,prod}.xcscheme`
  - Per-configuration xcconfigs: `ios/Flutter/{Debug,Release,Profile}-{dev,staging,prod}.xcconfig`
    (each includes the matching CocoaPods xcconfig, `Generated.xcconfig`, and one of the files below)
  - Per-flavour identity: `ios/Runner/Config/{Dev,Staging,Prod}.xcconfig` sets
    `PRODUCT_BUNDLE_IDENTIFIER`, `APP_DISPLAY_NAME` and `FLAVOR`.
  - `Info.plist` reads `CFBundleDisplayName` from `$(APP_DISPLAY_NAME)`; the
    unflavoured `Runner` scheme still builds and defaults to "Jewellery ERP".
  - After changing the Podfile or adding plugins run `cd ios && pod install`
    once so CocoaPods generates the `Pods-Runner.<config>-<flavor>.xcconfig`
    files the flavoured configurations include.

## Forced updates

On launch the app calls the public `GET /api/v1/app/version?platform=&current=`
endpoint (see `lib/core/settings/app_version_service.dart`). `forceUpdate: true`
replaces the whole app with a blocking "Update required" screen that opens
`storeUrl`; a newer `latest` shows a one-off dismissible prompt. A failed check
never blocks the app. **Settings → About → Check for updates** re-runs it.

## Tests

```bash
flutter analyze
flutter test
```
