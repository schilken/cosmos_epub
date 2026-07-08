---
type: Work Item
parent: spec.md
---

## What to build

Build the `SearchBottomSheet` widget, integrate it into the reader AppBar, implement the "Back to search results" button, wire up result tap → jump-to-chapter → reshow flow, and add widget/journey tests.

### Files to create/modify
- `lib/Helpers/search_bottom_sheet.dart` — `SearchBottomSheet` StatefulWidget.
- `lib/show_epub.dart` — add search icon to AppBar, add "Back to search results" button logic, create `EpubSearchController` in `initState`, wire up result tap.
- `test/search_bottom_sheet_test.dart` — widget tests.

### SearchBottomSheet widget
- Accepts: `List<LocalChapterModel> chapters`, `EpubSearchController searchController`, `Color accentColor`, `void Function(SearchResult) onResultTapped`.
- Layout (top to bottom, within the bottom sheet):
  - **Input field**: `TextField` with key `search_input_field`, auto-focused (`autofocus: true`), with a clear button (`suffixIcon`). Debounce input (300ms) before calling `searchController.search()`.
  - **Content area** (takes remaining height):
    - **Loading**: centered `CircularProgressIndicator` / `CupertinoActivityIndicator` using `accentColor` — shown when `searchController.isLoading`.
    - **Error**: centered text "Please enter a search term" — shown when `searchController.errorMessage` is set and no results.
    - **Empty**: centered "No results found" — shown when `searchController.isLoading` is false, no error, and results list is empty.
    - **Results**: `ListView.builder` with key `search_results_list` — shown when results list is non-empty. Each item displays:
      - `contextBefore` (dimmed/truncated)
      - `matchedText` (bold or highlighted)
      - `contextAfter` (dimmed/truncated)
    - Tapping a result calls `onResultTapped(result)` and dismisses the bottom sheet via `Navigator.pop(context)`.
- Opened via `showModalBottomSheet(isScrollControlled: true, enableDrag: true, ...)`.
- Uses `Builder` in the sheet to detect keyboard via `MediaQuery.of(context).viewInsets.bottom` and pad accordingly.

### AppBar integration (in ShowEpubState)

**Search icon (default state):**
- Add an `IconButton` with `Icons.search`, key `search_button`, to the AppBar `actions` list, positioned before the overflow menu (`PopupMenuButton`).
- Condition: visible only when `_searchController.isActive == false` (no active search results) and the search bottom sheet is not currently open.

**Opening the bottom sheet:**
- On tap, create the bottom sheet, passing `chaptersList`, `_searchController`, `widget.accentColor`, and a callback for result taps.
- If `_searchController` has saved state from storage, load it first (`_searchController.loadFromStorage(bookId)`).
- After the bottom sheet is dismissed, if a result was tapped, transition to post-navigation state.

**"Back to search results" button (post-navigation state):**
- After a result is tapped and the reader navigates to the target chapter, replace the leading back button with an `IconButton` with platform-appropriate back icon, key `back_to_search_button`, tooltip "Back to search results".
- Condition: visible when `_searchController.isActive == true` and `_searchController.results.isNotEmpty`.
- On tap: reopen the bottom sheet with the same controller (results still loaded).
- While the bottom sheet is open, tapping `back_to_search_button` again closes the sheet and restores the standard back button.

**Standard back button restoration:**
- When the user navigates to a different chapter via prev/next or TOC (not via search), clear the search state and restore the standard back button.

### Search → navigate flow
1. User taps a result in the bottom sheet.
2. The result tap callback runs `findPageContainingMatch()` with the target chapter's paginated HTML to determine `pageIndex`.
3. If `pageIndex == -1` (match not found in any page), fall back to 0.
4. Call `CosmosEpub.jumpToChapter(bookId, chapterIndex, pageIndex)` (or the GlobalKey direct call).
5. Set `_searchController.isActive = true`, persist state via `_searchController.saveToStorage(bookId)`.
6. AppBar updates to show `back_to_search_button` replacing the leading back button.

### On reader re-entry (persisted state)
- In `ShowEpubState.initState`, after loading preferences, check `GetStorage` for `${libSearchPrefix}${bookId}`.
- If saved state exists, call `_searchController.loadFromStorage(bookId)` and set `isActive = true`.
- This causes the "Back to search results" button to appear immediately.

### Keyboard handling
- `SearchBottomSheet` uses a `Builder` to read `MediaQuery.of(context).viewInsets.bottom`.
- The sheet content is padded by `viewInsets.bottom` so the input field and results stay visible above the keyboard.

## Required context

- `lib/show_epub.dart:797-926` — AppBar structure: leading (back button), actions (TOC button, "Aa", brightness, PopupMenuButton). Insert search icon before the overflow menu.
- `lib/show_epub.dart:115` — `initState` calls `loadThemeSettings()` then `reLoadChapter(init: true)`. Add search state hydration here.
- `lib/show_epub.dart:144` — `reLoadChapter` is called on init, TOC pop, prev/next. When prev/next is used, clear search state.
- `lib/show_epub.dart:199` — `setupNavButtons()` sets `showPrevious`/`showNext`. Clean search state in prev/next paths.
- The `ShowEpub` widget already has `backColor` and `fontColor` globals (lines 51-52) — the sheet colors should match the reader theme.
- `flutter_screenutil` is available: use `.sp`, `.w`, `.h` for sizing in the bottom sheet.
- Existing `CosmosEpub.clearThemeCache()` resets GetStorage keys for theme only — search state should survive theme changes.

## Acceptance criteria

- [ ] `SearchBottomSheet` widget renders with auto-focused input field (key: `search_input_field`).
- [ ] Debounced input (300ms) triggers `searchController.search()`.
- [ ] Loading state: centered spinner with `accentColor` during search.
- [ ] Error state: "Please enter a search term" for empty query.
- [ ] Empty state: "No results found" when search returns no matches.
- [ ] Results list (key: `search_results_list`) displays context before, match text (bold), and context after.
- [ ] Tapping a result calls `onResultTapped` and dismisses the sheet.
- [ ] Bottom sheet draggable (swipe to dismiss), dismissible via backdrop tap.
- [ ] Keyboard-aware height: content stays above keyboard.
- [ ] Search icon (key: `search_button`) appears in AppBar actions, before the overflow menu, only when no active search results.
- [ ] "Back to search results" button (key: `back_to_search_button`) replaces leading back button after result navigation.
- [ ] Tapping `back_to_search_button` reopens bottom sheet with previous results intact.
- [ ] Standard back button restored when user navigates via prev/next or TOC.
- [ ] On reader re-entry with persisted search state, `back_to_search_button` appears immediately.
- [ ] Widget tests pass: state transitions (idle → loading → results → empty → error), input field focus, result tap callback, keyboard padding.
- [ ] Widget tests pass: AppBar search icon visibility, "Back to search results" button swap and tap behavior.
- [ ] `fvm flutter run` from `7epubs/` — full search flow works end-to-end.

## Covers

- User Stories: 1, 2, 3, 4, 7, 8
- Requirements: 3, 6, 11, 12, 13, 14
- Tech Decisions: 6, 9
- Interview Ledger: L3, L5, L6, L12, L13

## Blocked by

1 — Search data layer (Work Item 1)
2 — Search state management (Work Item 2)
3 — Chapter jump navigation (Work Item 3)
