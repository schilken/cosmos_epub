---
type: Work Item
parent: spec.md
---

## What to build

Add `jumpToChapter(chapterIndex, pageIndex)` to `ShowEpubState`, expose it via `GlobalKey<ShowEpubState>` on `CosmosEpub`, and add `goToPage()` to the page flip controller so the reader can jump to an arbitrary chapter and page programmatically.

### Files to modify
- `lib/show_epub.dart` — add public `jumpToChapter()` method to `ShowEpubState`, assign GlobalKey.
- `lib/cosmos_epub.dart` — hold `GlobalKey<ShowEpubState>`, assign in `_openBook()`, add static `jumpToChapter()`.
- `lib/PageFlip/page_flip_widget.dart` — add mechanism to jump to an arbitrary page index after pagination.

### ShowEpubState.jumpToChapter behavior
```dart
void jumpToChapter(int chapterIndex, int pageIndex) {
  _currentChapterIndex = chapterIndex;
  _currentPageIndex = pageIndex;
  bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
  bookProgress.setCurrentPageIndex(bookId, pageIndex);
  reLoadChapter(index: chapterIndex);
  // After pagination completes, navigate to pageIndex via PageFlipWidget controller
}
```

- The method stores `_pendingJumpPageIndex` (int) on the state. After `controllerPaging.paginate()` completes and the `PageFlipWidget` builds with the new pages, a post-frame callback (`WidgetsBinding.instance.addPostFrameCallback`) triggers the page flip controller to go to `_pendingJumpPageIndex`.
- If `chapterIndex == _currentChapterIndex` (same chapter), skip `reLoadChapter` and directly navigate to `pageIndex` in the page flip controller.
- Must validate bounds: if `chapterIndex` is out of range, fall back to 0. If `pageIndex` is out of range, fall back to 0.

### CosmosEpub integration
- Add `static final GlobalKey<ShowEpubState> _showEpubKey = GlobalKey<ShowEpubState>();`
- In `_openBook()`, assign `key: _showEpubKey` to the `ShowEpub` widget.
- Add `static void jumpToChapter(String bookId, int chapterIndex, int pageIndex)` that calls `_showEpubKey.currentState?.jumpToChapter(chapterIndex, pageIndex)`.

### PageFlipWidget page control
- The `PageFlipWidget` receives `starterPageIndex` via its constructor (line ~570 in `show_epub.dart`). After pagination, the starter page is used as the initial page index.
- For jump-to-page-after-pagination, the post-frame callback approach works: set `_currentPageIndex` on the state, then call `setState` so `PagingWidget` picks up the new `starterPageIndex`.
- Alternative: if `PageFlipWidget` already exposes a method to change pages programmatically, use that. Otherwise, re-build the widget with the new starter page index via `setState`.

### Page index resolution for search (done later, in Work Item 4)
- This Work Item only provides the navigation mechanism. Work Item 4 wires it up with `findPageContainingMatch` to compute the correct `pageIndex` from a `SearchResult`.

## Required context

- `lib/show_epub.dart:56` — `ShowEpub` is a `StatefulWidget` with `// ignore: must_be_immutable`. The `ShowEpubState` at line ~74 has `_currentChapterIndex` (line 106) and `_currentPageIndex` (line 107).
- `lib/show_epub.dart:144` — `reLoadChapter({bool init = false, int index = -1})` reads progress, calls `loadChapter`.
- `lib/show_epub.dart:158` — `loadChapter()` builds `EpubContentParser`, sets `chaptersList`, calls `updateContentAccordingChapter`.
- `lib/show_epub.dart:176` — `updateContentAccordingChapter(int chapterIndex)` stores chapter index in DB, sets `htmlContent`, triggers `controllerPaging.paginate()`.
- `lib/show_epub.dart:189` — `controllerPaging.paginate()` presumably triggers the `PageFlipWidget` to rebuild with paginated content.
- The existing `ShowEpub` key is `Key('ShowEpub_${bookId}_${DateTime.now().millisecondsSinceEpoch}')` at line 265 of `cosmos_epub.dart` — this needs to accept the GlobalKey alongside or replace it.
- `lib/PageFlip/page_flip_widget.dart` — the `PageFlipWidget` and its `_PageFlipWidgetState` need to be inspected for existing page-jump capability.

## Acceptance criteria

- [ ] `ShowEpubState` has a public `jumpToChapter(int chapterIndex, int pageIndex)` method.
- [ ] `CosmosEpub` holds a `GlobalKey<ShowEpubState>` and assigns it to the `ShowEpub` widget in `_openBook()`.
- [ ] `CosmosEpub.jumpToChapter(bookId, chapterIndex, pageIndex)` delegates to the key's current state.
- [ ] Jumping to a new chapter triggers `reLoadChapter`, and after pagination, the page flip navigates to the target page.
- [ ] Jumping within the same chapter navigates to the target page without re-parsing.
- [ ] Out-of-range chapter index falls back to 0; out-of-range page index falls back to 0.
- [ ] Both `currentChapterIndex` and `currentPageIndex` are persisted to `DriftProgressService`.
- [ ] Sequential prev/next navigation continues to work normally after a jump (doesn't break `showPrevious`/`showNext` logic).
- [ ] App builds and runs without errors via `fvm flutter run` from the `7epubs/` directory.

## Covers

- User Stories: 3
- Requirements: 8, 9
- Tech Decisions: 4, 5
- Interview Ledger: L8, L9

## Blocked by

None — ready to start
