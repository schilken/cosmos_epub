## Overview

Replace swipe/drag page turning with tap zones (left 20% = prev, right 20% = next, middle = passive) and simplify the page-curl animation to a direct slide transition. Fix end-of-chapter navigation bug caused by swipe-counter workaround.

**Spec**: `ai_specs/02-changerequest_paging.md` (read for full requirements)

## Context

- **Structure**: Flat library root — logic in `lib/Helpers/`, widgets in `lib/PageFlip/` and `lib/`
- **State management**: None — global mutable vars + `setState` + `ValueNotifier`
- **Reference implementations**: `lib/PageFlip/page_flip_widget.dart` (current gesture/animation system), `lib/Helpers/pagination.dart` (page rendering + tap listener pattern), `lib/show_epub.dart` (chapter navigation + swipe-counter bug)
- **Assumptions/Gaps**:
  - "Simple slide/direct transition" — replacing page-curl `CustomPaint` with a horizontal slide (e.g. `SlideTransition` or `AnimatedSwitcher`). Exact easing TBD during implementation.
  - Tap zones do NOT flip for RTL — right 20% always = forward/next, left 20% always = backward/prev (matches spec's "right edge moves to next page").
  - Removing the page-curl animation system deletes `lib/PageFlip/builders/builder.dart`, `lib/PageFlip/effects/flip_effect.dart`, and image-capture global state in `builder.dart`.

## Plan

### Phase 1: Replace drag with tap navigation

- **Goal**: Remove all horizontal drag handling; add tap zone detection. Keep existing animation system intact (replaced in Phase 2).
- [x] `lib/PageFlip/page_flip_widget.dart` — In `GestureDetector`, remove `onHorizontalDragUpdate`, `onHorizontalDragEnd`, `onHorizontalDragCancel`, `onPanDown`, `onPanEnd`. Remove `_turnPage()`, `_onDragFinish()`, `_isForward` field.
- [x] `lib/PageFlip/page_flip_widget.dart` — Add `onTapUp` handler in `GestureDetector`: compute `localPosition.dx / dimens.maxWidth`, call `previousPage()` if ≤ 0.2, `nextPage()` if ≥ 0.8, no-op otherwise. Call `widget.onPageFlip(pageNumber, isForward: bool)` after animation.
- [x] `lib/PageFlip/page_flip_widget.dart` — Remove `cutoffForward`, `cutoffPrevious` constructor params (no longer used). Remove unused drag state.
- [x] `lib/Helpers/pagination.dart` — In `_PagingWidgetState`, remove passing `isRightSwipe` parameter to `PageFlipWidget` (removed constructor param). (No-op: `isRightSwipe` was never passed from pagination.dart.)
- [x] Change `GestureDetector` `behavior` from `HitTestBehavior.opaque` to `HitTestBehavior.translucent` so horizontal scroll gestures on tables pass through to child `SingleChildScrollView`.
- [x] Verify: `fvm flutter analyze` in root

### Phase 2: Simplify page transition (slide instead of page-curl)

- **Goal**: Replace the page-curl `CustomPaint` animation with a horizontal slide transition. Remove image capture and `PageFlipEffect`.
- [x] `lib/PageFlip/page_flip_widget.dart` — Replace `_controllers` list + `PageFlipBuilder` pages with a simpler rendering approach: render current page in an `AnimatedSwitcher`/`SlideTransition` driven by a single `AnimationController`. Remove `pages` list, `_setUp()`, `goToPage()` — replace with targeted page display.
- [x] `lib/PageFlip/page_flip_widget.dart` — Simplify `nextPage()` and `previousPage()` to trigger a slide animation (animate out old page left, animate in new page from right for forward; opposite for backward).
- [x] `lib/PageFlip/page_flip_widget.dart` — Remove dependency on `builders/builder.dart`. Remove accesses to `imageData`, `currentPage`, `currentWidget`, `currentPageIndex` global `ValueNotifier` variables.
- [x] `lib/PageFlip/builders/builder.dart` — Delete entire file (no longer referenced). Contains global `ValueNotifier` state and `PageFlipBuilder` widget with `RepaintBoundary` image capture.
- [x] `lib/PageFlip/effects/flip_effect.dart` — Delete entire file (no longer referenced). Contains `PageFlipEffect` `CustomPainter`.
- [x] `lib/Helpers/pagination.dart` — Remove import of `builders/builder.dart` and any references to `flip_cache.imageData`.
- [x] `lib/cosmos_epub.dart` — Remove exports of `builder.dart` and `flip_effect.dart` if they were public. (No-op: these were never exported from cosmos_epub.dart.)
- [x] Verify: `fvm flutter analyze` && `fvm flutter test`

### Phase 3: Fix end-of-chapter navigation bug

- **Goal**: Remove swipe-counter workaround in `onLastPage`/`onFirstPageBack`; always advance chapter immediately when tapping past boundaries.
- [x] `lib/show_epub.dart` — In `onLastPage` callback (line ~615): remove `lastSwipe` counter and `totalPages <= 1` special case. Call `nextChapter()` unconditionally.
- [x] `lib/show_epub.dart` — In `onFirstPageBack` callback (line ~633): remove `prevSwipe` counter and `totalPages <= 1` special case. Call `prevChapter()` unconditionally.
- [x] `lib/show_epub.dart` — Remove `lastSwipe`, `prevSwipe`, `isLastPage` fields. Remove `_resetSwipeState()`. Remove swipe-reset logic from `onPageFlip` callback (line ~605-610).
- [x] `lib/show_epub.dart` — In `onPageFlip` callback (line ~598-600): don't reset `currentPageIndex` to 0 on last page (`currentPage == totalPages - 1`) — this was a swipe-workaround hack. Always save actual `currentPage`.
- [x] Verify: `fvm flutter analyze` in root

### Phase 4: Verify table horizontal scroll + text selection

- **Goal**: Confirm that removing `HitTestBehavior.opaque` and horizontal drag from parent `GestureDetector` allows table scroll and text selection to work.
- [ ] Manual verification: Open `7epubs/assets/example-with-table.epub` — scroll wide table horizontally, confirm no page turns during scroll.
- [ ] Manual verification: Long-press to select text, drag selection handles — confirm no page turns.
- [x] `lib/Helpers/pagination.dart` — The existing `Listener` (5px threshold) in `_HighlightablePage` already distinguishes taps from drags. Verified it remains alongside new tap zones (middle 60% does not trigger page turns, still toggles header via `onTextTap`).
- [x] Verify: `fvm flutter analyze`

## Risks / Out of scope

- **Risks**:
  1. Removing the page-curl/image-capture system may affect perceived performance during page transitions (image cache avoided re-rendering). Slide animation should be lightweight enough.
  2. `HitTestBehavior.translucent` allows events through to children — verify `SelectionArea` and `FadingEdgeScrollView` work correctly in this arrangement.
- **Out of scope**: Chapter-level navigation (bottom bar prev/next arrows remain unchanged), TOC navigation, font/theme settings, macOS platform adjustments.
