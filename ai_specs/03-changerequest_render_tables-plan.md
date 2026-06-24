## Overview

Replace the current "flatten `<table>` to plain text" rendering path with a native Flutter `Table` widget: bordered box around the table, per-cell separators, distinct header row styling, per-cell `SoftHyphenParagraph` (keeps selectability + highlight offset accounting). Wide tables scroll horizontally.

**Spec**: `ai_specs/03-changerequest_render_tables.md` (read this file for full requirements)

## Context

- **Structure**: layer-first Helpers (`html_text_builder.dart` builds widgets; `html_paginator.dart` measures blocks; `pagination.dart` wires both into page builder)
- **State management**: file-scope globals in `show_epub.dart`; per-page `HtmlTextBuilder` instance with cumulative `_pageOffset` text accounting for highlights
- **Reference implementations**:
  - `lib/Helpers/html_text_builder.dart:69` — `_collectWidgets` (current table path flattens to paragraph spans) and `_buildSpans`, `_styleForTag`, `_paddingForTag`
  - `lib/Helpers/html_paginator.dart:79` — `_measureBlockHeight` (table estimate at line 85)
  - `lib/Helpers/pagination.dart:340` — how `HtmlTextBuilder` is instantiated twice (temp for page key + final for highlights); both must produce identical page text so highlight offsets match
- **Assumptions/Gaps**:
  - Example asset path: spec says `7epubs/assets/example-with-table.epub` — confirmed on disk; `7epubs/lib/generated/assets.dart` is stale (refs `examüle-with-table.epub`) and must not be hand-edited (regenerate via flutter_gen if needed)
  - No test infra exists beyond default `flutter test`; new unit/widget tests introduced here
  - Selectability + highlight offsets must be preserved inside cells (per-cell user choice)

## Plan

### Phase 1: Table renderer + offset accounting

- **Goal**: Render `<table>` as bordered Flutter `Table` with header row; cells are `SoftHyphenParagraph`; page text + highlight offsets remain correct; wide tables scroll horizontally.
- [x] `lib/Helpers/html_text_builder.dart` — extract pure helper `HtmlTableParser` (private class or top-level) returning structured `ParsedTable { rows: List<ParsedTableRow { cells: List<ParsedCell {textSpans, cleanText, isHeader}> } }`. Reads `<thead>/<tbody>/<tfoot>/<tr>/<th>/<td>`, treats `<th>` cells and any first row inside `<thead>` as header; honors `colspan`/`rowspan` via `Table`'s `columnSpan`/`rowSpan`.
- [x] `lib/Helpers/html_text_builder.dart` — in `_collectWidgets`, branch on `tag == 'table'` → call new `_addTable(element, widgets)` instead of paragraph path. Keep `_isContainer` returning false for `table`.
- [x] `lib/Helpers/html_text_builder.dart` — `_addTable`: build Flutter `Table` with `border: TableBorder.all(width: 1, color: borderColor)` (borderColor = `textColor.withValues(alpha: 0.4)`), `defaultColumnWidth: IntrinsicColumnWidth()`, header-row cells get bold style + `textColor.withValues(alpha: 0.08)` background via `DesktopTextSelection`-free `Container`/`ColoredBox` wrapper. Cell padding `EdgeInsets.all(fontSize * 0.25)`.
- [x] `lib/Helpers/html_text_builder.dart` — per cell, emit `SoftHyphenParagraph(textSpan: cellSpan, highlights: blockHighlights)` with per-cell block start/end derived from `_pageOffset`; advance `_pageOffset` by `cell.cleanText.length` in reading order (thead first, top→bottom, LTR or RTL per `textDirection`), appending to `_pageTextBuf` so `lastBuiltCleanText` matches the temp builder exactly.
- [x] `lib/Helpers/html_text_builder.dart` — wrap wide tables: `SingleChildScrollView(scrollDirection: Axis.horizontal, child: IntrinsicWidth(child: Table(...)))`. Add optional `maxWidth` param to `HtmlTextBuilder` so intrinsic width can compare to page width; if column sum + borders exceeds maxWidth → enable scroll wrap; else plain Table wrapped in a constrained `SizedBox` width.
- [x] `lib/Helpers/pagination.dart` — thread `maxWidth` (≈ `pageSize.width - 20.w`) into both `HtmlTextBuilder` instances (temp + final) at lines ~342 and ~360.
- [x] `7epubs/lib/main.dart` — switch example asset to `example-with-table.epub` (mirror current path-loading code) for visual verification. Leave generated `assets.dart` untouched; reference the file string directly if needed.
- [x] TDD: `HtmlTableParser` parses a simple `<table><thead><tr><th>A</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>` → 1 header row + 1 body row, header cell flagged, body cell text preserved.
- [x] TDD: `HtmlTableParser` handles missing `<thead>` → first `<tr>` becomes header; `<th>` anywhere is treated as header.
- [x] TDD: `HtmlTableParser` honors `colspan="2"` / `rowspan="2"` → produces `columnSpan`/`rowSpan` metadata.
- [x] TDD: `HtmlTextBuilder.build` on a small table → resulting clean text equals concatenation of cell texts in reading order; `_pageOffset` advancement matches.
- [x] TDD: widget test — table with 2 columns renders `Table` widget with `border` non-null and one header `ColoredBox` background; cells render `Text.rich` participatable in `SelectionArea`.
- [x] TDD: widget test — table wider than maxWidth renders inside a horizontal `SingleChildScrollView`; narrow table does not.
- [x] Verify: `fvm flutter analyze` && `fvm flutter test`
- [ ] Manual: run `7epubs` on a device/simulator, open `example-with-table.epub`, confirm bordered box, row/column separators, styled header row, cell text selectable, highlights (if any) still line up, wide table swipes horizontally without triggering page flip.

### Phase 2: Paginator table-height sync

- **Goal**: Page breaks around tables stay accurate under new renderer (borders + header padding + cell padding + optional horizontal scroll wrapper).
- [ ] `lib/Helpers/html_paginator.dart` — refine table branch in `_measureBlockHeight` (line 85): count header rows separately, add per-cell padding `2 * fontSize * 0.25`, add border thickness `1.0 * (rows + 1 + cols + 1)`, header row height `fontSize * 1.7`, body row height `fontSize * 1.4`, outer padding `fontSize * 0.6`.
- [ ] TDD: `HtmlPaginator._measureBlockHeight` of a 3-row (1 header + 2 body), 2-column table returns value within ±10% of an actual laid-out `Table` of identical content measured by `TextPainter` along the height axis (sanity bound).
- [ ] Verify: `fvm flutter analyze` && `fvm flutter test`
- [ ] Manual: paginated book with a long table → no awkward half-row stranded at page top/bottom; tables taller than page sit on their own page (existing behavior).

## Risks / Out of scope

- **Risks**:
  - Horizontal scrolling of wide tables may conflict with the `PageFlipWidget` swipe gesture inside a paginated reader — needs gesture arena testing; if conflicts, fall back to scale-down/fit-to-width.
  - `Table` + `IntrinsicColumnWidth` inside `PageFlipWidget` rasterizer (cached page images) — verify the cached-page flip still renders table borders correctly; may need `flip_cache.imageData.clear()` already called on highlight change.
  - `colspan`/`rowspan` interacting with per-cell linear `_pageOffset` accounting could shift highlight offsets for tables with spans; assume simple tables first, spans handled structurally but offset path uses cell-text concatenation (document limitation).
- **Out of scope**:
  - Editing generated `assets.dart` (regenerate via flutter_gen if asset rename needed)
  - Web support (Isar-blocked, unsupported platform)
  - Adding new dependencies (use only material `Table`)
  - Refactoring existing highlight model or storage backend