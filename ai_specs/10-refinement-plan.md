## Overview

Fix 3 notes bugs: edit existing note from context menu, macOS markdown export crash, JSON export false-negative. Single-phase fix — all changes in 2 files, low risk.

**Spec**: `ai_specs/10-refinement_notes.md` (read for full requirements)

## Context

- **Structure**: feature-first (Helpers/, Model/, Component/)
- **State management**: ad-hoc (global state + setState + GetStorage)
- **Reference implementations**: `lib/Helpers/pagination.dart:567` _takeNote, `lib/show_epub.dart:1096` _handleExport, `lib/Model/highlight_model.dart:85` addOrUpdate
- **Assumptions/Gaps**: none blocking

## Plan

### Phase 1: Fix all 3 notes bugs

- **Goal**: Edit existing notes from context menu; export works on macOS for both formats

- [ ] `lib/Helpers/pagination.dart` — modify `_takeNote()` to check for existing note at resolved selection range before showing dialog; if found, pre-populate text field with existing `noteText`, title = "Edit Note", reuse existing `HighlightModel.id` on save
- [ ] `lib/show_epub.dart` — in `_handleExport()`, remove `bytes:` param from `FilePicker.platform.saveFile()` (unsupported on macOS); rely on existing `file.writeAsBytes()` path
- [ ] `lib/show_epub.dart` — in `_handleExport()`, replace flawed `content.isEmpty \|\| (!content.contains('---'))` check with `HighlightStorage.getBookNotes(bookId).isEmpty` before building content
- [ ] Verify: `flutter analyze lib/` && `cd 7epubs && flutter analyze lib/`

## Risks / Out of scope

- **Risks**: `_resolveSelectionRange` may produce null for edge-case soft-hyphen text — existing note lookup could miss match. Fall back to "Add Note" dialog if no match found (already handled).
- **Out of scope**: Notes list screen editing, rich text notes, cloud sync
