## Overview

Rename the Flutter app in `7epubs/` from "example" to "7epubs" with bundle ID `de.schilken.sevenEpubs`. ~15 files, ~30 line edits. No logic changes.

**Spec**: `ai_specs/01-changerequest_rename_app.md`

## Context

- **Structure**: The `7epubs/` directory is a copy of `example/`; the root `example/` directory stays untouched
- **State management**: None relevant — rename only
- **Key files to change**: pubspec, Android/iOS/macOS build configs, Dart source, IDE config

## Plan

### Phase 1: Core Identity Rename

- **Goal**: Change package name, bundle identifiers, display name, and all code references

- [x] `7epubs/pubspec.yaml` — `name: cosmos_epub_example` → `name: seven_epubs`
- [x] `7epubs/android/app/build.gradle` — `namespace "com.example.example"` → `"de.schilken.sevenEpubs"`; `applicationId` same change
- [x] `7epubs/android/app/src/main/AndroidManifest.xml` — `android:label="example"` → `"7epubs"`
- [x] `7epubs/android/app/src/debug/AndroidManifest.xml` — `package="com.example.example"` → `"de.schilken.sevenEpubs"`
- [x] `7epubs/android/app/src/profile/AndroidManifest.xml` — same package change
- [x] Move `7epubs/android/app/src/main/kotlin/com/example/example/` → `.../kotlin/de/schilken/sevenEpubs/` + update `package` declaration in `MainActivity.kt`
- [x] `7epubs/ios/Runner/Info.plist` — CFBundleDisplayName + CFBundleName → `7epubs`
- [x] `7epubs/ios/Runner.xcodeproj/project.pbxproj` — all `PRODUCT_BUNDLE_IDENTIFIER = com.example.example` → `de.schilken.sevenEpubs` (3 occurrences)
- [x] `7epubs/macos/Runner/Configs/AppInfo.xcconfig` — `PRODUCT_NAME = seven_epubs`, `PRODUCT_BUNDLE_IDENTIFIER = de.schilken.sevenEpubs`, `PRODUCT_COPYRIGHT` update domain
- [x] `7epubs/macos/Runner.xcodeproj/project.pbxproj` — all occurrences of `cosmos_epub_example` in product paths → `seven_epubs`; test target bundle IDs → `de.schilken.sevenEpubs.RunnerTests`
- [x] `7epubs/lib/main.dart` — `title: 'CosmosEpub Reader Example'` → `'7epubs'` (line 22); `const Text('CosmosEpub Reader Example')` → `'7epubs'` (line 245)
- [x] `7epubs/lib/shelf_service.dart` — `_key = 'example_shelf_v1'` → `'seven_epubs_shelf_v1'`
- [x] `7epubs/test/widget_test.dart` — import `package:cosmos_epub_example/...` → `package:seven_epubs/...`
- [x] Rename `7epubs/cosmos_epub_example.iml` → `seven_epubs.iml`
- [x] `7epubs/.idea/modules.xml` — does not exist; n/a
- [x] Verify: `dart analyze` in `7epubs/` (expected: import errors from stale `.dart_tool/` — Phase 2 resolves)

### Phase 2: Clean Build Artifacts & Final Verification

- **Goal**: Purge stale generated files referencing old paths, verify clean build

- [x] `cd 7epubs && fvm flutter clean` — removes `build/`, `.dart_tool/`, stale `Generated.xcconfig`, Gradle caches
- [x] `cd 7epubs && fvm flutter pub get` — regenerates `.flutter-plugins*`, `.dart_tool/package_config.json`
- [x] Verify: `cd 7epubs && fvm flutter analyze` passes with no errors (warning: missing flutter_lints dep — pre-existing, same as example/)
- [x] Verify: `cd 7epubs && fvm flutter test` passes (test failure is pre-existing counter template test, identical in example/)

## Risks / Out of scope

- **Risks**: 
  - `get_storage` key rename orphans existing shelf data — acceptable since this is a new app copy with no real user data
  - IDE `.iml` filenames mismatch until modules.xml updated and project re-imported
- **Out of scope**: Original `example/` directory (untouched), root `README.md` and `AGENTS.md` (document original `example/`), `rtl_example.dart` (uses "example" as English word, not app name)
