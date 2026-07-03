# Code Improvements — cosmos_epub (made by GLM 5.2)

Codebase analysis + prioritized refactoring proposals.
Generated from a full audit of `lib/` (26 Dart files, ~3,200 LOC).

---

## Executive Summary

The package is functional and well-structured for its scope, but carries
significant technical debt in three areas:

1. **Global mutable state** — 6 file-scope globals in `show_epub.dart`
   leak state across book instances, break test isolation, and make
   concurrent readers impossible.
2. **Duplication** — HTML parsing/layout logic is copy-pasted between
   `html_paginator.dart` and `html_text_builder.dart` (~150 lines).
   The 4 `open*Book` methods in `cosmos_epub.dart` repeat the same
   13-parameter signature.
3. **God object** — `show_epub.dart` (1,013 lines) mixes reader
   orchestration, theming, font UI, brightness, export, and navigation.

The analyzer reports **28 issues** (2 warnings, 26 infos/lints).

---

## 1. Static Analysis Issues (Quick Wins)

Run `fvm flutter analyze` to reproduce. All are mechanical fixes.

### 1.1 Deprecated APIs

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `lib/show_epub.dart` | 384 | `withOpacity` deprecated | `.withValues(alpha: ...)` |
| `lib/show_epub.dart` | 648 | `withOpacity` deprecated | `.withValues(alpha: ...)` |
| `lib/show_epub.dart` | 653 | `withOpacity` deprecated | `.withValues(alpha: ...)` |
| `lib/Helpers/pagination.dart` | 670 | `copySelection` deprecated | use `contextMenuBuilder` |
| `lib/Helpers/context_extensions.dart` | 92 | `textScaleFactor` deprecated | `textScaler` |

### 1.2 Lint Violations

| File | Line | Rule | Fix |
|------|------|------|-----|
| `lib/show_epub.dart` | 28-29 | `constant_identifier_names` | `DESIGN_WIDTH` → `designWidth` |
| `lib/show_epub.dart` | 88 | `void_checks` | `Future<void> loadChapterFuture = Future.value(true)` — assigning `void` |
| `lib/show_epub.dart` | 107 | `prefer_typing_uninitialized_variables` | `var dropDownFontItems` → add type or remove (appears unused) |
| `lib/show_epub.dart` | 968,979,986 | `use_build_context_synchronously` | guard `context` after `await` with `if (!context.mounted) return` |
| `lib/Helpers/pagination.dart` | 169 | `library_private_types_in_public_api` | `_PagingWidgetState` exposed via `createState()` — keep state class private but the lint fires; suppress or restructure |
| `lib/Helpers/pagination.dart` | 177 | `void_checks` | same `Future<void>` pattern |
| `lib/Helpers/pagination.dart` | 294 | `invalid_null_aware_operator` | `?.body` after `??` already null-guards |
| `lib/Helpers/pagination.dart` | 516 | `curly_braces_in_flow_control_structures` | wrap `while` body in `{}` |
| `lib/Helpers/pagination.dart` | 615 | `use_build_context_synchronously` | guard after `await` |
| `lib/Helpers/pagination.dart` | 625 | `annotate_overrides` | add `@override` to `build` |
| `lib/Helpers/custom_toast.dart` | 9 | `non_constant_identifier_names` | `Snack(` → `showSnack(` |
| `lib/Helpers/chapters.dart` | 66 | `prefer_const_constructors` | add `const` |
| `lib/Helpers/chapters.dart` | 76 | `use_build_context_synchronously` | guard after `await` |
| `lib/Helpers/epub_content_parser.dart` | 56 | `avoid_print` | remove debug `print('[Bug2]...')` |
| `lib/Helpers/html_text_builder.dart` | 82,279 | `curly_braces_in_flow_control_structures` | wrap `if`/`continue` in `{}` |
| `lib/Helpers/html_paginator.dart` | 201,233 | `curly_braces_in_flow_control_structures` | wrap `if`/`continue` in `{}` |
| `test/html_paginator_table_test.dart` | 106 | `prefer_const_constructors` | add `const` |

**Estimated effort:** 1-2 hours. No behavior change.

---

## 2. Global Mutable State (High Priority)

### Problem

`lib/show_epub.dart` lines 27-53 declare 6 file-scope mutable globals:

```dart
late DriftProgressService bookProgress;     // line 27
String selectedFont = 'Segoe';               // line 32
List<String> fontNames = [...];              // line 33
Color backColor = Colors.white;             // line 51
Color fontColor = Colors.black;             // line 52
int staticThemeId = 3;                       // line 53
```

**Impact:**
- State leaks between book instances — opening book B after book A
  inherits A's font/theme.
- Two simultaneous readers share the same colors/font → visual bugs.
- `CircleButton` (`circle_button.dart:26`) reads `staticThemeId`
  directly from the global — no widget rebuild when it changes unless
  parent rebuilds.
- `ChaptersList` (`chapters.dart:39,96-99`) reads `backColor`,
  `fontColor`, `selectedFont`, `fontNames`, `bookProgress` from globals
  → circular import on `show_epub.dart` just for state access.
- Widget tests cannot isolate state — must reset globals manually.

### Refactoring

**Phase A — Encapsulate reader state:**
- Create `lib/Reader/reader_state.dart`:
  ```dart
  class ReaderState extends ChangeNotifier {
    String selectedFont = 'Segoe';
    Color backColor = Colors.white;
    Color fontColor = Colors.black;
    int themeId = 3;
    double fontSize = 17.0;
    // ... methods: loadThemeSettings, updateTheme, etc.
  }
  ```
- `ShowEpub` creates a `ReaderState` in `initState`, provides it via
  `InheritedNotifier` or `provider` package.
- `CircleButton`, `ChaptersList` read from inherited state, not globals.
- Remove the 6 globals from `show_epub.dart`.

**Phase B — Encapsulate progress service:**
- `DriftProgressService` is assigned to the global `bookProgress` in
  `CosmosEpub.initialize()`. Instead:
  - Keep `CosmosEpub.initialize()` setting a private static instance.
  - `ShowEpub` receives `DriftProgressService` as a constructor param
    (defaults to the static instance via `CosmosEpub._progressService`).
  - Enables mock injection for widget tests.

**Risk:** Breaking change to public API if `bookProgress` was used
externally. Grep shows it's only used inside the package — safe.

**Effort:** 4-6 hours.

---

## 3. Duplication (High Priority)

### 3.1 HTML Parsing/Layout Duplication

`html_paginator.dart` and `html_text_builder.dart` share near-identical
code that has drifted apart:

| Method | paginator.dart | text_builder.dart | Status |
|--------|----------------|-------------------|--------|
| `_fixXhtml` | line 266 | line 460 | **Identical** |
| `_isContainer(Only)` | line 222 | line 268 | **Identical** |
| `_buildSpans` | line 114 | line 179 | **Identical** |
| `_applyInlineTag` | line 132 | line 197 | **Diverged** — paginator missing `s`/`del`/`strike`/`sup`/`sub`/`code` bg |
| `_styleForTag` | line 147 | line 221 | **Identical** |
| `_paddingForTag` | line 176 | line 249 | **Diverged** — different return type + values |

**Risk:** The paginator measures height with fewer inline tag styles
than the builder renders → page-break miscalculation for text using
`<s>`, `<sub>`, `<sup>`, or `code` styling.

### Refactoring

- Extract `lib/Helpers/html_shared.dart` with:
  - `String fixXhtml(String html)` — shared.
  - `bool isContainerElement(Element e)` — shared.
  - `TextStyle applyInlineTag(String tag, TextStyle base)` — **single
    source of truth** (use the richer text_builder version).
  - `TextStyle styleForTag(String tag, TextStyle base)` — shared.
  - `double paddingForTag(String tag, double fontSize)` — shared.
- Both files import and use the shared versions.
- Add a test that verifies `_applyInlineTag` handles all tags.

**Effort:** 2-3 hours. Eliminates ~150 lines of duplication.

### 3.2 Open-Book API Duplication

`cosmos_epub.dart` has 4 methods (`openLocalBook`, `openFileBook`,
`openURLBook`, `openAssetBook`) that each declare the **same 13 named
parameters** and call `_openBook` with identical arguments. Only the
byte-loading differs.

### Refactoring

- Define a config struct or use a private helper that accepts a
  `Future<Uint8List> Function()` loader + the shared params:
  ```dart
  static Future<void> _openBookFromBytes({
    required Future<Uint8List> Function() loadBytes,
    required BuildContext context,
    required String bookId,
    // ... other shared params with defaults
  }) async {
    final bytes = await loadBytes();
    final epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());
    if (!context.mounted) return;
    _openBook(...);
  }
  ```
- Each public method becomes a 3-line delegate.
- Reduces 4 × ~30 lines → 4 × ~6 lines + 1 × ~30 lines.

**Effort:** 1-2 hours.

---

## 4. God Object Decomposition (Medium Priority)

### Problem

`show_epub.dart` (1,013 lines) handles 7 distinct concerns in one
`State` class:

| Concern | Lines | Methods |
|---------|-------|---------|
| Reader orchestration | 84-211 | `initState`, `reLoadChapter`, `loadChapter`, `updateContentAccordingChapter`, `setupNavButtons` |
| Theme management | 448-474 | `updateTheme`, `loadThemeSettings` |
| Font settings UI | 226-446 | `_buildFontSettingsContent`, `updateFontSettings` |
| Brightness control | 217-224, 616-686 | `setBrightness` + inline UI |
| Export logic | 937-992 | `_handleExport` |
| Table of contents nav | 994-1012 | `openTableOfContents` |
| Build/render | 502-935 | `build` (430 lines) |

### Refactoring

Split into widgets/services:

1. **`ReaderThemeController`** (ChangeNotifier or simple class) — owns
   `backColor`, `fontColor`, `staticThemeId`, `selectedFont`,
   `fontSize`. Methods: `updateTheme(int id)`, `loadFromStorage()`,
   `persist()`. Eliminates Phase 2A globals.

2. **`FontSettingsSheet`** widget — extracts `_buildFontSettingsContent`
   + `updateFontSettings` (~220 lines). Receives `ReaderThemeController`.
   Fixes the `setState` shadowing bug (see §5.1).

3. **`BrightnessControl`** widget — extracts the brightness slider
   (~70 lines of inline UI in `build`). Note: currently dead code (see
   §6.1) — decide whether to remove or implement properly.

4. **`ReaderAppBar`** widget — extracts the AppBar + overflow menu
   (~140 lines of `build`). Receives callbacks for export, TOC, back.

5. **`ReaderFooter`** widget — extracts the chapter nav footer
   (~100 lines of `build`).

6. **`NoteExporter`** service — extracts `_handleExport` into a
   testable service class. Already has pure functions in
   `note_exporter.dart`; the `_handleExport` orchestration (file
   picker, snackbar, error handling) should move there or to a
   dedicated `ExportService`.

After extraction, `show_epub.dart` should be ~200-300 lines: just
orchestration + `build` assembling the sub-widgets.

**Effort:** 6-8 hours. Should follow §2 (state encapsulation).

---

## 5. Design & Correctness Issues

### 5.1 setState Shadowing in Font Settings

`show_epub.dart:226` — `_buildFontSettingsContent(StateSetter setState)`
takes a parameter named `setState`, then nests a `StatefulBuilder` that
also names its builder param `setState`. Three different `setState`
functions are in scope, and the wrong one may be called.

**Fix:** Rename params to `parentSetState` and `innerSetState`, or
restructure as a separate `StatefulWidget` (see §4.2).

### 5.2 Theme System: Magic Integers

`updateTheme(int id)` uses an if/else chain mapping IDs 1-5 to colors.
No enum, no validation, no self-documentation.

**Refactoring:**
```dart
enum ReaderTheme {
  violet(id: 1, background: cVioletishColor, foreground: Colors.black),
  bluish(id: 2, background: cBluishColor, foreground: Colors.black),
  light(id: 3, background: Colors.white, foreground: Colors.black),
  dark(id: 4, background: Colors.black, foreground: Colors.white),
  pink(id: 5, background: cPinkishColor, foreground: Colors.black);

  const ReaderTheme({required this.id, required this.background, required this.foreground});
  final int id;
  final Color background;
  final Color foreground;

  static ReaderTheme fromId(int id) =>
      values.firstWhere((t) => t.id == id, orElse: () => ReaderTheme.light);
}
```

**Effort:** 1 hour. Part of §4.1.

### 5.3 Font 'Segoe' Not in Assets

`selectedFont` defaults to `'Segoe'` and `fontNames` lists it first,
but `pubspec.yaml` declares 15 font families — none named `Segoe`.
`Segoe` is a system font on Windows; on other platforms it falls back
to default. Not broken, but misleading.

**Fix:** Either add a Segoe asset, or change default to an actual
bundled font (e.g., `'Lora'`). Also, font lookup uses
`fontNames.where((e) => e == selectedFont).first` — this is O(n) and
throws if not found. Use `fontNames.contains(selectedFont)` or a `Set`.

### 5.4 Error Swallowing

`catch (_)` appears in 8 places across the codebase, silently
discarding all exceptions:

- `drift_progress_service.dart` — 4 catch blocks returning `false`/defaults
- `highlight_model.dart` (`_readAll`) — returns `[]` on corrupt JSON
- `pagination.dart` (`_findAnchorPageByText`) — returns `-1`
- `html_text_builder.dart` (`_addImage`) — silently drops broken images
- `7epubs/lib/main.dart` — multiple `catch (_)`

**Refactoring:**
- Replace with `catch (e) { debugPrint('...: $e'); ... }` or use a
  logging package.
- For `_readAll`: corrupt JSON silently wipes all highlights. At
  minimum, log a warning. Consider a backup/migration path.
- For drift service: returning `false` on failure is fine, but the
  caller never checks the return value. Either log or surface errors.

**Effort:** 1-2 hours.

### 5.5 `PagingTextHandler` — Useless Wrapper

```dart
class PagingTextHandler {
  final Function paginate;  // untyped!
  PagingTextHandler({required this.paginate});
}
```

A class wrapping a single untyped `Function`. Used only as a callback
relay between `ShowEpub` and `PagingWidget`.

**Refactoring:** Replace with `typedef PaginateCallback = void Function();`
and pass the callback directly. Eliminates the class entirely.

**Effort:** 30 min.

### 5.6 `backPress()` — Dead Logic

```dart
Future<bool> backPress() async {
  return true;  // always true, never awaited meaningfully
}
```

Called from `PopScope.onPopInvokedWithResult` but the result is
ignored. `canPop: false` prevents popping regardless. The method does
nothing.

**Fix:** Remove `backPress()`. If custom back behavior is needed
later, implement it in `onPopInvokedWithResult` directly.

**Effort:** 5 min.

### 5.7 `getTitleFromXhtml` — Misleading Name

```dart
getTitleFromXhtml() {
  if (epubBook.Title != null) {
    bookTitle = epubBook.Title!;
    updateUI();
  }
}
```

Doesn't parse XHTML — reads `epubBook.Title` (metadata). Name suggests
XHTML parsing that doesn't happen.

**Fix:** Rename to `loadBookTitle()`.

### 5.8 `updateContentAccordingChapter` — Missing Preposition

Should be `updateContentAccordingToChapter` or simply
`loadChapterContent(int index)`.

### 5.9 Naming Inconsistencies

- `reLoadChapter` — should be `reloadChapter` (lowercase L) or `loadChapter`
- `rePaginate` — should be `repaginate` or `paginate`
- `updateUI` — wraps `setState(() {})`; just call `setState` directly
- `dropDownFontItems` — declared, never assigned, never read. Dead field.

---

## 6. Dead / Stale Code

### 6.1 Brightness Control — Non-functional

`setBrightness()` delays 5 seconds then hides the widget. The tap
handler delays 7 seconds and hides it. **No actual screen brightness
change occurs** — the `screen_brightness` package is not in
`pubspec.yaml` and the method body just waits and hides.

On macOS the entire brightness UI is gated behind `!Platform.isMacOS`.

**Options:**
1. **Remove** the brightness feature entirely (~100 lines).
2. **Implement** it: add `screen_brightness` package, set actual
   brightness in `setBrightness`, remove the arbitrary delays.

### 6.2 `CustomToast` — No-op

```dart
class CustomToast {
  static void showToast(String text) {
    // fluttertoast removed for macOS compatibility; no-op without a context.
  }
}
```

Called once in `loadChapter` for invalid chapter index. Does nothing.
The companion `Snack()` function works but is never called.

**Fix:** Remove `CustomToast`. Replace the one call site with a
`SnackBar` via `ScaffoldMessenger` (context is available).

### 6.3 `context_extensions.dart` — Mostly Unused

112 lines, 20+ extension methods. Grep shows only `isTablet` is used
(in `show_epub.dart:359`). The rest is copied boilerplate (Get-X style).

**Fix:** Strip to only `isTablet` (or inline it). Remove the file.
Fixes the `textScaleFactor` deprecation for free.

### 6.4 `HighlightToolbar` Widget — Unused

`lib/Component/highlight_toolbar.dart` defines a `HighlightToolbar`
widget. It's never instantiated — the toolbar is built inline as
`_PageToolbar` in `pagination.dart`. Only the constants
(`highlightColors`, `noteAnchorColor`) are imported.

**Fix:** Move the 2 constants to `theme_colors.dart` or a new
`palette.dart`. Delete the widget class.

### 6.5 `dropDownFontItems` — Unused Field

`show_epub.dart:108` — `var dropDownFontItems;` declared, never
assigned, never read.

### 6.6 Debug Print in Production

`epub_content_parser.dart:56-58`:
```dart
if (fragment != null && fragment.isNotEmpty) {
  print('[Bug2] _flattenNavPoints: source="$source", fragment="$fragment"');
}
```

Leftover debugging. Remove.

### 6.7 Stale AGENTS.md

AGENTS.md references `isar_community` and `book_progress_model.g.dart`
but the codebase now uses **Drift** (`app_database.dart` +
`app_database.g.dart`). The file count and line count for
`show_epub.dart` (894 → 1013) are also stale. Tests now exist (12 files).

**Fix:** Update AGENTS.md to reflect Drift migration, current file
sizes, and existing tests.

---

## 7. Testing Gaps

### Current State

12 test files exist (contrary to AGENTS.md). Coverage focuses on:
- HTML table parsing/rendering (4 files)
- Note exporter, highlight model (2 files)
- Drift progress service (1 file)
- Widget smoke tests: overflow menu, back button, notes list, toolbar (4 files)

### Gaps

1. **No reader integration test** — `ShowEpub` is never instantiated
   in tests. The 1,013-line core has zero test coverage.
2. **No pagination test** — `HtmlPaginator.paginate()` (the most
   complex algorithm) has only a table-height test. No test for
   multi-page text splitting, image estimation, or edge cases
   (empty HTML, single block larger than page).
3. **No soft-hyphen test** — `soft_hyphen_text.dart` (324 lines of
   TextPainter manipulation) has zero tests. The `_verifyHyphens`
   second-pass logic is fragile and untested.
4. **No highlight offset test** — `_resolveSelectionRange` (50 lines,
   4-strategy fallback) is untested.
5. **Global state blocks widget tests** — can't test `ShowEpub`
   without initializing real `GetStorage` + `AppDatabase`.

### Recommendations

- **Priority 1:** Add unit tests for `HtmlPaginator.paginate()` with
  simple multi-paragraph HTML. This is the highest-risk untested logic.
- **Priority 2:** Add unit tests for `_hyphenateWord` /
  `_hyphenateHtml` — especially Uzbek digraph handling.
- **Priority 3:** After §2 (state encapsulation), add widget tests
  for `ShowEpub` with mocked `DriftProgressService`.
- **Priority 4:** Add a robot-style journey test for: open book →
  flip pages → navigate chapters → add highlight.

---

## 8. Architecture Observations

### 8.1 Storage Backend Split

Reading progress uses **Drift** (SQLite); highlights/notes use
**GetStorage** (JSON-in-key-value). Two different storage paradigms
for similar data. Highlights are loaded synchronously via
`HighlightStorage._readAll()` which **decodes the entire JSON list
on every call** — `getParagraphHighlights` reads all highlights for
all books, then filters in memory.

**Impact:** With many highlights, every page render does a full JSON
decode + filter. No caching.

**Refactoring (low priority):** Migrate highlights to Drift as a
second table. Enables indexed queries, transactions, and removes the
JSON-encode/decode overhead. Or, at minimum, cache the decoded list
in memory and invalidate on write.

### 8.2 `ChaptersList` Circular Dependency

`chapters.dart` imports `show_epub.dart` to access globals
(`backColor`, `fontColor`, `selectedFont`, `fontNames`, `bookProgress`).
`show_epub.dart` imports `chapters.dart` (for the `ChaptersList` widget).

This circular import works because Dart allows it, but it creates tight
coupling. After §2 (state encapsulation), `ChaptersList` should receive
theme + font via constructor params, breaking the cycle.

### 8.3 `ScreenUtil.init` in `build`

`show_epub.dart:504` calls `ScreenUtil.init(context, ...)` inside
`build()`. This re-initializes ScreenUtil on every rebuild. The
`designSize` differs for macOS (1280×800) vs mobile (375×812), so
swapping `.sp`/`.w`/`.h` values shift on every platform check.

**Refactoring:** Move `ScreenUtil.init` to the app root (in the host
app's `build`), or use `ScreenUtilInit` widget. The package reader
shouldn't own screen-util initialization.

---

## 9. Prioritized Action Plan

Ordered by impact / effort ratio.

| # | Refactoring | Priority | Effort | Section |
|---|-------------|----------|--------|---------|
| 1 | Fix all 28 analyzer issues | High | 1-2h | §1 |
| 2 | Remove dead code (brightness, CustomToast, context_extensions, HighlightToolbar widget, debug print, dropDownFontItems) | High | 1h | §6 |
| 3 | Extract shared HTML helpers (eliminate duplication) | High | 2-3h | §3.1 |
| 4 | Deduplicate open-book API | High | 1-2h | §3.2 |
| 5 | Replace `PagingTextHandler` with typedef | Medium | 30min | §5.5 |
| 6 | Replace magic theme integers with enum | Medium | 1h | §5.2 |
| 7 | Fix `setState` shadowing in font settings | Medium | 30min | §5.1 |
| 8 | Encapsulate reader state (remove globals) | High | 4-6h | §2 |
| 9 | Decompose `show_epub.dart` god object | Medium | 6-8h | §4 |
| 10 | Add `HtmlPaginator` unit tests | High | 2-3h | §7 |
| 11 | Replace `catch (_)` with logging | Low | 1-2h | §5.4 |
| 12 | Update stale AGENTS.md | Low | 30min | §6.7 |
| 13 | Move `ScreenUtil.init` out of `build` | Low | 1h | §8.3 |
| 14 | Migrate highlights to Drift (or cache) | Low | 3-4h | §8.1 |

**Total estimated effort:** ~25-35 hours for all items.

Items 1-2 are safe to do immediately with zero risk. Items 3-6 are
low-risk mechanical refactors. Item 8 is the highest-impact but should
be done before item 9. Items 10+ can proceed in parallel.
