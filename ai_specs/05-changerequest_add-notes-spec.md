<goal>
Add the ability to attach free-text notes to text selections inside the EPUB reader,
review and export those notes for the currently-open book, and simplify the highlight
palette. Notes piggyback on the existing highlight storage so they appear inline as blue
anchors and remain navigable/exportable. Readers benefit by being able to annotate
passages and later recall or share their notes from one screen.
</goal>

<background>
- Technology stack: Flutter (FVM 3.35.0), `epubx`, `get_storage` (highlights), `drift`/`sqlite3` (reading progress only), `flutter_screenutil` (design 375x812), `file_picker` in the `7epubs` example app.
- AGENTS.md is stale about Isar — the real storage backend for highlights is `get_storage` via `lib/Model/highlight_model.dart` (`HighlightStorage`). Drift is only for reading progress (`lib/Database/app_database.dart`). Do NOT change Drift schema.
- Files to examine before implementing:
  - @lib/Component/highlight_toolbar.dart — `highlightColors` palette (6 entries today).
  - @lib/Helpers/pagination.dart — `_PageToolbar` at line 610; `_addHighlight` at line 456; the `contextMenuBuilder` at line 560 wires the toolbar to `SelectionArea`.
  - @lib/Model/highlight_model.dart — `HighlightModel` + `HighlightStorage` (GetStorage JSON, key `cosmos_highlights_v2`).
  - @lib/Helpers/html_text_builder.dart — renders highlights per block (note-anchors reuse the same render path).
  - @lib/show_epub.dart — reader `AppBar` at line 792, `actions:` list at line 824 (where the three-dots overflow is added). `bookId` is available on the widget.
  - @lib/cosmos_epub.dart — public API surface (`CosmosEpub`); extend with note accessors.
  - @7epubs/lib/main.dart — example app; `file_picker` already a dependency and used for epub picking. Export feature lives in the library but the example app's reader (via `ShowEpub`) is where the AppBar menu appears.
- Constraints: web is unsupported (per AGENTS.md). Do not add web targets. Do not introduce new heavy dependencies; `file_picker` is already present in the example app. Keep `flutter_screenutil` `.sp`/`.w`/`.h` sizing for any new UI.
</background>

<user_flows>
Primary flow (take a note):
1. While reading, long-press / drag to select a word or phrase → `SelectionArea` shows `_PageToolbar`.
2. Toolbar now shows 3 color dots (yellow, green, red), a divider, a "note" icon (`Icons.note_add` or `Icons.sticky_note_2`), copy, select-all.
3. If a selection exists, the note icon is clickable; otherwise it is greyed and non-interactive.
4. Tap the note icon → a modal dialog opens with the selected text (read-only preview at top) and a multi-line text field.
5. Tap "Save" → dialog closes, the selected span is highlighted in blue (`Color(0xFF64B5F6)`), and a `HighlightModel` with `noteText` set is persisted via `HighlightStorage.addOrUpdate`. The toolbar collapses (selection cleared).
6. The blue anchor remains visible on subsequent reads of that page; tapping the anchored span (later) re-opens the note dialog (see alternative flow) — at minimum for MVP, plain blue highlight is rendered; tapping to re-open is a nice-to-have and is out of scope unless time permits.

Primary flow (review notes):
1. From the reader AppBar, tap the new three-dots overflow icon (`Icons.more_vert`).
2. Menu shows: "Notes", "Export Markdown…", "Export JSON…".
3. Tap "Notes" → pushes `NotesListScreen` showing all notes for the current `bookId`, grouped/sorted by chapter index ascending then position.
4. Each row shows: chapter title (or "Chapter N"), the anchored selected text (truncated), and the note text. Tapping a row is a nice-to-have "jump to chapter" (out of MVP scope); a delete affordance (swipe or trailing icon) removes the note.
5. Empty state: "No notes yet for this book." with no export actions active.

Primary flow (export):
1. Reader AppBar three-dots → "Export Markdown…" (or JSON).
2. `FilePicker.platform.saveFile(...)` opens with `dialogTitle`, default `fileName` e.g. `notes_<safeBook>_<yyyyMMdd_HHmm>.md`, `filesExtensions` (`['md']` / `['json']`).
3. On user cancel: snackbar "Export cancelled". Do not write.
4. On confirm: library builds the content (markdown or JSON) from `CosmosEpub.getBookNotes(bookId)` and writes bytes to the returned path.
5. Snackbar "Notes exported to <filename>". On failure: snackbar "Export failed: <error>".

Alternative flows:
- Tap note icon with NO selection: icon is disabled (grey `Colors.white24`, `onTap` guard returns early). No dialog.
- Cancel note dialog: no highlight and no record written; the selection stays highlighted only if user then taps a color dot; otherwise dismissed.
- Export with zero notes: "Export Markdown…" and "Export JSON…" menu items are disabled/greyed (or, if tapped, immediately show snackbar "No notes to export"). Pick one and apply consistently.

Error flows:
- Note persistence failure (GetStorage write error): swallow storage error and show snackbar "Could not save note"; do NOT leave a dangling blue highlight (atomic: build the `HighlightModel`, then `addOrUpdate`; if `addOrUpdate` throws, show error, no `setState`).
- Export save dialog returns `null` (cancelled): snackbar "Export cancelled".
- Export write throws (`FileSystemException`): snackbar "Export failed: <e>".
- FilePicker unavailable (platform missing plugin): guard in try/catch → snackbar "Export unavailable on this platform".

Entry/exit:
- Entry to notes flows is the reader (`ShowEpub`) AppBar only for MVP.
- Exit: back from `NotesListScreen` → reader is unchanged (notes removed via swipe update the backing list and the AppBar remains).
</user_flows>

<requirements>
**Functional:**
1. Reduce `highlightColors` in `lib/Component/highlight_toolbar.dart` to exactly three entries: yellow `Color(0xFFFFEB3B)`, green `Color(0xFF81C784)`, red `Color(0xFFE57373)`. Remove blue/orange/purple. Do not regress the visual layout of `_PageToolbar` or `HighlightToolbar`.
2. Extend `HighlightModel` (`lib/Model/highlight_model.dart`) with an optional `String? noteText` field (default `null`). Update `toJson`/`fromJson` to round-trip `noteText` (default empty/`null`). Keep backward compatibility with existing JSON entries (missing key → `null`).
3. Add a `bool get isNote => noteText != null && noteText!.isNotEmpty;` getter to `HighlightModel` for reuse. Also add a `Color noteAnchorColor = const Color(0xFF64B5F6);` constant (in `highlight_toolbar.dart` or `highlight_model.dart`) used for note-anchors.
4. Add note query helpers to `HighlightStorage`: `getBookNotes(String bookId)` returning all entries where `isNote` is true; `removeNote(id)` delegates to existing `removeHighlight` (or alias). Add to public API `CosmosEpub.getBookNotes(bookId)` and `CosmosEpub.removeNote(id)` in `lib/cosmos_epub.dart`.
5. In `_PageToolbar` (`lib/Helpers/pagination.dart`), add a new `VoidCallback onTakeNote` callback and a `bool selectionAvailable` flag (or pass the current selection text down). Render a note icon after the color dots + divider, before copy. When `!selectionAvailable` render the icon with `Colors.white24` and a guard so `onTakeNote` does not fire. Disabled icon still displays.
6. In `_HighlightablePageState.build`'s `contextMenuBuilder`, wire `onTakeNote` to a new `_takeNote()` method that shows a dialog (`showDialog<String?>`) with the selected-text preview and a `TextField`. On non-empty result, build a `HighlightModel` with `noteText` set and the blue anchor color, persist via `HighlightStorage.addOrUpdate`, call `setState`, and clear focus (`FocusManager.instance.primaryFocus?.unfocus()`). Reuse the offset-resolution logic from `_addHighlight` (extract a private `_resolveSelectionRange(String text)` returning `({int start, int end})` or `-1`) — refactor `_addHighlight` and `_takeNote` to share that helper to avoid drift.
7. In the reader AppBar (`lib/show_epub.dart` ~line 824 `actions`), append a `PopupMenuButton<String>` with `Icon(Icons.more_vert)` keyed `Key('reader_overflow_menu')`. Items: `notes` (label "Notes"), `export_md` (label "Export Markdown…"), `export_json` (label "Export JSON…"). On select: push `NotesListScreen(bookId: widget.bookId, ...)` or invoke the exporter.
8. Create `lib/Component/notes_list_screen.dart` exporting `NotesListScreen` (a `StatefulWidget`). It reads `CosmosEpub.getBookNotes(widget.bookId)` in `initState`/`didChangeDependencies`; renders a `ListView` of `ListTile`s whose `title` is the note text, `subtitle` is "Ch. N · <selected text>" (truncated to ~60 chars, ellipsis). Provide a trailing delete `IconButton(Icons.delete_outline)` that removes via `CosmosEpub.removeNote(id)` and refreshes state. Empty state widget as described. Add stable keys: `Key('notes_list')`, per-row `Key('note_$id')`, delete button `Key('note_delete_$id')`.
9. Create `lib/Helpers/note_exporter.dart` exporting two pure functions:
   - `String notesToMarkdown(String bookTitle, List<HighlightModel> notes)` producing, e.g.:
     ```markdown
     # Notes — <bookTitle>

     ## Chapter N — <chapterTitle?>
     > <selectedText>

     <noteText>

     ---
     ```
   - `String notesToJson(String bookTitle, List<HighlightModel> notes)` producing a JSON array (`jsonEncode`) of each note's `{chapterIndex, selectedText, noteText, paragraphKey, startIndex, endIndex}` plus a top-level object `{book: bookTitle, exportedAt: ISO8601, notes: [...]}`.
   - Both must be pure, no I/O, deterministic aside from `exportedAt` (use an injectable `DateTime Function()` clock seam, default `DateTime.now`).
10. The example app (`7epubs`) does NOT need AppBar changes per the scope decision; the three-dots menu lives in the library's `ShowEpub` reader AppBar. (Note the deviation from the literal change-request wording, confirmed during spec authoring.)

**Error Handling:**
11. Note save/storage failures → snackbar "Could not save note"; never leave a visual anchor with no persisted record (write first, then `setState`).
12. Export cancel → snackbar "Export cancelled"; export fail → "Export failed: <error>".
13. Notes list query errors (GetStorage corruption) → render empty state rather than crashing (wrap in try/catch consistent with `_readAll` patterns).
14. Disabled states: note icon disabled when no selection; export menu items disabled/snip when notes empty (choose one + apply consistently; recommended: enabled but show snackbar "No notes to export" when tapped, simpler than `itemEnabled`).

**Edge Cases:**
15. Selection spans soft-hyphenated or hyphenated text: the offset resolution must reuse the same normalization that `_addHighlight` uses (`replaceAll('\u00AD','')`, collapse whitespace) — do NOT special-case note matching.
16. Re-highlighting an existing selection as a note: if `_resolveSelectionRange` finds an identical `(bookId, chapterIndex, paragraphKey, start, end)` highlight already present, replace its `colorValue` with blue and set its `noteText` (reuse `HighlightStorage.addOrUpdate` which already dedupes by those fields). Do not create a duplicate record.
17. Note on a selection that previously had a yellow/green/red highlight: same replacement as above — taking a note upgrades the existing record (color → blue, noteText set). Acceptable per design; document this behavior.
18. Empty book (`widget.bookId.isEmpty`, same guard `_addHighlight` uses at line 457): `onTakeNote` no-ops.
19. Dialog dismissed by back gesture / barrier tap: returns `null`/empty → no save, no `setState`.
20. Concurrent note + highlight on overlapping spans: out of scope; existing `addOrUpdate` dedupe-by-exact-position wins.

**Validation:**
21. The note dialog rejects empty `noteText` on Save (disabled "Save" button OR snackbar "Note cannot be empty"). Recommended: disable Save button while text is empty.
22. Exported markdown must be valid markdown that round-trips to readable text; exported JSON must `jsonDecode` back to a list with matching counts.
23. Removed color dots (blue/orange/purple) never render anywhere `_PageToolbar`/`HighlightToolbar` is used.
</requirements>

<boundaries>
Edge cases:
- Selection across multiple paragraphs: out of scope. `_PageToolbar` is shown per `SelectionArea`; only single-paragraph anchored notes are MVP. If the resolved range spans zero paragraphs (only intra-block), proceed. If `_resolveSelectionRange` returns `-1` show snackbar "Could not anchor note here" and abort cleanly.
- Note on chapter title page (no content blocks): `onTakeNote` no-ops just as `_addHighlight` does for empty selections.
- Notes with selectedText > ~200 chars: store fully; UI truncates with ellipsis. No hard limit MVP.

Error scenarios:
- GetStorage JSON corrupt → `HighlightStorage._readAll` already returns `[]`. Notes export/list degrade to empty; do not throw.
- `file_picker` plugin missing on a platform → export menu items catch `MissingPluginException` and show "Export unavailable on this platform".
- User backgrounds the app mid-dialog → Flutter preserves dialog state; on resume nothing special required.
- Writing export to a path the OS rejects (permissions) → caught `FileSystemException`, snackbar shown.

Limits:
- No pagination/infinite virtualization for notes list MVP (realistic note counts are small). If `getBookNotes` returns >500 entries, still fine with `ListView.builder`; document that no chunking is added.
- No localization MVP → all strings in English, hardcoded.
- No filtering/search on the notes list MVP (nice-to-have; spec'd out).
</boundaries>

<implementation>
Files to create:
- `lib/Component/notes_list_screen.dart` — `NotesListScreen` StatefulWidget as described.
- `lib/Helpers/note_exporter.dart` — pure `notesToMarkdown` + `notesToJson`.

Files to modify:
- `lib/Component/highlight_toolbar.dart` — trim `highlightColors` to 3; add `const Color noteAnchorColor = Color(0xFF64B5F6);`.
- `lib/Model/highlight_model.dart` — add `noteText` field + `isNote` getter; update `toJson`/`fromJson`; add `HighlightStorage.getBookNotes` + alias `removeNote`; (optional) bump storage key versioning only if a migration is needed — RECOMMENDED: keep key `cosmos_highlights_v2` since `noteText` is additive and `fromJson` defaults it to `null`.
- `lib/Helpers/pagination.dart` — refactor `_addHighlight` to extract `_resolveSelectionRange`; add `_takeNote` + dialog; extend `_PageToolbar` with `onTakeNote`/`selectionAvailable`; wire in `contextMenuBuilder` (line ~560).
- `lib/show_epub.dart` — add `PopupMenuButton` overflow to `actions` (line ~824); handlers route to `NotesListScreen` and the exporter (`FilePicker.platform.saveFile`).
- `lib/cosmos_epub.dart` — add `getBookNotes(String bookId)` and `removeNote(String id)` public methods.

Patterns:
- Reuse `HighlightStorage` GetStorage JSON pattern; do not introduce a second storage key.
- Keep `_PageToolbar` a pure `StatelessWidget`; pass callbacks and the `selectionAvailable` bool from the stateful `_HighlightablePageState`.
- Use `file_picker`'s `saveFile` API (already a `7epubs` dependency; the library should import it guarded so consumers without it can still build — wrap the export invocation so the example app's instance is used via a callback seam; OR add `file_picker` as a library dep — RECOMMENDED: add `file_picker: ^8.0.0` to the library `pubspec.yaml` to keep UI in-library; re-run `fvm flutter pub get`).

Avoid:
- New state-management libraries (Riverpod/Bloc) — out of scope; plain `setState` matches existing patterns.
- Touching the Drift schema or reading-progress service.
- Platform-specific native code; `file_picker` already abstracts `saveFile`.
- Internationalization/plurals.
- Web targets (unsupported per AGENTS.md).

Code generation:
- No Drift build_runner run is needed (schema unchanged).
- No `.g.dart` regeneration required for `HighlightModel` (it is plain Dart).
</implementation>

<validation>
Automated coverage baseline (the repo currently has no test infra; `flutter_test` is in dev deps). Spec requires WILL-ADD coverage:

Logic unit tests (no Flutter binding needed where possible; `HighlightModel`/`NoteExporter` are pure Dart):
- `HighlightModel.toJson/fromJson` round-trips `noteText` (non-null and absent→null).
- `HighlightModel.isNote` true iff `noteText` is non-blank.
- `HighlightStorage.getBookNotes` filters only `isNote` rows (use a `GetStorage` fake or refactor `_readAll` to accept an injectable reader; add a `@visibleForTesting` constructor or static seam).
- `notesToMarkdown` produces expected heading + one section per note; empties/long-text/unicode-safe.
- `notesToJson` output `jsonDecode`s to a structure with `book`, `exportedAt`, and matching `notes.length`; rejects no input.

UI behavior widget tests (`flutter_test`):
- `HighlightToolbar` renders exactly 3 color dots (find `Container` circles by background color count via `find.byWidgetPredicate`).
- `_PageToolbar` note icon is present; tapping it invokes `onTakeNote` when `selectionAvailable`; when not, tap is a no-op (verify callback not called).
- `NotesListScreen` with faked `CosmosEpub.getBookNotes`: shows rows per note; tapping delete calls `CosmosEpub.removeNote(id)` and removes the row; empty-input list shows the empty-state text.
- Export menu: tapping "Export Markdown…" with no notes shows "No notes to export" snackbar (or button disabled — match chosen behavior).

Critical journey coverage (robot-driven optional; project has no robot infra yet — note as risk):
- Open reader → select text → take note → see blue anchor → open notes list → see entry → delete entry → reopen list → empty state.
- EXPRESSED as a single integration robot test target in `7epubs/test/` or `test/` once a robot harness exists; if not feasible in this change, REQUIRE at minimum a widget-level test that drives the note dialog → save → notes-list contains the row (uses faked storage seam).

Testability seams required:
- `NoteExporter` functions are pure → trivially unit-testable.
- `HighlightStorage._readAll/_writeAll` must be overridable for tests: expose a `@visibleForTesting` static `GetStorage Function()? storageProvider` (default `_gs`) OR refactor `HighlightStorage` methods to accept a `GetStorage` parameter (recommended the smaller change: a `static @visibleForTesting set storage(GetStorage gs)`). The plan should pick exactly one seam and apply it consistently.
- `ShowEpub`/`NotesListScreen` must obtain notes via `CosmosEpub.getBookNotes` (a static facade). For widget tests, allow injecting a `NoteProvider` callback into `NotesListScreen` (e.g. `NotesListScreen({required this.bookId, this.noteProvider})` defaulting to `CosmosEpub.getBookNotes`). This seam is REQUIRED so screen-level tests are deterministic without spinning up GetStorage.
- `FilePicker` is a true external boundary — mock via `FilePicker.setMockFilePickerResult(...)` (existing test seam in the package) for export widget tests, or keep export logic in pure helper + test only the helper + the menu plumbing separately.

TDD-first expectations:
- Behavior order (one test → minimal code at a time):
  1) `noteText` round-trip → add field.
  2) `isNote` getter → add getter.
  3) `getBookNotes` filters → add method + storage seam.
  4) `notesToMarkdown`/`notesToJson` → implement exporter.
  5) `_PageToolbar` renders note icon w/ disabled state → add icon.
  6) `_PageToolbar` tap w/ selection calls `onTakeNote` → wire callback.
  7) `_takeNote` saves a blue-anchored `HighlightModel` with `noteText` (use storage seam) → implement dialog + persistence, sharing `_resolveSelectionRange`.
  8) `NotesListScreen` lists/deletes notes (via injected `noteProvider`) → implement screen.
  9) Overflow menu routes to those two → implement AppBar wiring.

Manual verification (since CI/tests absent today):
- `fvm flutter pub get` then `fvm flutter run` (or example app) on macOS.
- Select a word in `book_nested.epub`, take note "lorem", confirm blue anchor persists after navigation away+back.
- Tap three-dots → Notes → verify entry; delete → verify gone.
- Three-dots → Export Markdown… → pick destination → open file in a text editor → verify content.
- Three-dots → Export JSON… → save → `python3 -m json.tool out.json` validates ≠ errors.
- Verify the toolbar now shows only 3 color dots; orange/purple/blue gone.

Required test-type mapping (baseline outcomes this spec REQUIRES):
- Unit: `HighlightModel` + `HighlightStorage` filter + `NoteExporter` (deterministic, fast).
- Widget: `_PageToolbar`/`HighlightToolbar` dot count + note icon states; `NotesListScreen` list/delete using injected `noteProvider` seam; overflow menu snackbar empty-notes path.
- Journey/Robot (stretch, flag risk if unmet): full take-note → list → delete trip; export skip-when-empty; export success path with a fake file-picker.

`<done_when>` is a distinct tag below — do not duplicate.
</validation>

<stages>
Phase 1 — Data model + storage (no UI): extend `HighlightModel`, add `getBookNotes`/`removeNote`, add storage test seam. Verify: unit tests green for round-trip + filtering.
Phase 2 — Exporter: implement `note_exporter.dart`. Verify: unit tests green for markdown + JSON shape; `jsonDecode` round-trips.
Phase 3 — Toolbar note icon: trim palette to 3; refactor `_resolveSelectionRange`; add note icon + disabled state to `_PageToolbar`; wire `onTakeNote`. Verify: widget tests for icon presence/disabled/tap; manual blue-anchor verification.
Phase 4 — `_takeNote` dialog + persistence: implement dialog; reuse `_resolveSelectionRange`; persist blue-anchored record with `noteText`. Verify: widget test that saving produces a row found via storage seam (and `getBookNotes`); manual blue anchor persists across page-flips.
Phase 5 — Public API: add `CosmosEpub.getBookNotes`/`removeNote`; add `file_picker` to library `pubspec.yaml`. Verify: `fvm flutter pub get` succeeds; `dart analyze` clean.
Phase 6 — Notes list screen: `NotesListScreen` + injected `noteProvider` seam + delete. Verify: widget test list/delete/empty.
Phase 7 — Reader AppBar overflow menu: add `PopupMenuButton` routing to list + exporter with `saveFile`. Verify: widget test menu items present + empty-notes snackbar; manual export on macOS succeeds for both formats.
</stages>

<done_when>
- `highlightColors` contains exactly 3 colors; no blue/orange/Purple render anywhere in `_PageToolbar` or `HighlightToolbar`.
- A user can select text, tap the note icon, enter a note, and the selection becomes a blue anchor that persists across reads.
- `CosmosEpub.getBookNotes(bookId)` returns notes (records with non-blank `noteText`); `CosmosEpub.removeNote(id)` removes them.
- The reader AppBar three-dots menu offers Notes, Export Markdown, Export JSON scoped to the open book; export writes a valid `.md`/`.json` via a `saveFile` dialog; cancel/fail paths show snackbars.
- Required unit and widget tests are added and pass under `fvm flutter test`; `fvm flutter analyze` is clean; `7epubs` example builds and runs on macOS.
</done_when>