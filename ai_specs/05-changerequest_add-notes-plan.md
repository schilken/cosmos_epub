## Overview

Add note-anchoring on text selections (blue highlight + free-text) reusing `HighlightStorage`; review + export notes per open book via a reader AppBar overflow menu. Trim highlight palette to 3 colors.

**Spec**: `ai_specs/05-changerequest_add-notes-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`lib/Component`, `lib/Helpers`, `lib/Model`) + `lib/cosmos_epub.dart` facade.
- **State management**: plain `setState`; no Riverpod/Bloc. Do not introduce any.
- **Storage**: highlights via GetStorage JSON (`HighlightStorage`, key `cosmos_highlights_v2`). Progress via Drift — DO NOT touch.
- **Reference implementations**:
  - `lib/Component/highlight_toolbar.dart` — `highlightColors` palette, toolbar shape.
  - `lib/Helpers/pagination.dart:610` `_PageToolbar`; `:456` `_addHighlight`; `:560` `contextMenuBuilder`.
  - `lib/Model/highlight_model.dart` — `HighlightModel` + `HighlightStorage`.
  - `lib/Helpers/html_text_builder.dart` — block highlight rendering (reused for note anchors).
  - `lib/show_epub.dart:824` — reader AppBar `actions` insertion point.
- **Test infra**: `flutter_test` present in dev deps; no tests exist yet. Plan adds a test tree; `flutter test` baseline = 0 tests. Risk: harness/robot not established — start with unit + widget tests, defer robot journey.
- **file_picker**: already `^8.0.0` in `7epubs` example (resolve 8.3.7). Add `file_picker: ^8.0.0` to the **library** `pubspec.yaml` so the in-library export UI builds; example inherits.
- **Assumptions/Gaps**:
  - Change request says "refine AppBar of 7epubs"; user clarified notes scope = currently-open book → menu lives on the **ShowEpub reader AppBar**, not the shelf AppBar (spec-confirmed).
  - Storage seam: `HighlightStorage` singleton uses `_gs`; for tests add a `@visibleForTesting` injectable storage override (smallest change).
  - `NotesListScreen` must accept an injectable `noteProvider` so widget tests don't boot GetStorage.

## Plan

### Phase 1: Data model + storage seam (TDD vertical slice)

- **Goal**: `HighlightModel` carries `noteText`; `HighlightStorage` filters notes; test seam exists.
- [x] `lib/Model/highlight_model.dart` — add `final String? noteText`; ctor + `toJson`/`fromJson` (absent/empty → `null`); `bool get isNote => noteText != null && noteText!.trim().isNotEmpty;`.
- [x] `lib/Model/highlight_model.dart` — add `@visibleForTesting static late GetStorage _gs` swap seam (or `static GetStorage Function() storageProvider = () => GetStorage();`) and route `_gs` access through it; keep key `cosmos_highlights_v2`.
- [x] `lib/Model/highlight_model.dart` — add `HighlightStorage.getBookNotes(String bookId)` (`_readAll().where((h) => h.bookId == bookId && h.isNote)`); alias `removeNote(id)` → `removeHighlight`.
- [x] `test/model/highlight_model_test.dart` — TDD: round-trip `noteText` non-null → then impl; absent key → null → then impl; `isNote` true iff non-blank → then impl; `getBookNotes` filters only note rows scoped by bookId using a fake GetStorage → storage seam.
- [x] Verify: `fvm flutter analyze` clean; `fvm flutter test test/model/highlight_model_test.dart` green.

### Phase 2: Note exporter (pure helpers, TDD)

- **Goal**: markdown + JSON serialization, deterministic aside from clock.
- [x] `lib/Helpers/note_exporter.dart` — `String notesToMarkdown(String bookTitle, List<HighlightModel> notes, {DateTime Function() now = DateTime.now})`; section per note (`## Chapter N` + `>` quote of selectedText + note body + `---`).
- [x] `lib/Helpers/note_exporter.dart` — `String notesToJson(String bookTitle, List<HighlightModel> notes, {DateTime Function() now})` → `jsonEncode({book, exportedAt: now().toIso8601String(), notes: [...]})` with `{chapterIndex, selectedText, noteText, paragraphKey, startIndex, endIndex}`.
- [x] `test/helpers/note_exporter_test.dart` — TDD: empty list → minimal valid output; one note → expected markdown shape; JSON `jsonDecode`s with matching `notes.length`; multi/chapter ordering; unicode; injected `now` keeps output deterministic.
- [x] Verify: `fvm flutter test test/helpers/note_exporter_test.dart`.

### Phase 3: Toolbar palette + note icon (UI behavior, TDD)

- **Goal**: 3 colors only; note icon disabled when no selection.
- [x] `lib/Component/highlight_toolbar.dart` — trim `highlightColors` to yellow/green/red; add `const Color noteAnchorColor = Color(0xFF64B5F6);`.
- [x] `lib/Helpers/pagination.dart` — extract `_resolveSelectionRange(String text)` from `_addHighlight` (returns `({int start, int end, String cleanSelected})?`); `_addHighlight` reuses it (no behavior change).
- [x] `lib/Helpers/pagination.dart` `_PageToolbar` — add `VoidCallback onTakeNote` + `bool selectionAvailable`; render note icon (`Icons.note_add`) after the divider, before copy; disabled style `Colors.white24` + tap guard.
- [x] `lib/Helpers/pagination.dart` `contextMenuBuilder` — wire `selectionAvailable: _lastSelectedText.trim().isNotEmpty`.
- [x] `test/component/highlight_toolbar_test.dart` + `test/helpers/page_toolbar_test.dart` — TDD: exactly 3 color dots (count circles by background) → trim; note icon present + palette tests green. (Full note icon behavior tests deferred to Phase 4 since _PageToolbar is private.)
- [x] Verify: `fvm flutter test`; `fvm flutter analyze`.

### Phase 4: `_takeNote` dialog + persistence (vertical slice, TDD)

- **Goal**: selection → note dialog → blue anchor with `noteText` saved.
- [x] `lib/Helpers/pagination.dart` `_HighlightablePageState` — add `_takeNote()`: `showDialog<String?>` with selected-text preview (read-only) + multiline `TextField`; Save disabled when empty; cancel/empty → no-op.
- [x] `lib/Helpers/pagination.dart` `_takeNote` — on non-empty result: reuse `_resolveSelectionRange`; build `HighlightModel` with `colorValue = noteAnchorColor.toARGB32()` and `noteText`; `HighlightStorage.addOrUpdate` (dedupe upgrades existing color→blue + sets noteText); try/catch → snackbar "Could not save note"; `setState`; `FocusManager.instance.primaryFocus?.unfocus()`.
- [x] `lib/Helpers/pagination.dart` — guard `_lastSelectedText` empty / `widget.bookId.isEmpty` (mirror `_addHighlight`).
- [x] `test/helpers/take_note_dialog_test.dart` — TDD: persisted entry appears via fake storage seam + is `isNote` + blue color; existing highlight upgraded to note with blue color by addOrUpdate dedupe.
- [x] Verify: `fvm flutter test`; manual: take note on `book_nested.epub` → blue anchor persists after page flip/back.

### Phase 5: Public API + dependency for export

- **Goal**: expose note accessors; library can run `file_picker.saveFile`.
- [x] `lib/pubspec.yaml` — add `file_picker: ^8.0.0`; `fvm flutter pub get`.
- [x] `lib/cosmos_epub.dart` — add `static List<HighlightModel> getBookNotes(String bookId)` (→ `HighlightStorage.getBookNotes`); `static void removeNote(String id)` (→ removeHighlight alias).
- [x] Verify: `fvm flutter analyze`; `7epubs` example builds (`cd 7epubs && fvm flutter pub get`).

### Phase 6: Notes list screen (TDD, injected seam)

- **Goal**: list + delete per `bookId`.
- [x] `lib/Component/notes_list_screen.dart` — `NotesListScreen` StatefulWidget: ctor `({required String bookId, List<HighlightModel> Function(String)? noteProvider})`; default `noteProvider = CosmosEpub.getBookNotes`. `ListView.builder`, per-row `title`=noteText, `subtitle`=`"Ch. N · <selectedText>"` truncated ~60; trailing `IconButton(Icons.delete_outline)` → `CosmosEpub.removeNote` + refresh. Empty state text. Keys: `notes_list`, `note_$id`, `note_delete_$id`.
- [x] `test/component/notes_list_screen_test.dart` — TDD: injected `noteProvider` returns K notes → K rows appear; tap delete → row gone; empty provider → empty-state text.
- [x] Verify: `fvm flutter test test/component/`.

### Phase 7: Reader AppBar overflow menu + export plumbing (TDD)

- **Goal**: three-dots → Notes / Export Markdown / Export JSON scoped to open book.
- [x] `lib/show_epub.dart` `actions` (~line 824) — add `PopupMenuButton<String>` `key: Key('reader_overflow_menu')`, `icon: Icon(Icons.more_vert)`, items `notes`, `export_md`, `export_json`.
- [x] `lib/show_epub.dart` — handlers: `notes` → `Navigator.push(MaterialPageRoute(builder: (_) => NotesListScreen(bookId: widget.bookId)));` `export_md`/`export_json` → build content via `notesToMarkdown`/`notesToJson` using `CosmosEpub.getBookNotes(widget.bookId)`; if empty → snackbar "No notes to export"; else `FilePicker.platform.saveFile(dialogTitle, fileName: notes_<safe>_<ts>.{ext}, filesExtensions: [ext], bytes: utf8.encode(content))`; null → "Export cancelled"; failure → "Export failed: <e>"; success → "Notes exported to <filename>".
- [x] `test/show_epub_overflow_test.dart` — TDD: menu item "Export Markdown" exists with key; menu items include notes, export_md, export_json values.
- [ ] Robot journey (stretch, flagged residual risk): open reader → select → take note → open Notes → row present → delete → empty state. Deferred — widget tests cover the individual slices but a full integration robot test is not in scope for this run.
- [x] Verify: `fvm flutter test`; `fvm flutter analyze`; manual on macOS: take note → Notes list → delete; Export Markdown/JSON to disk → open file → readable / `python3 -m json.tool` validates.

## Risks / Out of scope

- **Risks**:
  - Test harness absent (no tests, no robot infra) — first-pass cost; unit+widget layers come first, robot journey deferred unless trivial.
  - `file_picker.saveFile` semantics differ per OS (iOS presents share-ish sheet); test on macOS first, note any iOS/Android-specific snags for follow-up.
  - Storage seam must not regress production `_gs` default; verify default path still used at runtime (single-point change).
- **Out of scope**:
  - Shelf-level AppBar changes (notes are reader-scoped per user clarification).
  - Cross-book notes aggregation, search/filter on the notes list.
  - Reopening an anchor by tapping the blue highlight in the page (nice-to-have, deferred).
  - Localization; new state-management libs; web targets.
  - Drift/progress schema or reading-progress changes.