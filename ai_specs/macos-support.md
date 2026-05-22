<goal>
Make the `cosmos_epub` Flutter package run correctly on macOS desktop while keeping iOS (and Android) fully functional. A macOS host app must be able to call `CosmosEpub.initialize()` and open any EPUB without crashing, with a desktop-appropriate UI. No existing iOS/Android behavior changes.
</goal>

<background>
Flutter package at the repo root. Key files:

- `pubspec.yaml` — dependencies
- `lib/cosmos_epub.dart` — public API, `initialize()`, `openLocalBook()`, `openURLBook()`
- `lib/show_epub.dart` — `ShowEpub` StatefulWidget (894 lines); contains brightness, WillPopScope, bottom sheet, screenutil init
- `lib/Helpers/isar_service.dart` — opens Isar database
- `lib/Helpers/progress_singleton.dart` — CRUD over `BookProgressModel` via Isar
- `lib/Model/book_progress_model.dart` — Isar `@collection` with `bookId`, `currentChapterIndex`, `currentPageIndex`
- `lib/Model/book_progress_model.g.dart` — generated; do not edit manually
- `lib/Helpers/custom_toast.dart` — wraps `Fluttertoast`; already has a pure-Flutter `Snack()` fallback
- `example/` — example app; must gain a macOS runner

Platform-guard convention throughout: `import 'dart:io' show Platform;` then `if (Platform.isMacOS) { … }`.

Web is explicitly out of scope (AGENTS.md).
</background>

<requirements>
**Functional**

1. Replace `isar_community` + `isar_community_flutter_libs` with `drift` + `sqlite3` + `sqlite3_flutter_libs` for reading-progress persistence. No migration of existing Isar data — fresh start is acceptable.
2. Replace `isar_community_generator` dev-dependency with `drift_dev` and regenerate all affected code.
3. Delete `lib/Model/book_progress_model.g.dart` and `lib/Model/book_progress_model.dart` (Isar collection). Recreate progress persistence as a Drift table.
4. Create `lib/Database/` folder containing:
   - `connection/connection.dart` — conditional export (native vs unsupported; no web)
   - `connection/native.dart` — `NativeDatabase` via `path_provider` + `path`; include Android workaround; name DB file `cosmos_epub.sqlite`
   - `connection/unsupported.dart` — throws `UnsupportedError`
   - `app_database.dart` — `@DriftDatabase` with a `BookProgress` table: columns `bookId TEXT NOT NULL`, `currentChapterIndex INTEGER NOT NULL DEFAULT 0`, `currentPageIndex INTEGER NOT NULL DEFAULT 0`; `bookId` is the primary key
   - `app_database.g.dart` — generated; do not edit manually
5. Create `lib/Helpers/drift_progress_service.dart` as a drop-in replacement for `BookProgressSingleton` with the same public interface: `setCurrentChapterIndex`, `setCurrentPageIndex`, `getBookProgress`, `deleteBookProgress`, `deleteAllBooksProgress`.
6. Update `lib/cosmos_epub.dart`: remove Isar imports; call `AppDatabase()` instead; store the `DriftProgressService` instance in the `bookProgress` global.
7. Remove `fluttertoast` from `pubspec.yaml` and from `lib/Helpers/custom_toast.dart`. The existing `Snack()` function is the sole toast implementation.
8. Remove `screen_brightness` from `pubspec.yaml`. In `lib/show_epub.dart`, wrap all brightness-related code behind `if (!Platform.isMacOS)`:
   - The brightness `IconButton` in the AppBar actions (line ~847)
   - The `setScreenBrightness()` call (line ~207)
   - The brightness section in the settings bottom sheet (line ~636–692)
9. In `lib/show_epub.dart`, replace `WillPopScope(onWillPop: backPress)` with `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) backPress(); })`.
10. In `lib/show_epub.dart`, adapt `ScreenUtil.init(...)` call:
    - On macOS: `designSize: const Size(1280, 800), minTextAdapt: true, splitScreenMode: false`
    - On iOS/Android: keep `designSize: const Size(DESIGN_WIDTH, DESIGN_HEIGHT)` (existing)
    - Detect via `Platform.isMacOS`
11. Replace `showModalBottomSheet` (the font/settings panel at line ~214 in `show_epub.dart`) with a platform-adaptive helper: on macOS use `showDialog` centered with `barrierDismissible: true`; on iOS/Android keep `showModalBottomSheet`.
12. Add `build.yaml` at repo root (or update if present) with `drift_dev: options: generate_manager: false`.
13. Run `dart run build_runner build --delete-conflicting-outputs` after all code changes.
14. Add a macOS runner to the example app: run `fvm flutter create --platforms=macos .` inside `example/`.
15. Add macOS entitlements to `example/macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:
    - `com.apple.security.app-sandbox = true`
    - `com.apple.security.files.user-selected.read-only = true`
    - `com.apple.security.network.client = true` (for `openURLBook()`)

**Error Handling**

16. `DriftProgressService.getBookProgress` must return a default `BookProgressModel(currentChapterIndex: 0, currentPageIndex: 0)` on any database error (match existing Isar behavior).
17. All write methods in `DriftProgressService` must catch exceptions and return `false` on failure (match existing Isar behavior).

**Edge Cases**

18. On first launch (empty DB), `getBookProgress` returns defaults — never null.
19. `setCurrentChapterIndex` / `setCurrentPageIndex` must upsert: insert if `bookId` absent, update if present.
</requirements>

<implementation>
**Files to modify:**
- `pubspec.yaml` — remove `isar_community`, `isar_community_flutter_libs`, `fluttertoast`, `screen_brightness`; add `drift ^2.31.0`, `sqlite3 ^2.6.0`, `sqlite3_flutter_libs ^0.5.41`, `path ^1.8.0`; move `isar_community_generator` out, add `drift_dev` to dev_dependencies
- `lib/cosmos_epub.dart` — replace Isar init with `AppDatabase()`, wire `DriftProgressService`
- `lib/show_epub.dart` — brightness guard, WillPopScope → PopScope, screenutil platform designSize, adaptive settings modal
- `lib/Helpers/custom_toast.dart` — remove `fluttertoast` import and `Fluttertoast.showToast` call
- `lib/Helpers/isar_service.dart` — delete (replaced by drift DB)
- `lib/Helpers/progress_singleton.dart` — delete (replaced by `DriftProgressService`)
- `lib/Model/book_progress_model.dart` — delete (Isar collection)
- `lib/Model/book_progress_model.g.dart` — delete (generated Isar adapter)

**Files to create:**
- `lib/Database/connection/connection.dart`
- `lib/Database/connection/native.dart`
- `lib/Database/connection/unsupported.dart`
- `lib/Database/app_database.dart`
- `lib/Helpers/drift_progress_service.dart`
- `build.yaml`

**Patterns:**
- Use `dart:io Platform` checks (not `defaultTargetPlatform`) throughout
- Drift upsert: use `into(bookProgress).insertOnConflictUpdate(...)` (Drift's built-in upsert on primary key conflict)
- `getBookProgress` must be async (Drift queries are always async); update all call sites in `progress_singleton` replacement accordingly; check `show_epub.dart` and `cosmos_epub.dart` for sync call sites and make them `await`

**What to avoid:**
- Do not target web — omit `web.dart` connection file; `unsupported.dart` is the non-native fallback
- Do not include `drift_dev` migration validation (`VerifySelf`) — adds friction without benefit here
- Do not use `isar_community` anywhere in new code
</implementation>

<validation>
**Manual verification:**
1. `fvm flutter pub get` — no resolution errors
2. `dart run build_runner build --delete-conflicting-outputs` — completes cleanly, `app_database.g.dart` generated
3. `fvm flutter analyze` — zero new errors or warnings (ignoring pre-existing ones)
4. In `example/`, `fvm flutter run -d macos` — app launches, opens `book.epub`, reader renders, page flip works
5. In `example/`, `fvm flutter run -d <iOS-simulator>` — same result confirming no regression
6. On macOS: open a book, flip to page 3, close, reopen — reader resumes at page 3 (drift persistence works)
7. On macOS: brightness AppBar icon is absent; settings modal opens as a centered dialog
8. On iOS: brightness icon visible; settings opens as a bottom sheet

**Automated — no test suite exists today; add the following unit tests:**

Location: `test/drift_progress_service_test.dart`

Use an in-memory Drift database (`NativeDatabase.memory()`) as the test seam — inject it via a constructor parameter on `AppDatabase` (add `AppDatabase([QueryExecutor? e])` overload that accepts an optional executor for testing).

Test slices (behavior-first order):
1. RED → GREEN: `getBookProgress` returns defaults when no row exists for a `bookId`
2. RED → GREEN: `setCurrentChapterIndex` inserts a row when none exists; subsequent `getBookProgress` returns correct chapter index
3. RED → GREEN: `setCurrentPageIndex` upserts — calling it twice for the same `bookId` results in one row with the latest page index
4. RED → GREEN: `deleteBookProgress` removes the row; subsequent `getBookProgress` returns defaults
5. RED → GREEN: `deleteAllBooksProgress` removes all rows
6. RED → GREEN: any method returns `false` / defaults when the executor throws (simulate by closing the DB before calling)

Testability seam: `AppDatabase` must accept an optional `QueryExecutor` in its constructor so tests pass `NativeDatabase.memory()` without `path_provider`.
</validation>

<done_when>
- `fvm flutter analyze` passes with no new issues
- `dart run build_runner build` completes without errors and `app_database.g.dart` is up to date
- Example app runs on macOS: book opens, pagination works, progress persists across restarts
- Example app still runs on iOS simulator with identical reading behaviour
- No references to `isar_community`, `fluttertoast`, or `screen_brightness` remain in `lib/`
- All 6 unit tests in `test/drift_progress_service_test.dart` pass
- `example/macos/` exists with correct entitlements files
</done_when>
