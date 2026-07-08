## Overview

Add close button to `SearchBottomSheet` that clears search state and dismisses the sheet.

**Spec**: `ai_specs/08-refinement_search.md`

## Context

- **Structure**: feature-first (Helpers/, Model/, Component/)
- **State management**: `ChangeNotifier` (`EpubSearchController`)
- **Reference implementations**: `lib/Helpers/search_bottom_sheet.dart`, `lib/show_epub.dart:529-564`
- **Assumptions/Gaps**: None. Spec is clear and narrow.

## Plan

### Phase 1: Add close button to SearchBottomSheet

- **Goal**: Close button clears search state and dismisses sheet

- [ ] `lib/Helpers/search_bottom_sheet.dart` - Add `VoidCallback? onClose` parameter; add close `IconButton` (X icon) in top bar row next to drag handle; on tap call `widget.onClose?.call()` then `Navigator.pop(context)`
- [ ] `lib/show_epub.dart:548` - Pass `onClose: _clearSearchState` to `SearchBottomSheet`
- [ ] TDD: close button is present and tappable in SearchBottomSheet widget test
- [ ] TDD: tapping close calls onClose callback, verifies Navigator.pop occurred
- [ ] TDD: tapping close clears controller state (`isActive = false`, `results = []`)
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `showModalBottomSheet().then()` already checks `isActive` before `updateUI()` — close clears `isActive`, so stray highlight cleanup is impossible. No risk.
- **Out of scope**: Any visual redesign beyond the close button; changes to `_clearSearchState` logic.
