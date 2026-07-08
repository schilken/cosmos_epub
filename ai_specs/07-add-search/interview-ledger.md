---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the search be case-sensitive or case-insensitive by default?

Answer: Case-insensitive

Decision: Search is case-insensitive by default. No toggle for case sensitivity is included in scope.

### L2

Status: current

Question: Should search include headings and metadata, or only body text?

Answer: Headings and body

Decision: Search scope is headings (h1-h6) + body text. Metadata (title, author) is excluded.

### L3

Status: current

Question: How should search results be displayed?

Answer: Floating list

Decision: Results are displayed as a floating list overlay (modal bottom sheet) over the reading screen.

### L4

Status: current

Question: How should search interact with chapters/sections? Should it cross boundaries or stay per chapter?

Recommended Answer:
- Search runs across all chapters in the EPUB.
- Matches from any chapter appear in the results list.
- Tapping a result loads the target chapter and navigates to the exact page.

Answer: search not only in current chapter but in the whole epub

Decision: Search runs across the entire EPUB. All matches from any chapter appear in the results list.

### L5

Status: current

Question: When the user taps a search result and the reader navigates to that page -- should the search UI remain visible and keep working, or should it disappear?

Recommended Answer:
- Tap hides search, lands on reading page with the search term selected.
- Search results are saved in GetStorage so they persist.
- A "Back to search results" button on the reading screen returns the user to the search results.

Answer: tap lands on reading page with search term is selected, but the search results stay saved and are displayed again with one button click "back to search results"

Decision: Tapping a result navigates to the reading page with the match visible. Search results persist in GetStorage and can be recalled via a "Back to search results" button on the reading screen.

### L6

Status: current

Question: What does "Back to search results" do?

Answer: Returns to the search screen with the full results list visible, rehydrated from GetStorage. The search state (query, results, active index) survives navigation.

Decision: Add a "Back to search results" button visible on the reading screen when a search is active. Tapping it returns to the SearchOverlay with results rehydrated from GetStorage.

### L7

Status: current

Question: How should search results persist?

Answer: Search results persist in GetStorage keyed by bookId, co-located with highlights and preferences.

Decision: Use GetStorage key `search_results_$bookId` to persist the current search query and results list. Hydrate on search screen open; clear on new search or book close.

### L8

Status: current

Question: How should chapter navigation with search work?

Answer: Add a `jumpToChapter` method that bypasses sequential prev/next and loads a chapter by index directly.

Decision: Add `jumpToChapter(String bookId, int targetChapterIndex, int targetPageIndex)` static method to `CosmosEpub`. Sets both chapter and page indices in DriftProgressService, then triggers chapter reload on the reader widget.

### L9

Status: current

Question: How is `pageIndex` determined for a search match?

Answer: When jumping to a target chapter, scan the paginated page HTML strings. Extract plain text from each page, find the page whose plain text contains the match text. Fall back to page 0 if no match found.

Decision: Page index is computed at navigation time, not at search time. The target chapter is loaded, its pages are scanned for the match text, and `_currentPageIndex` is set to the matching page index. Fall back to page 0 on failure.

### L10

Status: current

Question: How many lines of context should each search result show?

Recommended Answer:
- Show 5 lines before and after each match, extracted from the chapter raw HTML plain text.
- Lines are defined by newline characters in the plain text.

Answer: 5 lines before and after

Decision: Each SearchResult includes `contextBefore` (5 lines) and `contextAfter` (5 lines) extracted from the chapter raw HTML via `html_parser.parse(chapter.htmlContent).documentElement?.text`, split on newline characters, and matched to the search term position.

### L11

Status: current

Question: What error state should be shown for an empty or blank search query?

Answer: Show "Please enter a search term".

Decision: When the user submits an empty or blank query, display the error message "Please enter a search term" in the search overlay instead of running a search.

### L12

Status: current

Question: How should the loading state work for an active cross-chapter search?

Answer: Show a loading indicator in the results overlay during search.

Decision: While `SearchService.searchAllChapters` runs, the results list shows a centered loading spinner (`CupertinoActivityIndicator` / `CircularProgressIndicator`) respecting the current theme accent color. The reading screen remains visible underneath (search is non-blocking).

### L13

Status: current

Question: How should the zero-match state look?

Answer: Show "No results found" in the results overlay.

Decision: When `SearchService.searchAllChapters` returns an empty list, display "No results found" centered in the results overlay.
