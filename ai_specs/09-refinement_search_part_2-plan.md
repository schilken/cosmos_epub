## Overview

When a search result is tapped and the reader navigates to the matching page, bold all occurrences of the search term on that page using the existing `HtmlTextBuilder` span-splitting approach.

**Spec**: `ai_specs/09-refinement_search_part_2.md`

## Context

- **Structure**: layer-first (Model/, Helpers/, Component/)
- **State management**: `ChangeNotifier` (`EpubSearchController`) + `setState` (`ShowEpub`)
- **Reference implementations**:
  - `lib/Helpers/html_text_builder.dart:197-218` — `_applyInlineTag` already bolds `<b>`/`<strong>` via `fontWeight: FontWeight.bold`
  - `lib/Helpers/search_bottom_sheet.dart:262-267` — search results in the sheet already bold the matched text
  - `lib/Helpers/search_service.dart:7-57` — search uses case-insensitive `indexOf`, not regex
- **Assumptions/Gaps**: Bold text may be slightly wider than regular text → minor page reflow on pages with many matches. Acceptable for first iteration (search terms are typically short).

## Plan

### Phase 1: Thread search query through rendering pipeline and bold matches

- **Goal**: When search is active and a result is tapped, all occurrences of the search term are bolded on the displayed page.

- [ ] `lib/Model/search_controller.dart` — add `String? _lastQuery` field, set in `search()`, expose via `String? get query`, clear in `clear()`
- [ ] `lib/Helpers/html_text_builder.dart` — add `String? searchQuery` constructor param; in `_buildSpans()` and `_collectWidgets()` (text-only path), split text nodes at case-insensitive match boundaries and apply `FontWeight.bold` to matched segments
- [ ] `lib/Helpers/pagination.dart` — add `String? searchQuery` to `PagingWidget` and `_HighlightablePage` constructors; thread from `PagingWidget._paginate()` → `_HighlightablePage()` → `HtmlTextBuilder()` in `_buildContent()`
- [ ] `lib/show_epub.dart` — pass `_searchController.isActive ? _searchController.query : null` as `searchQuery` to `PagingWidget`
- [ ] TDD: `HtmlTextBuilder` bolds search query matches case-insensitively within text nodes
- [ ] TDD: `HtmlTextBuilder` returns unchanged spans when searchQuery is null or empty
- [ ] TDD: `HtmlTextBuilder` handles search query with special regex chars (e.g. `(`, `[`, `*`) as literal text
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: Bold rendering may cause minor text reflow on pages with many/long matches; layout was already measured without bold width
- **Out of scope**: Clearing bolding when search is dismissed (already handled — `searchQuery` becomes null when `isActive` is false); bolding matches across chapter boundaries (each chapter is paginated independently)
