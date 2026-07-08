---
type: Work Item
parent: spec.md
---

## What to build

Create the pure-Dart search data layer: `SearchResult` model, `SearchService`, and the `findPageContainingMatch()` utility — all with unit tests.

### Files to create
- `lib/Model/search_result.dart` — `SearchResult` data class with fields: `chapterIndex`, `matchStart`, `matchEnd`, `matchedText`, `contextBefore`, `contextAfter`, and nullable `pageIndex`.
- `lib/Helpers/search_service.dart` — `SearchService` class with `searchAllChapters(List<LocalChapterModel> chapters, String query)` and the exported top-level function `int findPageContainingMatch(List<String> pageHtmlFragments, String matchText)`.
- `test/search_service_test.dart` — unit tests.

### SearchService behavior
- Accepts `List<LocalChapterModel>` and a query string.
- For each chapter, parses `htmlContent` via `html_parser.parse()`, extracts body text (excluding `<script>`, `<style>`, metadata), performs case-insensitive substring matching using `String.toLowerCase().indexOf()`.
- For each match, generates context: up to 100 characters before the match and up to 100 characters after, extended to the nearest word boundary (space) or paragraph boundary (two consecutive newlines in plain text). Does not truncate mid-word.
- Returns `List<SearchResult>` with `pageIndex` set to `null` (resolved later).
- If a chapter's HTML cannot be parsed to plain text, skip that chapter silently and continue.
- Returns empty list for empty query.

### findPageContainingMatch behavior
- Accepts `List<String>` (HTML page fragments from `HtmlPaginator.paginate()`) and a `String` match text.
- Parses each fragment to plain text, checks for case-insensitive match.
- Returns the index of the first page containing the match, or `-1` if not found.
- Exported as a public top-level function for use as a Test Seam.

## Required context

- `lib/Model/chapter_model.dart` — `LocalChapterModel` has `htmlContent` (full HTML string) and `chapter` (title).
- `lib/Helpers/html_paginator.dart` — `HtmlPaginator` constructor takes `pageWidth`, `pageHeight`, `fontSize`, `fontFamily`, `textDirection`; `paginate(String htmlContent)` returns `List<String>` of page HTML fragments.
- The `html` package (`import 'package:html/parser.dart' as html_parser`) is already a dependency — uses `html/dom.dart` for DOM traversal.
- EPUB body content is XHTML; use `documentElement?.text` on the parsed document to get plain text, then use that for matching and context extraction.

## Acceptance criteria

- [ ] `SearchResult` model is in `lib/Model/search_result.dart` with all specified fields, `pageIndex` is nullable.
- [ ] `SearchService` is in `lib/Helpers/search_service.dart` with a `searchAllChapters` method matching the signature above.
- [ ] `findPageContainingMatch` is a public top-level function in `lib/Helpers/search_service.dart`.
- [ ] Search is case-insensitive (lowercase comparison).
- [ ] Context is ~100 chars before/after, word-boundary aligned.
- [ ] Chapters with unparseable HTML are skipped silently.
- [ ] Empty query returns empty list.
- [ ] Unit tests pass for all edge cases: empty chapter list, empty HTML, no match, single match, multiple matches in same chapter, matches across multiple chapters, case-insensitive validation, chapters with only headings, chapters with HTML entities (`&amp;`, `&lt;`, etc.), chapter with unparseable HTML.
- [ ] Unit tests for `findPageContainingMatch`: match in first/middle/last page, match not found returns -1, empty pages list returns -1, HTML fragments with non-breaking spaces.
- [ ] `dart run build_runner build` completes without errors (no codegen needed, just verifying the model doesn't conflict).

## Covers

- User Stories: 1, 2, 5
- Requirements: 1, 2, 4, 5
- Tech Decisions: 1, 2, 8
- Interview Ledger: L1, L2, L4, L10

## Blocked by

None — ready to start
