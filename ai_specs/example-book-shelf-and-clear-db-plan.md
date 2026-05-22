## Overview

Replace example app's single hardcoded "Open book" button with a persistent book shelf UI.
Use `file_picker` for EPUB selection, `get_storage` for shelf persistence, existing CosmosEpub API for progress/highlights.

**Spec**: `ai_specs/example-book-shelf-and-clear-db.md`

## Context

- **Structure**: Single-file example app; adding one service class + rewriting main screen
- **State management**: Plain `StatefulWidget` + `setState` (no Riverpod/Bloc in example)
- **Storage**: `get_storage` already available via cosmos_epub transitive dep; key `example_shelf_v1`
- **Reference**: `example/lib/main.dart` (108 lines, current app)
- **Assumptions**: `CosmosEpub.initialize()` inits GetStorage before `runApp`; `path` package available transitively via cosmos_epub

## Plan

### Phase 1: Dependencies + ShelfService

- **Goal**: Wire up `file_picker`, create `ShelfService`, verify pub get succeeds
- [x] `example/pubspec.yaml` — add `file_picker: ^8.0.0` under `dependencies`
- [x] `example/lib/shelf_service.dart` — NEW: `ShelfService` with `getShelf()`, `addBook(path)`, `removeBook(path)`, `clearShelf()`; uses `GetStorage` key `example_shelf_v1`; add inline comment: "GetStorage initialised by CosmosEpub.initialize() in main() before runApp"
- [x] Verify: `cd example && fvm flutter pub get` (no errors)

### Phase 2: Shelf Screen UI

- **Goal**: Replace hardcoded button with ShelfScreen showing shelf list, empty state, and FAB
- [x] `example/lib/main.dart` — remove all asset-book code; replace `MyHomePage` with `ShelfScreen` StatefulWidget
- [x] `ShelfScreen._loadShelf()` — loads `ShelfService.getShelf()`, checks `File(path).existsSync()` per entry, calls `CosmosEpub.getBookProgress(path)` for subtitle; stored in `_books` (List of small data class or record)
- [x] `ListView.builder` — each row: `ListTile(title: basename, subtitle: "Chapter X, Page Y" or "Not started")`; greyed-out + warning icon when file missing
- [x] Empty-state placeholder — centred text "No books yet. Tap + to pick an EPUB."
- [x] `FloatingActionButton` labelled "Pick EPUB"
- [x] AppBar trailing `IconButton(icon: Icons.delete_forever)` for "Clear database"
- [ ] Verify: `fvm flutter run` (shelf screen renders, no crashes)

### Phase 3: File Picker + Open Flow

- **Goal**: FAB opens file picker, adds to shelf, opens reader immediately
- [x] FAB `onPressed` — `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['epub'])` wrapped in try/catch
- [x] On result null/empty: do nothing
- [x] On valid path: `ShelfService.addBook(path)` (dedup: skip if already present), then `CosmosEpub.openLocalBook(localPath: path, bookId: path, context: context)` in try/catch (SnackBar on error)
- [x] After `openLocalBook` returns (reader closed): call `_loadShelf()` to refresh subtitles
- [ ] Verify: pick an EPUB → reader opens → close → shelf row shows filename + progress

### Phase 4: Row Interactions + Clear Database

- **Goal**: Long-press remove, missing-file tap flow, clear-all confirmation
- [x] `ListTile.onTap` — if file missing: SnackBar "File not found." with "Remove" action (calls `_removeBook(path)`); if valid: `CosmosEpub.openLocalBook` then `_loadShelf()`
- [x] `ListTile.onLongPress` — show `showDialog` "Remove from shelf?" → confirm → `_removeBook(path)`
- [x] `_removeBook(path)`: `ShelfService.removeBook(path)`, `CosmosEpub.deleteBookProgress(path)`, `CosmosEpub.removeAllHighlights(path)`, then `_loadShelf()`
- [x] AppBar delete icon `onPressed`: `showDialog` confirmation → on confirm: iterate shelf, call `_removeBook` for each, then `CosmosEpub.deleteAllBooksProgress()`, `ShelfService.clearShelf()`, `_loadShelf()`, SnackBar "All books and progress cleared."
- [ ] Verify: long-press remove works; clear-all empties shelf; missing-file SnackBar shown

## Risks / Out of scope

- **Risks**: `file_picker` on Android may need `READ_EXTERNAL_STORAGE` permission in `example/android/app/src/main/AndroidManifest.xml` — add if needed; **`CosmosEpub.removeAllHighlights(bookId)`** — verify exact method name in `lib/cosmos_epub.dart` before Phase 4 (explorer found `removeAllHighlights` but check signature)
- **Out of scope**: Library (`lib/`) changes, web platform, automated tests, asset books retention
