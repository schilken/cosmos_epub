## Overview

Fix two chapter navigation bugs: (1) right-edge tap on last page doesn't advance to next chapter, (2) TOC subchapter entries pointing to same source file show identical content.

**Spec**: `ai_specs/05-bug_chapter-navigation.md` (read this file for full requirements)

## Context

- **Structure**: feature-first (flat `lib/` with Helpers, Model, Component subdirs)
- **State management**: No framework — ad-hoc global vars (`bookProgress`, `selectedFont`, `backColor`, `fontColor`) + `setState` in `ShowEpubState`
- **Reference implementations**: `lib/show_epub.dart` (core reader), `lib/PageFlip/page_flip_widget.dart` (page swipe), `lib/Helpers/pagination.dart` (per-chapter paging), `lib/Helpers/epub_content_parser.dart` (chapter list builder)
- **Assumptions/Gaps**:
  - No fragment/anchor support exists; `_resolveContentBySource` strips `#anchor` via `split('#').first` at `lib/Helpers/epub_content_parser.dart:85`
  - `LocalChapterModel` has no fragment or source-file tracking field
  - Test EPUB `7epubs/assets/book_nested.epub` likely reproduces both bugs (nested TOC structure)

## Root Cause Analysis

### Bug 1 — Right-edge tap on last page doesn't advance chapter

`lib/PageFlip/page_flip_widget.dart:110-113` — tap handler guards `nextPage()` with `!_isLastPage`. When already on the last page, the right-edge tap does nothing. `onLastPage` only fires inside the animation-completion callback (`page_flip_widget.dart:57-66`), which only runs after a successful `forward()` animation — which never starts because `_isLastPage` blocks it.

The page-tap handler in `PagingWidget` (`lib/Helpers/pagination.dart:274-288`) correctly detects last-page-reached during forward animation, but the animation is never triggered from the last page.

### Bug 2 — TOC subchapter shows parent chapter content

`lib/Helpers/epub_content_parser.dart:85` — `_resolveContentBySource` calls `source.split('#').first`, stripping fragment anchors. Many EPUBs use the same source file for a parent chapter and its subchapters, differentiated only by `#` anchors (e.g. `ch4.xhtml` vs `ch4.xhtml#section4-3`). All nav points sharing the same base file resolve to the identical `htmlContent`, so navigating to "4.3" shows the same full content as "Chapter 4" — from the top.

The bottom bar correctly shows the subchapter title because `_currentChapterIndex` is set to the correct flat-list index. Only `htmlContent` is wrong.

## Plan

### Phase 1: Fix last-page right-edge tap (Bug 1)

- **Goal**: Right-edge tap on last page of a chapter triggers `nextChapter()`.

- [x] `lib/PageFlip/page_flip_widget.dart` — add an `onLastPageTap` callback to `PageFlipWidget`. In the tap handler (line ~112), when `ratio >= 0.8 && _isLastPage`, invoke the new callback instead of silently dropping the tap.
- [x] `lib/Helpers/pagination.dart` — pass the `onLastPageTap` from `PagingWidget` through to `PageFlipWidget`; wire it to `widget.onLastPage`.
- [x] Verify: `flutter analyze` with `fvm flutter analyze` (no tests exist per AGENTS.md)

### Phase 2: Fix TOC subchapter navigation (Bug 2)

- **Goal**: Navigating to a subchapter via TOC scrolls to the correct position within the shared source file. Do NOT break the flat-chapter-list model — keep one list entry per TOC nav point.

- [x] `lib/Model/chapter_model.dart` — add `final String? contentSource;` and `final String? anchorFragment;` fields to `LocalChapterModel` (nullable, default null). Update constructor.
- [x] `lib/Helpers/epub_content_parser.dart` — in `_resolveContentBySource`, extract the fragment before stripping; return it alongside content. Modify `_flattenNavPoints` to populate `contentSource` and `anchorFragment` on each `LocalChapterModel`.
- [x] `lib/Helpers/pagination.dart` — in `PagingWidget` (or in `_HighlightablePage`), accept the `anchorFragment`. When non-empty, use it to compute an initial scroll offset: parse the HTML for the anchor element, measure its position, and scroll to it. Alternatively: wrap the target anchor with a scroll-to tag and use `Scrollable.ensureVisible`.
- [x] `lib/show_epub.dart` — pass `anchorFragment` from `chaptersList[_currentChapterIndex]` through to `PagingWidget`.
- [x] Verify: `fvm flutter analyze` (no automated tests; manual test with `book_nested.epub` in example app)

## Risks / Out of scope

- **Risks**:
  1. Fragment-based scrolling requires measuring element positions in laid-out HTML — may need a post-frame callback and could be unreliable for deeply nested EPUB markup.
  2. If scroll-to-anchor fails silently, the user still sees the top of the source file (current behavior), which is acceptable degradation.
- **Out of scope**:
  - Persisting the last-read anchor position (only chapter+page are persisted currently).
  - Swipe-based chapter transitions (unrelated gesture handling).
  - Web platform support (explicitly unsupported per AGENTS.md).
