## Overview

Add macOS support to `cosmos_epub` by fixing 3 crash-causing dependencies, migrating reading-progress storage from Isar to Drift/SQLite, and applying platform-adaptive UI.

**Spec**: `ai_specs/macos-support.md`

## Context

- **Structure**: flat helpers/models under `lib/`; no feature folders; layer-ish
- **State management**: global mutable variables (no Riverpod/Bloc)
- **Reference implementations**: `lib/Helpers/isar_service.dart`, `lib/Helpers/progress_singleton.dart`
- **Assumptions/Gaps**: `getBookProgress` is called synchronously in `progress_singleton.dart` line 70 (`findFirstSync`) — must audit all call sites in `show_epub.dart` when replacing with async Drift queries

## Plan

### Phase 1: Replace isar_community with Drift

- **Goal**: swap persistence layer; keep same public interface; all platforms compile

- [x] `pubspec.yaml` — remove `isar_community`, `isar_community_flutter_libs`; add `drift ^2.31.0`, `sqlite3 ^2.6.0`, `sqlite3_flutter_libs ^0.5.41`, `path ^1.8.0`; remove `isar_community_generator` from dev_deps; add `drift_dev`
- [x] `build.yaml` (create) — `drift_dev: options: generate_manager: false`
- [x] `lib/Database/connection/connection.dart` (create) — conditional export: `unsupported.dart` default, `native.dart` if `dart.library.ffi`
- [x] `lib/Database/connection/native.dart` (create) — `DatabaseConnection.delayed` using `NativeDatabase.createInBackground`; Android workaround; DB file `cosmos_epub.sqlite` in documents dir
- [x] `lib/Database/connection/unsupported.dart` (create) — throws `UnsupportedError`
- [x] `lib/Database/app_database.dart` (create) — `@DriftDatabase`; table `BookProgress` with `bookId TEXT PK`, `currentChapterIndex INTEGER DEFAULT 0`, `currentPageIndex INTEGER DEFAULT 0`; accept optional `QueryExecutor` constructor arg for test injection
- [x] Run `dart run build_runner build --delete-conflicting-outputs` → `app_database.g.dart` generated
- [x] `lib/Helpers/drift_progress_service.dart` (create) — same public API as `BookProgressSingleton`: `setCurrentChapterIndex`, `setCurrentPageIndex`, `getBookProgress`, `deleteBookProgress`, `deleteAllBooksProgress`; upsert via `insertOnConflictUpdate`; all write methods catch + return `false` on error; `getBookProgress` returns defaults on miss or error
- [x] Delete `lib/Helpers/isar_service.dart`, `lib/Helpers/progress_singleton.dart`, `lib/Model/book_progress_model.dart`, `lib/Model/book_progress_model.g.dart`
- [x] `lib/cosmos_epub.dart` — replace Isar import/init with `AppDatabase()` + `DriftProgressService`; remove `isar_community` imports
- [x] TDD: `test/drift_progress_service_test.dart` — inject `NativeDatabase.memory()` via constructor
  - RED→GREEN: `getBookProgress` returns defaults when no row exists
  - RED→GREEN: `setCurrentChapterIndex` inserts row; subsequent `getBookProgress` returns correct chapter
  - RED→GREEN: `setCurrentPageIndex` upserts (two calls → one row, latest value)
  - RED→GREEN: `deleteBookProgress` removes row; `getBookProgress` returns defaults
  - RED→GREEN: `deleteAllBooksProgress` removes all rows
  - RED→GREEN: write method returns `false` when DB closed before call
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs` && `fvm flutter analyze` && `fvm flutter test`

### Phase 2: Fix crash-causing plugins

- **Goal**: remove `fluttertoast` and `screen_brightness`; no runtime crashes on macOS

- [x] `pubspec.yaml` — remove `fluttertoast`, `screen_brightness`
- [x] `lib/Helpers/custom_toast.dart` — delete `fluttertoast` import + `Fluttertoast.showToast` block; `showToast` is a no-op (no callers with context)
- [x] `lib/show_epub.dart` — audit call sites of `CustomToast.showToast` and `setBrightness`
- [x] `lib/show_epub.dart` — wrap `setBrightness()` body, brightness `InkWell` (AppBar action) and brightness slider widget with `if (!Platform.isMacOS)` guards; added `import 'dart:io' show Platform;`
- [x] Verify: `fvm flutter analyze` (no unresolved imports)

### Phase 3: Desktop-adaptive UI

- **Goal**: macOS window renders correctly; no deprecated widget warnings

- [x] `lib/show_epub.dart` — replace `WillPopScope(onWillPop: backPress)` with `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) backPress(); })`
- [x] `lib/show_epub.dart` — `ScreenUtil.init`: branch on `Platform.isMacOS`: macOS → `designSize: const Size(1280, 800), minTextAdapt: true, splitScreenMode: false`; else keep `Size(DESIGN_WIDTH, DESIGN_HEIGHT)`
- [x] `lib/show_epub.dart` — `updateFontSettings()`: branch on `Platform.isMacOS`: macOS → `showDialog(context: context, barrierDismissible: true, builder: ...)` reusing extracted `_buildFontSettingsContent` widget; else keep `showModalBottomSheet`
- [x] Verify: `fvm flutter analyze`

### Phase 4: Example app macOS target + entitlements

- **Goal**: example runs on macOS with correct sandbox permissions

- [x] From `example/`: `fvm flutter create --platforms=macos .`
- [x] `example/macos/Runner/DebugProfile.entitlements` — add `com.apple.security.app-sandbox = true`, `com.apple.security.files.user-selected.read-only = true`, `com.apple.security.network.client = true`
- [x] `example/macos/Runner/Release.entitlements` — same three entitlements
- [ ] `fvm flutter run -d macos` from `example/` — book opens, page flip works, progress persists across restart
- [ ] `fvm flutter run -d <iOS-simulator>` — no regression
- [x] Verify: `fvm flutter analyze` (both root and example) && `fvm flutter test`

## Risks / Out of scope

- **Risks**:
  - `getBookProgress` was `findFirstSync` in Isar — all call sites in `show_epub.dart` must become `await`; missed sites cause type errors
  - `sqlite3_flutter_libs` requires macOS 10.14+; verify `example/macos/Podfile` platform target
  - `drift_dev` `VerifySelf` import in `native.dart` reference pulls in extra dev-only API — omit it
- **Out of scope**: web support, Android regression, data migration from Isar to Drift
