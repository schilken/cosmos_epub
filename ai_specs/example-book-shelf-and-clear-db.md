<goal>
Replace the single hardcoded "Open book" button in the example app with a full book-shelf UI.
Users can pick EPUB files from the filesystem, open them immediately, and see all previously opened files
in a persistent shelf list. A "Clear database" button wipes all reading progress and highlights for
every book on the shelf and clears the shelf itself. This demonstrates the full CosmosEpub API surface
(open, progress, highlights, clear) to consumers of the library.
</goal>

<background>
Flutter package: cosmos_epub (example app at `example/`)
Tech stack: Flutter, Dart, get_storage (already a transitive dep via cosmos_epub), Drift for reading
progress, CosmosEpub static API.

Key files to examine before implementing:
- `example/lib/main.dart` — current single-screen app (hardcoded asset book, no file picker)
- `example/pubspec.yaml` — add `file_picker` dependency here
- `lib/cosmos_epub.dart` — public API (deleteAllBooksProgress, deleteBookProgress, getBookProgress,
  openLocalBook, removeAllHighlights, removeHighlight)
- `lib/Helpers/drift_progress_service.dart` — DAO (deleteAllBooksProgress, deleteBookProgress)
- `lib/Model/highlight_model.dart` — HighlightStorage.removeAllForBook(bookId)

Constraints:
- Changes are confined to `example/` only; do not modify any file under `lib/`.
- get_storage is already available transitively — use it for the shelf list (no new storage dep).
- `file_picker` must be added to `example/pubspec.yaml` (not the root pubspec.yaml).
- bookId for a locally-picked file: use the file's absolute path as the stable identifier
  (consistent with openLocalBook usage patterns).
- CosmosEpub.initialize() is already called in main(); it initialises get_storage too.
- Web is unsupported — no web-specific code needed.
</background>

<user_flows>
Primary flow — pick and open a new EPUB:
1. User opens the example app → sees the shelf screen (empty shelf on first launch).
2. User taps the FAB "Pick EPUB" button.
3. OS file picker opens filtered to `.epub` files.
4. User selects a file → picker returns the absolute local path.
5. Path is saved to the shelf list in get_storage (key: `example_shelf_v1`).
6. `CosmosEpub.openLocalBook(localPath: path, bookId: path, context: context)` is called immediately.
7. Reader opens. User reads, closes reader.
8. App returns to shelf screen. The new book row is now visible showing filename + last chapter/page.

Alternative flow — re-open a previously remembered book:
1. User opens app → sees shelf populated from get_storage.
2. User taps a book row that has a valid file path.
3. `CosmosEpub.openLocalBook` is called with that path.
4. Reader opens at the last saved position (resume behaviour from CosmosEpub).

Alternative flow — user cancels file picker:
1. User taps FAB → file picker opens.
2. User cancels without selecting a file.
3. Nothing changes; app remains on shelf screen.

Error flow — missing file:
1. Shelf loads a saved path that no longer exists on the device (file deleted, SD card removed, etc.).
2. The row is rendered greyed-out with a warning icon.
3. User taps the row → no reader is opened; a SnackBar shows "File not found. Remove it from the shelf?".
4. User taps "Remove" in the SnackBar action → row is deleted from shelf and DB progress/highlights
   for that bookId are cleared.
5. Alternatively, the user can long-press any row (valid or missing) to get a "Remove from shelf" option.

Clear database flow:
1. User taps "Clear database" button (e.g., in an AppBar action or a dedicated button on the shelf screen).
2. A confirmation dialog is shown: "This will delete all reading progress and highlights. Continue?"
3. User confirms.
4. For each bookId in the shelf:
   - `CosmosEpub.deleteBookProgress(bookId)` is called.
   - `CosmosEpub.removeAllHighlights(bookId)` is called  ← uses HighlightStorage.removeAllForBook
     (note: this is `CosmosEpub.removeAllHighlights(bookId)` in the public API — verify exact method name).
5. `CosmosEpub.deleteAllBooksProgress()` is called to catch any orphaned DB rows.
6. The shelf list in get_storage is cleared (key: `example_shelf_v1` → empty list `[]`).
7. Shelf screen refreshes to empty state.
8. SnackBar: "All books and progress cleared."
</user_flows>

<requirements>
**Functional:**
1. Add `file_picker: ^8.0.0` (or latest compatible) to `example/pubspec.yaml`.
2. Remove all hardcoded asset book buttons from the example app UI.
3. Implement `ShelfService` (a plain Dart class in `example/lib/`) that wraps get_storage key
   `example_shelf_v1` and exposes:
   - `List<String> getShelf()` — returns saved file paths (empty list if not set).
   - `Future<void> addBook(String path)` — appends path if not already present.
   - `Future<void> removeBook(String path)` — removes path.
   - `Future<void> clearShelf()` — sets key to [].
4. Each shelf row shows: filename (basename of path) on the first line; last read position
   ("Chapter X, Page Y" from `CosmosEpub.getBookProgress(bookId)`) on the second line.
   If no progress exists, show "Not started" as the subtitle.
5. If a row's file does not exist on disk (`File(path).existsSync() == false`):
   - Render the row greyed out with a warning icon.
   - On tap: show SnackBar with message "File not found." and a "Remove" action.
   - On "Remove" action: remove from shelf, delete progress, delete highlights.
6. Long-press on any row (valid or missing) shows a "Remove from shelf" option (bottom sheet or
   simple dialog). Confirming removes it from shelf, progress, and highlights.
7. FAB labelled "Pick EPUB" triggers `FilePicker.platform.pickFiles(type: FileType.custom,
   allowedExtensions: ['epub'])`. If the user cancels (result is null or files is empty), do nothing.
8. On successful file pick: call `ShelfService.addBook(path)`, then immediately call
   `CosmosEpub.openLocalBook(localPath: path, bookId: path, context: context)`.
9. "Clear database" action (AppBar trailing IconButton with a delete icon):
   - Show confirmation AlertDialog before proceeding.
   - On confirm: for each path in shelf, call `deleteBookProgress` and `removeAllHighlights`.
   - Then call `deleteAllBooksProgress()` and `ShelfService.clearShelf()`.
   - Refresh shelf UI. Show SnackBar "All books and progress cleared."
10. After returning from the reader (Navigator.pop), refresh the shelf list to update last-read subtitles.

**Error Handling:**
11. Wrap `CosmosEpub.openLocalBook` in a try/catch; if it throws, show a SnackBar with the error message.
12. Wrap `FilePicker.platform.pickFiles` in a try/catch (permission denied, platform exception);
    show a SnackBar "Could not open file picker: [error]".
13. If `CosmosEpub.getBookProgress` throws or returns null, display "Not started" subtitle (do not crash).

**Edge Cases:**
14. Duplicate file: if the user picks a file path already in the shelf, do not add a duplicate — call
    `openLocalBook` directly (the file is already in the shelf).
15. Shelf empty state: show a centred placeholder "No books yet. Tap + to pick an EPUB." when the
    shelf list is empty.
16. Long paths: display only the basename (`path.split('/').last`) — never the full path — in the UI.

**Validation:**
17. (Manual) Pick an EPUB → shelf shows one entry with filename + "Not started" → open it, read a
    few pages → close → subtitle updates to "Chapter X, Page Y".
18. (Manual) Clear database → confirmation dialog appears → confirm → shelf empties, SnackBar shows.
19. (Manual) Simulate missing file by renaming a file after adding it to the shelf → row appears greyed
    out, tap shows SnackBar with "Remove" action.
</requirements>

<boundaries>
Edge cases:
- User picks same file twice: deduplicate silently; no duplicate rows.
- File picker returns a URI (on some Android configs) rather than a direct path: use
  `result.files.single.path` (file_picker resolves to a cache path on Android automatically).
- get_storage not yet initialised when ShelfService is called: CosmosEpub.initialize() is called in
  main() before runApp(), so GetStorage is always ready — document this assumption in code comments.
- Large shelf (many books): use ListView.builder (lazy); no pagination needed for example app scale.
- Progress refresh timing: `getBookProgress` is async; use FutureBuilder or async setState per row
  to avoid blocking list rendering.

Error scenarios:
- File picker permission denied (iOS/Android): SnackBar "Could not open file picker: [error]".
- openLocalBook fails (corrupt EPUB, parse error): SnackBar "Failed to open book: [error]".
- get_storage write failure: treat as non-fatal; log to console.
- deleteBookProgress/removeAllHighlights throw during clear: continue iterating other books; log errors.

Limits:
- No explicit file size limit in the example; file_picker has no built-in restriction.
- The example is not a production app — no rate limiting or quota logic needed.
</boundaries>

<implementation>
Files to create or modify:

1. `example/pubspec.yaml` — add `file_picker: ^8.0.0` under `dependencies`.
2. `example/lib/shelf_service.dart` — NEW: `ShelfService` class (see requirement 3).
3. `example/lib/main.dart` — REPLACE current content:
   - Remove all hardcoded asset book references.
   - Build a `ShelfScreen` StatefulWidget as the home screen.
   - Shelf screen renders `ListView.builder` over `ShelfService.getShelf()`.
   - Each item: `ListTile` with `title = basename(path)`, `subtitle = FutureBuilder for progress`,
     greyed-out style + warning icon when file is missing, onTap/onLongPress handlers.
   - FAB: "Pick EPUB" with add icon.
   - AppBar trailing: delete icon for "Clear database".

Patterns to follow:
- Use `StatefulWidget` + `setState` for shelf refresh (no Riverpod/Bloc needed in example).
- `path` package (already in root pubspec, available to example via path dep) for basename.
- `dart:io` `File` for existsSync check.
- Keep all new logic inside `example/lib/`; never import from `lib/` directly except via the
  `cosmos_epub` package import.

What to avoid:
- Do not add `file_picker` or any new dep to the root `pubspec.yaml` — example-only change.
- Do not store the full file path in any UI label — use basename only.
- Do not call `CosmosEpub` methods before `initialize()` completes.
- Do not use `isar` or `isar_community` (removed from project; AGENTS.md is stale on this point).
- Do not add web platform support.

Run after changes:
```bash
cd example && fvm flutter pub get && fvm flutter run
```
</implementation>

<validation>
Manual smoke tests (no automated test suite exists; document results):

1. **Empty shelf** — fresh launch → placeholder text visible, no list items.
2. **Pick EPUB** — tap FAB → OS picker opens filtered to .epub → select a file → reader opens → 
   close reader → shelf shows one row with correct filename and updated subtitle.
3. **Duplicate pick** — pick the same file again → shelf still shows one row (no duplicate).
4. **Resume position** — re-tap existing row → reader opens at last saved chapter/page.
5. **Missing file** — rename/delete the file externally, hot-restart → row appears greyed out → 
   tap row → SnackBar with "Remove" action → tap Remove → row disappears, no crash.
6. **Long-press remove** — long-press a valid row → dialog/bottom-sheet → confirm remove → 
   row removed from shelf.
7. **Clear database** — add multiple books with progress → tap delete icon → confirmation dialog → 
   confirm → shelf empties → SnackBar appears → re-pick same file → progress subtitle shows "Not started".
8. **Cancel file picker** — tap FAB → cancel picker → shelf unchanged.
9. **Corrupt/unreadable EPUB** — pick a non-EPUB file renamed to .epub → SnackBar error shown, no crash.

No automated tests are required for the example app itself (it is a demo, not a library). If the
library's own unit/widget tests are ever added, they live under `test/` in the package root, not in
`example/`.
</validation>

<done_when>
- `example/pubspec.yaml` contains `file_picker` dependency.
- `example/lib/shelf_service.dart` exists with ShelfService class.
- `example/lib/main.dart` contains no hardcoded asset book references.
- Running the example app shows an empty shelf with "No books yet" placeholder on first launch.
- Picking an EPUB opens the reader and adds the file to the shelf.
- The shelf row shows filename + chapter/page progress after returning from the reader.
- Greyed-out row + SnackBar behaviour works for a missing file path.
- "Clear database" confirmation dialog wipes shelf + progress + highlights.
- `fvm flutter run` in `example/` completes without errors.
</done_when>
