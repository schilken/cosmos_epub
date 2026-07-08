---
type: Spec
title: Add Full-Text Search in EPUB Reader
---

## Problem

The 7epubs EPUB reader app has no search functionality. Users cannot find specific text within an open EPUB book. They need to locate words, phrases, or passages across all chapters, then navigate directly to the page containing a match.

## Proposed Outcome

Add a search feature accessible from a magnifying-glass icon (`Icons.search`) in the reader AppBar actions, placed before the existing overflow menu. The user types a search string, sees all matching spots across every chapter in a modal bottom sheet results list with a character-window context preview, taps a result to jump to that exact page with the search term visible, and can return to search results at any time from the reading view via a "Back to search results" icon button replacing the leading back button in the AppBar after navigation.

## User Stories

1. As a reader, I can tap a search icon in the reader AppBar to open a search input and type a search term to find text within the EPUB.
2. As a reader, I see all matching occurrences across the entire EPUB in a modal bottom sheet results list, each showing the match with ~100 characters of context before and after.
3. As a reader, I can tap any result to navigate directly to the page containing that match, with the search term visible in the reading view.
4. As a reader, I can return to the search results after viewing a match via a "Back to search results" button in the AppBar, without losing my search state.
5. As a reader, I see a loading indicator while the search runs across all chapters.
6. As a reader, I see a clear empty state when no matches are found and an error message for empty queries.
7. As a reader, I can dismiss the search bottom sheet by swiping down, tapping a semi-transparent backdrop, or pressing the device back button.
8. As a reader, starting a new search while one is already running cancels the previous search and begins the new one.

## Requirements

1. Search must be case-insensitive by default. [L1]
2. Search must include chapter headings and body text. Metadata (book title, author, etc.) is excluded. [L2]
3. Search results must be displayed in a draggable modal bottom sheet (`showModalBottomSheet`) over the reading screen, dismissible via swipe-down, backdrop tap, or device back button. [L3]
4. Search must run across all chapters in the EPUB, not just the currently displayed chapter. [L4]
5. Each result must show ~100 characters of text before the match, the match text itself, and ~100 characters of text after the match, extracted from the chapter plain text (HTML body content stripped of tags). Context extends to the nearest word boundary or paragraph boundary — no mid-word truncation. [L10]
6. Tapping a result must navigate the reader to the page containing that match. After navigation, the leading back button in the AppBar must be replaced with a "Back to search results" icon button (`Icons.arrow_back` or platform-appropriate back icon) with tooltip "Back to search results" and key `back_to_search_button`. Tapping it reopens the search bottom sheet with the previous results list intact. [L5] [L6]
7. Search state (query string, results, active result index) must persist in GetStorage keyed by `bookId`, using a constant key defined in `lib/Component/constants.dart` alongside existing storage keys (`libTheme`, `libFont`, `libFontSize`). The key name is `libSearchPrefix` = `"search_results_"`. State survives navigation away from the reader and app restart. On reader re-entry, if saved search state exists, the "Back to search results" button must appear in the AppBar immediately (no search icon needed since results already exist). [L7]
8. The reader must support chapter-level navigation that bypasses the sequential prev/next flow. `ShowEpub` must expose a public `jumpToChapter(int chapterIndex, int pageIndex)` method on its State, accessible externally via a `GlobalKey<ShowEpubState>` held by `CosmosEpub`. This method sets `_currentChapterIndex` and `_currentPageIndex` in `ShowEpubState`, stores both in `DriftProgressService`, and triggers `reLoadChapter(index: chapterIndex)` followed by page-level navigation to `pageIndex` after pagination completes. [L8]
9. When jumping to a target chapter for a search result, the reader must scan the target chapter's paginated HTML pages using a freshly-instantiated `HtmlPaginator` (matching the reader's current `pageWidth`, `pageHeight`, `fontSize`, `fontFamily`, and `textDirection`). Each page's HTML is parsed to plain text and checked for the presence of the match text. The page whose plain text first contains the match becomes the target page index. If the match cannot be found in any page, fall back to page 0 (chapter start). [L9]
10. Empty or blank search queries must show an error message "Please enter a search term" in the results area of the bottom sheet (replacing the results/list/loading state). [L11]
11. An active cross-chapter search must show a loading indicator (`CircularProgressIndicator` or `CupertinoActivityIndicator`) centered in the results area of the bottom sheet, using the accent color from `ShowEpub.accentColor`. [L12]
12. When zero matches are found, display a centered "No results found" message in the results area of the bottom sheet. [L13]
13. If a chapter's HTML content cannot be parsed to plain text (malformed HTML), skip that chapter silently and continue searching the remaining chapters. [L14]
14. The search input field in the bottom sheet must auto-focus on open, showing the keyboard immediately. The bottom sheet height must adapt to keyboard visibility. [L15]

## Technical Decisions

1. **Search service**: Create `SearchService` in `lib/Helpers/search_service.dart` that receives a `List<LocalChapterModel>` from `ShowEpubState` (via the `chaptersList` field). For each chapter, extracts plain text from `htmlContent` via `html_parser.parse()`, performs case-insensitive substring matching with `String.indexOf()`, and returns a list of `SearchResult` objects. [L4]

2. **Search results model**: Define `SearchResult` in `lib/Model/search_result.dart` with fields:
   - `int chapterIndex`
   - `int matchStart` — character offset in plain text
   - `int matchEnd` — character offset in plain text
   - `String matchedText`
   - `String contextBefore` — ~100 characters before match, word-boundary aligned
   - `String contextAfter` — ~100 characters after match, word-boundary aligned
   - `int? pageIndex` — nullable, resolved at navigation time (set by the page-index computation step)
   The `pageIndex` field is initially `null` and is populated when the user taps the result and the reader resolves which paginated page contains the match. [L8] [L9]

3. **Storage**: Persist search results in `GetStorage` under key `${libSearchPrefix}$bookId` where `libSearchPrefix` is a new constant in `lib/Component/constants.dart`. Each entry stores a JSON-serialized map: `{"query": "...", "results": [...], "activeResultIndex": 0}`. Hydrate on reader entry (check in `ShowEpub.initState`), clear on new search. [L7]

4. **Page index computation**: Extract a pure function `findPageContainingMatch(List<String> pageHtmlFragments, String matchText)` that takes the output of `HtmlPaginator.paginate()` and the match text, parses each page fragment to plain text, returns the index of the first page containing the match, or `-1` if not found. Export this function as a Test Seam. The `HtmlPaginator` instance inside `ShowEpubState` is re-run for the target chapter using the widget's current font/page dimensions. [L9]

5. **Chapter navigation architecture**: 
   - Add a `GlobalKey<ShowEpubState>` to the `CosmosEpub` class, assigned when the `ShowEpub` widget is created in `_openBook()`.
   - `ShowEpubState` exposes a public method: `void jumpToChapter(int chapterIndex, int pageIndex)`. This stores the target indices, calls `bookProgress.setCurrentChapterIndex()` and `bookProgress.setCurrentPageIndex()`, invokes `reLoadChapter(index: chapterIndex)`, and after pagination completes via a post-frame callback, navigates the `PageFlipWidget` controller to `pageIndex`.
   - `CosmosEpub.jumpToChapter(String bookId, int chapterIndex, int pageIndex)` delegates to `_showEpubKey.currentState?.jumpToChapter(chapterIndex, pageIndex)`.
   - The `PageFlipWidget` must support an external page index change after pagination (add a `goToPage(int pageIndex)` method to the page flip controller or accept a post-pagination callback). [L8]

6. **Search overlay**: Build `SearchBottomSheet` as a `StatefulWidget` in `lib/Helpers/search_bottom_sheet.dart`. Manages: input field (auto-focused, `TextField` with clear button), loading state (centered spinner, accent color), results list (`ListView.builder` with context previews), empty state, and error state ("Please enter a search term"). Accepts `List<LocalChapterModel> chapters`, `EpubSearchController searchController`, `Color accentColor`, and `Function(SearchResult) onResultTapped` callback. Opened via `showModalBottomSheet(isScrollControlled: true, enableDrag: true)` from the search icon button in the AppBar. Uses `Builder` as one of the bottom sheet children to detect keyboard visibility via `MediaQuery.of(context).viewInsets.bottom` and adjust its height accordingly. [L3] [L12] [L14] [L15]

7. **EpubSearchController**: Build `EpubSearchController` in `lib/Helpers/epub_search_controller.dart` as a `ChangeNotifier` managing: `query` (String), `results` (List<SearchResult>), `activeResultIndex` (int), `isLoading` (bool), `isActive` (bool), and `errorMessage` (String?). Depends on `SearchService` via constructor injection. Exposes:
   - `Future<void> search(String query, List<LocalChapterModel> chapters)` — cancels any in-flight search before starting a new one via a `_searchToken` pattern (int token incremented on each call, matched after async operations complete).
   - `void clear()` — clears results, query, error message.
   - `Future<void> saveToStorage(String bookId)` / `Future<void> loadFromStorage(String bookId)` — JSON serialize/deserialize through GetStorage.
   - `void selectResult(int index)` — sets `activeResultIndex`, updates storage.
   Store the key name `libSearchPrefix` in `lib/Component/constants.dart`. [L5]

8. **Context generation**: For each match, extract context from the chapter's plain text. Define "context window" as up to 100 characters before and up to 100 characters after the match — extended to the nearest word boundary (space) or paragraph boundary (double-newline / blank line extracted from HTML) to avoid mid-word cuts. Extract plain text from `<body>` content only — not `<head>`, `<script>`, `<style>`, or metadata tags. [L10]

9. **Loading state**: During cross-chapter search, the results area of the bottom sheet shows a centered loading spinner using the accent color. The reading screen remains visible underneath (search is non-blocking). If the user starts a new query while loading, the previous search is cancelled via the token pattern described in Tech Decision 7. [L12]

## AppBar Layout Specification

### Default state (no active search results)
The reader AppBar `actions` list, in order, left to right:
1. TOC button (`Icons.menu`, key `toc_button`) — existing
2. Font settings "Aa" — existing
3. Brightness toggle — existing (non-macOS only)
4. **Search icon** (`Icons.search`, key `search_button`) — NEW
5. Spacer (`SizedBox(width: 10.w)`) — existing
6. Overflow menu (`Icons.more_vert`, key `reader_overflow_menu`) — existing

The leading slot contains the back button (`key: 'back_button'`) — unchanged.

### Post-navigation state (after tapping a search result, or on re-entry with saved search state)
- The **leading** back button (`key: 'back_button'`) is **replaced** with a "Back to search results" icon button (`Icons.arrow_back` or platform-appropriate, key `back_to_search_button`, tooltip "Back to search results").
- The **search icon** in actions is removed (no need to show search when results already exist).
- Tapping `back_to_search_button` reopens the search bottom sheet with the previously-populated results list (loaded from `EpubSearchController` state or GetStorage).
- The "Back to search results" button remains visible while the bottom sheet is open. Tapping it while the bottom sheet is already open closes the sheet and restores the standard back button.

### Bottom sheet open state
- The AppBar does not change when the bottom sheet is merely open (the search icon remains). The back button only changes after a result is tapped and the sheet is dismissed.

## Testing Strategy

- **Test Seam -- SearchService**: `SearchService` operates on `List<LocalChapterModel>` — fully deterministic, no I/O, no platform dependencies. Pure Dart unit tests.
- **Test Seam -- EpubSearchController**: Depends on `SearchService` via constructor injection — fakes can replace the service for widget tests. Uses `ChangeNotifier` for widget test observation.
- **Test Seam -- findPageContainingMatch**: Pure function `int findPageContainingMatch(List<String> pageHtmlFragments, String matchText)` — unit testable with mock page fragments. Exported as a public top-level function in `lib/Helpers/search_service.dart`.
- **Test Seam -- HtmlPaginator**: Already testable with explicit constructor parameters (`pageWidth`, `pageHeight`, `fontSize`, `fontFamily`, `textDirection`). No platform dependencies.
- **Test Seam -- GetStorage**: Prefer mocking the storage layer (`libSearchPrefix` key reads/writes) in unit/widget tests. Use real storage only in integration/journey tests.
- **Test Seam -- ShowEpubState.jumpToChapter**: Accessible via `GlobalKey<ShowEpubState>` for integration tests that drive the reader programmatically.

- **Unit tests — SearchService.searchAllChapters**: empty chapter list, empty HTML, no match, single match, multiple matches, case-insensitive validation, chapters with only headings, chapters with HTML entities, chapter with unparseable HTML (should skip silently).
- **Unit tests — findPageContainingMatch**: match in first page, match in middle page, match in last page, match not found (returns -1), empty pages list, HTML fragments with non-breaking spaces, match text spanning across HTML tags within the same page fragment.
- **Unit tests — EpubSearchController**: search triggers loading → results transition, search with empty query sets error, cancellation of in-flight search (token pattern), save/load from storage round-trip preserves query and results.
- **Widget tests — SearchBottomSheet**: state transitions (idle → loading → results → empty → error). Verify input field auto-focus, dismiss via swipe/backdrop tap, result tap callback emits correct `SearchResult`, keyboard visibility adjusts sheet height.
- **Widget tests — AppBar**: Verify search icon present/absent based on search state, verify "Back to search results" button (key: `back_to_search_button`) replaces back button after result navigation, verify tap on "Back to search results" reopens bottom sheet.
- **Widget tests — Context rendering**: Verify context window is ~100 chars on each side, verify no mid-word truncation at boundaries.
- **Integration/journey tests — Stable selectors**:
  - `search_button` (Key) — search icon in AppBar
  - `back_to_search_button` (Key) — "Back to search results" button
  - `search_input_field` (Key) — TextField in bottom sheet
  - `search_results_list` (Key) — ListView in bottom sheet
  - `back_button` (Key) — existing back button
- **Journey test — End-to-end flow**: open book → tap `search_button` → verify bottom sheet opens with auto-focused input → type query → see loading spinner → see results in `search_results_list` → tap a result → verify bottom sheet dismisses → verify AppBar shows `back_to_search_button` → verify target chapter loaded and page contains match text → tap `back_to_search_button` → verify bottom sheet reopens with previous results.
- **Journey test — Persistence**: perform search → tap result → close reader → reopen reader → verify `back_to_search_button` is present in AppBar → tap it → verify previous results appear.

## Out of Scope

- Case-sensitive search toggle
- Regex search
- Whole-word matching
- Search highlight within the reading content (only the result list shows matches)
- Search within metadata/title/author fields
- Search across multiple EPUBs
- Search history
- macOS `Cmd+F` search keyboard shortcut
- Search result pagination (all results shown in a single scrollable list)

## Cross-Cutting Notes

- **AGENTS.md is stale**: Still references `isar_community` for reading progress. The codebase migrated to Drift (`lib/Database/app_database.dart`, `lib/Helpers/drift_progress_service.dart`). Update AGENTS.md as part of this work.
