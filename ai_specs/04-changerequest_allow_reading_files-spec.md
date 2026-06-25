<goal>
Fix the macOS sandbox "Operation not permitted" error when reopening previously-loaded EPUB files from the ShelfScreen. Integrate `macos_secure_bookmarks` to persist file access across app restarts using security-scoped bookmarks. Add a SettingsScreen with directory authorization UI accessible via a gear icon in the AppBar.
</goal>

<background>
The `7epubs` example app runs in a macOS App Sandbox (`com.apple.security.app-sandbox = true`) with `com.apple.security.files.user-selected.read-only` entitlement. FilePicker grants temporary read access during the session, but after app restart, the sandbox revokes access to previously-picked files. The shelf stores raw POSIX paths in GetStorage and tries `File(path).existsSync()` + `File(path).readAsBytesSync()` — both fail on macOS after restart.

## Why macos_secure_bookmarks
`macos_secure_bookmarks` v0.2.1 is a Flutter plugin that wraps `NSURL.bookmarkData(options:)` and `URL.startAccessingSecurityScopedResource()`. It enables persistent file/directory access across app restarts in sandboxed macOS apps. The podspec already exists at `7epubs/macos/Pods/Local Podspecs/macos_secure_bookmarks.podspec.json` but was never integrated into the plugin registry or Dart code.

## Tech stack
- `macos_secure_bookmarks: ^0.2.1` — new dependency for `7epubs/`
- `file_picker: ^8.0.0` — already used for EPUB picking; also supports `getDirectoryPath()` for directory selection
- `get_storage: ^2.1.1` — already used for shelf and preferences; will also store bookmark data
- `Platform.isMacOS` — used throughout the codebase to branch macOS-specific behavior

## Key source files
- `7epubs/lib/main.dart` — ShelfScreen, _pickAndOpenEpub(), _openBook(), _loadShelf()
- `7epubs/lib/shelf_service.dart` — GetStorage-backed shelf persistence
- `7epubs/macos/Runner/Release.entitlements` — sandbox entitlements
- `7epubs/macos/Runner/DebugProfile.entitlements` — debug entitlements
- `lib/cosmos_epub.dart` — openLocalBook() performs `File(localPath).readAsBytesSync()`
</background>

<user_flows>
Primary flow (reopen a previously-picked EPUB after app restart):
1. User launches 7epubs on macOS
2. ShelfScreen loads saved shelf entries from GetStorage
3. For each entry, the app resolves the stored security-scoped bookmark
4. `startAccessingSecurityScopedResource` is called on the resolved File
5. `File(path).existsSync()` returns true — shelf items show as available
6. User taps a book — `_openBook()` resolves the bookmark, starts resource access, opens the EPUB
7. Reader displays the book at the last reading position

Alternative flow (pre-authorize a directory via Settings):
1. User taps gear icon in ShelfScreen AppBar on macOS
2. SettingsScreen opens, showing "Allow access to directory" button and list of authorized directories
3. User taps "Allow access to directory"
4. System directory picker opens (`file_picker` `getDirectoryPath()`)
5. User selects a directory (e.g. home directory)
6. App creates a security-scoped bookmark for the directory, stores it in GetStorage
7. Directory appears in the authorized list with a remove option
8. EPUBs from this directory are now permanently accessible from the shelf

Alternative flow (auto-bookmark on first file pick):
1. User picks an EPUB via FilePicker (FAB)
2. App gets the file path from FilePicker
3. App immediately creates a security-scoped bookmark for the file
4. App stores bookmark data alongside shelf path entry
5. App opens the EPUB normally
6. On subsequent launches, the bookmark ensures the file remains accessible

Error flow (stale/invalid bookmark):
1. Bookmark resolution fails (file moved, directory removed, or permission revoked)
2. Shelf item shows a warning indicator (existing behavior for missing files)
3. Tapping the item shows a dialog: "File access lost. Please re-pick the file or authorize its parent directory in Settings."
4. User can dismiss and either pick the file again or go to Settings to authorize the directory

Error flow (non-macOS platform):
1. Gear icon is not rendered in the AppBar
2. No bookmark code executes — all file access falls through to direct path reads
3. Zero behavior change on iOS, Android, Linux, Windows, or web

Error flow (directory picker cancelled):
1. User opens directory picker from SettingsScreen
2. User cancels without selecting a directory
3. SettingsScreen remains as-is — no bookmark created, no error shown
</user_flows>

<requirements>
**Functional:**
1. On macOS, when `_pickAndOpenEpub()` selects a file via FilePicker, automatically create a security-scoped bookmark for that file and persist it in GetStorage alongside the shelf entry.
2. On macOS, when `_loadShelf()` runs, resolve stored bookmarks for each shelf entry and call `startAccessingSecurityScopedResource` before checking `File.existsSync()`. Fall back to direct path access if no bookmark exists or resolution fails.
3. On macOS, when `_openBook()` is called, resolve the file's bookmark, call `startAccessingSecurityScopedResource`, then proceed with `CosmosEpub.openLocalBook()`.
4. Add a gear icon (`Icons.settings`) to the ShelfScreen AppBar. The icon must only render when `Platform.isMacOS` is true. Display count: 0 on non-macOS.
5. Tapping the gear icon navigates to a new `SettingsScreen` via `Navigator.push` with a `MaterialPageRoute`.
6. SettingsScreen must display:
   - AppBar with title "Settings"
   - An `ElevatedButton` or `OutlinedButton` labeled "Allow access to directory"
   - A `ListView` (or empty state message) listing currently authorized directories
   - Each directory entry shows its path and a remove (trash/delete) icon button
7. Tapping "Allow access to directory" opens the system directory picker using `FilePicker.platform.getDirectoryPath()`. On macOS this triggers `NSOpenPanel` configured for directory selection.
8. After a directory is selected, create a security-scoped bookmark, persist it in GetStorage keyed by a unique identifier, and refresh the directory list.
9. Tapping the remove icon on a directory entry deletes the stored bookmark and removes it from the list.
10. The `macos_secure_bookmarks` package must be added as a dependency to `7epubs/pubspec.yaml` (not the root library pubspec.yaml).
11. macOS entitlements must include `com.apple.security.files.bookmarks.app-scope` (boolean true) in both DebugProfile and Release entitlements.

**Error Handling:**
12. If `SecureBookmarks().bookmark(File(path))` throws, catch the exception, show a SnackBar with "Failed to secure file access", and continue without persisting a bookmark. The file may still work during this session.
13. If `SecureBookmarks().resolveBookmark(bookmarkData)` throws or returns null, treat the bookmark as stale. Fall back to direct file access. The file may still be accessible if the sandbox has temporary access.
14. If `startAccessingSecurityScopedResource(resolvedFile)` returns false, treat the file as inaccessible. Show the shelf warning indicator.
15. If `getDirectoryPath()` returns null (user cancelled), do nothing — no error, no state change.
16. If bookmark creation for a directory fails, show a SnackBar error: "Could not secure access to this directory."

**Edge Cases:**
17. If a file was picked from a directory that is also bookmarked, the file-level bookmark takes precedence. No duplicate resolution.
18. If a bookmarked directory no longer exists on disk, show it in Settings with a warning icon rather than removing it silently.
19. On non-macOS platforms, all `macos_secure_bookmarks` calls must be guarded by `Platform.isMacOS` checks. No bookmark logic executes on other platforms.
20. Clearing the database (existing "Clear database" button) must also clear all stored bookmarks.
21. The `stopAccessingSecurityScopedResource` must be called after reading is complete and the reader is dismissed. Failure to stop accessing is a resource leak (macOS tracks security-scoped resource access counts).

**Validation:**
22. All bookmark storage/retrieval must use deterministic keys in GetStorage that do not collide with existing shelf or preference keys.
23. Bookmark data stored as String (base64 or hex-encoded) in GetStorage. No raw binary storage.
</requirements>

<boundaries>
Edge cases:
- File moved/renamed after bookmark creation: Bookmark resolution returns an updated path. Use the resolved path for file access, not the originally stored shelf path.
- Directory renamed after bookmark creation: Bookmark may become stale. Show warning in Settings; user must re-authorize.
- Multiple EPUBs from the same bookmarked directory: Only the directory bookmark needs resolution. Files are accessed via their stored paths after `startAccessingSecurityScopedResource` on the directory.
- App update/rebuild: Bookmark data persists in GetStorage across app updates as long as the app bundle identifier doesn't change.
- Bookmark for home directory (`/Users/username`): This grants access to ALL files within the user's home directory. Make this clear in the Settings UI with a subtitle: "Authorizing your home directory grants access to all EPUB files within it."

Error scenarios:
- Bookmark data corrupted in storage: Catch deserialization errors, treat as missing bookmark, fall back to direct path.
- `startAccessingSecurityScopedResource` returns false: File is inaccessible. Show shelf warning. Do not attempt to open.
- Both bookmark resolution AND direct path access fail: Show dialog: "Cannot open this file. It may have been moved or deleted. Remove it from your shelf and re-add it."

Limits:
- Files outside any bookmarked directory require individual file bookmarks. Auto-creation on pick handles this.
- Bookmark storage in GetStorage has no built-in size limit, but typical bookmark data is < 2KB. No practical limit for shelf sizes under 1000 entries.
- Directory bookmarks grant recursive access. Subdirectories are included automatically via macOS security-scoped bookmark semantics.
</boundaries>

<implementation>
## New files
- `7epubs/lib/settings_screen.dart` — SettingsScreen StatefulWidget
- `7epubs/lib/bookmark_service.dart` — BookmarkService class wrapping macos_secure_bookmarks API + GetStorage persistence

## Files to modify
- `7epubs/lib/main.dart` — add gear icon to AppBar, integrate bookmark resolution into `_loadShelf()`, `_openBook()`, `_pickAndOpenEpub()`, and `_removeBook()`; add stopAccessing call on reader dismiss
- `7epubs/lib/shelf_service.dart` — add `removeAll()` if not present; ensure clearDatabase also clears bookmarks
- `7epubs/pubspec.yaml` — add `macos_secure_bookmarks: ^0.2.1`
- `7epubs/macos/Runner/Release.entitlements` — add `com.apple.security.files.bookmarks.app-scope`
- `7epubs/macos/Runner/DebugProfile.entitlements` — add `com.apple.security.files.bookmarks.app-scope`
- `7epubs/macos/Podfile` — add pod install step if needed for the plugin's native code

## Patterns to follow
- Use `Platform.isMacOS` guards for all bookmark code (matches existing pattern in `show_epub.dart`)
- Store bookmark data in GetStorage with key prefix `'bookmark_'` to avoid collisions with `'seven_epubs_shelf_v1'`
- BookmarkService should be a class with constructor injection for `SecureBookmarks` and storage (enables testing with fakes)
- Follow the existing `ShelfService` pattern: static class with async methods for storage operations
- Use `Icons.settings` for the gear icon (standard Flutter material icon)
- Match existing AppBar style in ShelfScreen: dark theme, white icons

## What to avoid
- Do NOT add `macos_secure_bookmarks` to the root library `pubspec.yaml` — it stays in `7epubs/pubspec.yaml` only
- Do NOT modify `lib/cosmos_epub.dart` unless unavoidable — bookmark resolution happens in the app layer before calling `openLocalBook`
- Do NOT call `stopAccessingSecurityScopedResource` immediately after reading — keep access until the reader is popped
- Do NOT store bookmark data in the library's Drift database — keep it in the app layer's GetStorage
</implementation>

<validation>
This spec covers user-facing features with testable business logic. All tests use the `7epubs/` project's test runner (`fvm flutter test` from `7epubs/`).

## Required baseline automated coverage outcomes
1. **Business logic coverage**: BookmarkService.createBookmark, BookmarkService.resolveBookmark, BookmarkService.removeBookmark, BookmarkService.areAllRequired tested with unit tests using a FakeSecureBookmarks and FakeStorage.
2. **UI behavior coverage**: SettingsScreen widget tests covering: directory list rendering, empty state, remove button triggers deletion, "Allow access" button triggers directory picker.
3. **Critical journey coverage**: Robot-driven journey test: launch app → pick file → close reader → see file on shelf accessible → restart simulation → see file still accessible via bookmark resolution.

## TDD expectations — behavior-first slices with testability seams
Phase execution order follows vertical-slice TDD (one test at a time, red → green → refactor):

### Slice 1: Happy path — BookmarkService bookmarks a file
- Test: Given a valid File path, `BookmarkService.bookmarkFile(path)` returns a non-null bookmark string.
- Seam: `BookmarkService` takes `SecureBookmarks` interface via constructor. Use `FakeSecureBookmarks` in tests that returns a predetermined bookmark string.
- Implementation: `bookmarkFile()` calls `_bookmarks.bookmark(File(path))`, stores result in GetStorage with key `'bookmark_$path'`.

### Slice 2: Happy path — BookmarkService resolves a bookmark
- Test: Given a stored bookmark, `BookmarkService.resolveAndAccess(path)` returns true.
- Seam: `FakeSecureBookmarks.resolveBookmark()` returns a mock File; `startAccessingSecurityScopedResource` is mocked per-test.
- Implementation: Retrieves bookmark from storage, calls `resolveBookmark()`, calls `startAccessingSecurityScopedResource()`, returns success boolean.

### Slice 3: Error — BookmarkService handles missing bookmark
- Test: Given a path with no stored bookmark, `resolveAndAccess()` returns false without throwing.
- Implementation: Returns false when GetStorage read returns null.

### Slice 4: Widget — SettingsScreen displays authorized directories
- Test: Given stored directory bookmarks, SettingsScreen renders a ListTile per directory with path text and remove icon.
- Seam: Inject a fake BookmarkService that returns a prepopulated list of directories.
- Implementation: SettingsScreen reads from BookmarkService.getAuthorizedDirectories() in initState, renders ListView.

### Slice 5: Widget — SettingsScreen "Allow access" triggers picker
- Test: Tapping "Allow access to directory" button calls the onPickDirectory callback.
- Seam: Pass a callback; verify it's invoked on tap.
- Implementation: Button onPressed invokes the callback provided via constructor.

### Slice 6: Robot journey — Full pick-reopen cycle
- Test: Simulate picking a file → verify bookmark created → simulate app restart → verify bookmark resolves and file is accessible on shelf.
- Required selectors: `Key('shelf-list')` on the shelf ListView, `Key('settings-gear')` on the gear icon.
- Required seams: FakeFilePicker that returns a predetermined path; FakeSecureBookmarks with controlled bookmark data; FakeShelfService with preset entries.

## Default test split
- **Unit tests**: BookmarkService logic (bookmark creation, resolution, removal, storage key management) → `7epubs/test/bookmark_service_test.dart`
- **Widget tests**: SettingsScreen rendering, directory list, remove action, empty state → `7epubs/test/settings_screen_test.dart`
- **Robot journey test**: Critical happy path (pick → reopen → open) → `7epubs/test/journeys/macos_bookmark_journey_test.dart`

## Testing risks
- `macos_secure_bookmarks` native plugin cannot be exercised in standard `flutter test` (no macOS plugin channel). Tests must use a Fake/Double for `SecureBookmarks` and standalone `startAccessingSecurityScopedResource`/`stopAccessingSecurityScopedResource` functions.
- The native `startAccessingSecurityScopedResource` is a top-level function from the package, not a method on `SecureBookmarks`. The fake must also provide a top-level override or the BookmarkService must wrap it in an injectable interface.
- Real macOS sandbox behavior can only be validated manually on a macOS device or simulator. Document this as a manual verification step.

## Manual verification
After implementation, verify on macOS:
1. Launch app, pick an EPUB via FilePicker → confirm it opens
2. Close app completely (Cmd+Q)
3. Relaunch app → confirm the EPUB appears on shelf and opens without "Operation not permitted"
4. Open Settings → tap "Allow access to directory" → select home directory → confirm directory appears in list
5. Pick an EPUB from a subdirectory of home → close and relaunch app → confirm it opens
6. Remove a directory from Settings → confirm files from that directory show as inaccessible
</validation>

<done_when>
1. On macOS, picking an EPUB via FilePicker and reopening it after app restart succeeds without "Operation not permitted" error.
2. Gear icon appears in ShelfScreen AppBar on macOS. Non-macOS platforms show no gear icon.
3. SettingsScreen renders with "Allow access to directory" button and authorized directory list.
4. Selecting a directory via the picker persists a bookmark and displays the directory in the list.
5. Removing a directory from Settings deletes the bookmark and the directory disappears from the list.
6. All stored bookmarks are cleared when the user clears the database/shelf.
7. `stopAccessingSecurityScopedResource` is called when the reader screen is dismissed.
8. `7epubs/pubspec.yaml` includes `macos_secure_bookmarks: ^0.2.1`.
9. Both macOS entitlements files include `com.apple.security.files.bookmarks.app-scope`.
10. `flutter analyze` passes with no errors in the 7epubs project.
11. All unit tests, widget tests, and the robot journey test pass.
12. Manual verification on macOS confirms end-to-end bookmark persistence works.
</done_when>
