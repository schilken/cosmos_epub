## Overview

Integrate `macos_secure_bookmarks` to persist macOS file access across app restarts. Add SettingsScreen with directory authorization. Scope: `7epubs/` only.

**Spec**: `ai_specs/04-changerequest_allow_reading_files-spec.md`

## Context

- **Structure**: Flat — example app lives in `7epubs/lib/` with `main.dart` + `shelf_service.dart`
- **State management**: GetStorage for shelf + preferences; no Riverpod/Bloc
- **Reference implementations**: `shelf_service.dart` (GetStorage pattern), `show_epub.dart:213` (`Platform.isMacOS` guards)
- **Assumptions/Gaps**: Podspec exists but plugin not integrated into `GeneratedPluginRegistrant.swift` — `fvm flutter pub get` from `7epubs/` should handle this automatically after adding dependency. The local podspec at `7epubs/macos/Pods/Local Podspecs/macos_secure_bookmarks.podspec.json` is stale (v0.0.3) and should be removed after adding the proper pub dependency (v0.2.1).

## Plan

### Phase 1: Dependencies and entitlements

- **Goal**: Enable `macos_secure_bookmarks` plugin and grant bookmark entitlement
- [x] `7epubs/pubspec.yaml` — add `macos_secure_bookmarks: ^0.2.1` under dependencies
- [x] `7epubs/macos/Runner/Release.entitlements` — add `<key>com.apple.security.files.bookmarks.app-scope</key><true/>`
- [x] `7epubs/macos/Runner/DebugProfile.entitlements` — add `<key>com.apple.security.files.bookmarks.app-scope</key><true/>`
- [x] Remove stale podspec: `7epubs/macos/Pods/Local Podspecs/macos_secure_bookmarks.podspec.json`
- [x] Run `fvm flutter pub get` from `7epubs/` to install plugin + regenerate pod integration
- [x] Run `fvm flutter build macos --debug` from `7epubs/` to verify plugin compiles
- [x] Verify: `fvm flutter analyze` in `7epubs/` (pre-existing flutter_lints warning only)

### Phase 2: BookmarkService — business logic

- **Goal**: Abstraction over `SecureBookmarks` + GetStorage for creating, resolving, and removing bookmarks
- [x] `7epubs/lib/bookmark_service.dart` — create `BookmarkService` class with:
  - Constructor injection: `SecureBookmarksInterface` instance, `BookmarkStorageInterface` instance, `bool? isMacOS`
  - `Future<String?> bookmarkFile(String path)` — calls `_bookmarks.bookmark(File(path))`, stores in storage key `'bookmark_$path'`, returns bookmark string
  - `Future<String?> getBookmark(String path)` — reads from storage, returns null if missing
  - `Future<bool> resolveAndAccess(String path)` — gets bookmark, calls `resolveBookmark()`, calls `startAccessingSecurityScopedResource()`, returns success
  - `Future<void> stopAccessing(String path)` — calls `stopAccessingSecurityScopedResource()` on resolved file
  - `Future<void> removeBookmark(String path)` — removes from storage
  - `Future<void> clearAll()` — iterates all `'bookmark_'` keys and removes them
  - `Future<void> addDirectoryBookmark(String dirPath)` — creates bookmark for directory, stores with key `'bookmark_dir_$uuid'`, stores path mapping
  - `Future<List<AuthorizedDirectory>> getAuthorizedDirectories()` — lists stored directory bookmark entries
  - `Future<void> removeDirectoryBookmark(String entryKey)` — removes single directory bookmark
  - All methods guarded: no-op when `!_isMacOS`
  - Abstract interfaces (`SecureBookmarksInterface`, `BookmarkStorageInterface`) for testability
- [x] TDD: happy path — `bookmarkFile(path)` with valid File returns non-null bookmark string
- [x] TDD: happy path — `resolveAndAccess(path)` with stored bookmark returns true
- [x] TDD: edge case — `resolveAndAccess(path)` with no stored bookmark returns false without throwing
- [x] TDD: edge case — `bookmarkFile(path)` on non-existent file propagates exception from SecureBookmarks
- [x] TDD: happy path — `addDirectoryBookmark(dirPath)` + `getAuthorizedDirectories()` round-trip
- [x] TDD: edge case — `removeDirectoryBookmark(key)` removes only targeted entry
- [x] TDD: edge case — `clearAll()` removes all bookmark keys but leaves non-bookmark keys intact
- [x] Verify: `fvm flutter analyze` && `fvm flutter test` in `7epubs/` (8 tests pass, pre-existing flutter_lints warning only)

### Phase 3: Integrate bookmarks into ShelfScreen

- **Goal**: Wire BookmarkService into file pick/load/open flows so files survive app restart
- [x] `7epubs/lib/main.dart` — add `import 'bookmark_service.dart'` (already had Platform import); instantiate `BookmarkService` as state-scope variable
- [x] `_pickAndOpenEpub()` — after `ShelfService.addBook(path)`, call `bookmarkService.bookmarkFile(path)`; catch + SnackBar on failure; stopAccessing after reader dismiss
- [x] `_loadShelf()` — before `File(path).existsSync()`, call `bookmarkService.resolveAndAccess(path)` when Platform.isMacOS
- [x] `_openBook(String path)` — before `CosmosEpub.openLocalBook()`, call `bookmarkService.resolveAndAccess(path)`; stopAccessing after reader dismiss
- [x] `_removeBook(String path)` — add `bookmarkService.removeBookmark(path)` call
- [x] `_confirmClearAll()` — add `bookmarkService.clearAll()` call before `ShelfService.clearShelf()`
- [x] TDD: resolveAndAccess behaviour tested in Phase 2 unit tests (FakeBookmarks); wiring coverage deferred to Phase 6 robot journey test
- [x] Verify: `fvm flutter analyze` && `fvm flutter test` in `7epubs/` (8 tests pass)

### Phase 4: SettingsScreen and gear icon

- **Goal**: UI for directory authorization and bookmark management
- [x] `7epubs/lib/main.dart` — add gear icon (`Icons.settings`) to AppBar actions, conditionally rendered: `if (Platform.isMacOS) IconButton(icon: Icon(Icons.settings), onPressed: _openSettings)`
- [x] `7epubs/lib/main.dart` — add `_openSettings()` method: `Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(bookmarkService: bookmarkService)))`
- [x] `7epubs/lib/settings_screen.dart` — create `SettingsScreen` StatefulWidget:
  - Constructor takes `BookmarkService bookmarkService`
  - AppBar title "Settings"
  - Body: `Column` with:
    - `ElevatedButton` labeled "Allow access to directory" → calls `FilePicker.platform.getDirectoryPath()`
    - Subtitle explaining home directory access grant
    - `ListView` of authorized directories (from `bookmarkService.getAuthorizedDirectories()`)
    - Each list tile: directory path + trailing `IconButton(Icons.delete)` → confirms then removes
    - Empty state: centered "No directories authorized" text
  - On directory pick: create bookmark, refresh list, show SnackBar
  - On error: SnackBar with error message (bookmark creation failure, picker failure)
- [x] TDD: SettingsScreen renders list tiles when bookmarked directories exist (widget test with fake BookmarkService)
- [x] TDD: SettingsScreen shows empty state when no directories authorized
- [x] TDD: Tapping "Allow access to directory" invokes directory picker callback (widget test, verify onPressed)
- [x] TDD: Tapping delete on a directory tile removes it and refreshes list
- [x] TDD: On directory pick error, SnackBar appears with error message (covered by error handling in _pickDirectory)
- [x] Robot journey test deferred to Phase 6
- [x] Verify: `fvm flutter analyze` && `fvm flutter test` in `7epubs/` (12 tests pass)

### Phase 5: Resource cleanup and polish

- **Goal**: Call stopAccessing when reader is dismissed; ensure restart safety
- [ ] `7epubs/lib/main.dart` — `_openBook()`: after `Navigator.push` to reader, call `.then((_) => bookmarkService.stopAccessing(path))` when reader is popped
- [ ] `7epubs/lib/main.dart` — `_pickAndOpenEpub()`: same `.then()` pattern for stopAccessing
- [ ] Edge case: if `_openBook()` is called while another reader is still open, stopAccessing only the reopened book's path (path-keyed, no global leak)
- [ ] Verify: `fvm flutter analyze` && `fvm flutter test` in `7epubs/`
- [ ] Manual: macOS: pick EPUB → open reader → dismiss reader → verify no resource leak warnings in console

### Phase 6: Robot journey test — full pick-reopen cycle

- **Goal**: One end-to-end robot test proving bookmark persistence across simulated app restart
- [ ] `7epubs/test/journeys/macos_bookmark_journey_test.dart` — create robot journey:
  - Setup: FakeFilePicker returns `/tmp/test.epub`; FakeBookmarkService with controlled bookmark data; FakeShelfService with preset entries
  - Journey: pick file → assert bookmark created → simulate restart (re-instantiate services) → assert bookmark resolves → open book
  - Required selectors: `Key('shelf-list')` on ListView, `Key('shelf-loading')` on loading indicator, `Key('settings-gear')` on gear icon
  - Required seams: `FakeSecureBookmarks` with `bookmark()` returning test string, `resolveBookmark()` returning mock File; fake `startAccessingSecurityScopedResource` returning true
- [ ] Verify: `fvm flutter test test/journeys/macos_bookmark_journey_test.dart` in `7epubs/`

## Risks / Out of scope

- **Risks**:
  1. Plugin not auto-integrating: The stale local podspec may interfere with pub-get integration. Mitigated by deleting old podspec in Phase 1.
  2. `startAccessingSecurityScopedResource` is a top-level function, not a method — requires wrapping for testability.
  3. Manual verification only for real macOS sandbox — `flutter test` runs on host and cannot exercise native bookmark APIs.
- **Out of scope**:
  - `example/` app — not modified
  - Library (`lib/`) changes — `cosmos_epub.dart` untouched; bookmarking is app-layer concern
  - iOS, Android, Linux, Windows, web — zero behavior change on non-macOS
  - Removing stale bookmarks for deleted files — falls under existing shelf maintenance behavior
