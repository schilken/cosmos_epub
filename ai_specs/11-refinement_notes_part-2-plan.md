## Overview

Add tap-to-navigate on `NotesListScreen` items: pop back to reader, jump to the chapter/page containing the note. Show `startIndex` in the subtitle.

**Spec**: `ai_specs/11-refinement_notes_part-2.md`

## Context

- **Structure**: layer-first (lib/ `Component/`, `Helpers/`, `Model/`)
- **State management**: setState + global state (no Riverpod/BLoC)
- **Reference implementations**: `lib/Helpers/search_bottom_sheet.dart:225-281` (result tap → `onResultTapped` callback), `lib/show_epub.dart:572-599` (`_onSearchResultTapped` → `findPageContainingMatch` → `jumpToChapter`)
- **Assumptions**: navigation reuses existing `findPageContainingMatch` from `search_service.dart` to locate the page for a given `startIndex`

## Plan

### Phase 1: NotesListScreen tap-to-navigate

- **Goal**: tapping a note in the list pops back and opens the reader to the page containing the note; subtitle shows startIndex

- [x] `lib/Component/notes_list_screen.dart` — add `final void Function(HighlightModel)? onNoteTapped` param; wrap `ListTile` with `InkWell` or set `ListTile.onTap` → `widget.onNoteTapped?.call(note)` then `Navigator.pop(context)`. Update subtitle to include `startIndex` after chapter name: `'Ch. ${note.chapterIndex + 1} (idx: ${note.startIndex}) · ...'`
- [x] `lib/show_epub.dart` — pass `onNoteTapped` callback to `NotesListScreen` at the push site (~line 1049). In callback: `Navigator.pop(context)` first, then `jumpToChapter(note.chapterIndex, pageIndex)` where `pageIndex = findPageContainingMatch(controllerPaging.pageHtmlFragments, note.startIndex, note.endIndex)`. If different chapter, reload chapter first then find page in post-frame callback (mirror `_onSearchResultTapped` pattern at line 572-598).
- [x] TDD: tapping a note calls `onNoteTapped` with the correct `HighlightModel` → update widget test. Verify: `flutter test test/component/notes_list_screen_test.dart`
- [x] TDD: callback in `show_epub.dart` calls `jumpToChapter` with correct chapter/page → verify via integration/unit test or manual run. (Implemented mirroring `_onSearchResultTapped` pattern; manual run verification recommended.)
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `findPageContainingMatch` works on plain-text character offsets but `startIndex` is paragraph-relative; may need to account for intra-paragraph positioning vs. page-level offset accumulation. If mismatch, fall back to `pageIndex = 0` (same as search).
- **Out of scope**: highlighting/marking the note position visually after navigation (search already has its own highlight overlay).
