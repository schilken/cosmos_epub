---
type: Work Item
parent: spec.md
---

## What to build

Create `EpubSearchController` (ChangeNotifier) with search/cancel/clear/save/load, the `libSearchPrefix` constant, GetStorage persistence layer, and unit tests.

### Files to create/modify
- `lib/Helpers/epub_search_controller.dart` — `EpubSearchController` class extending `ChangeNotifier`.
- `lib/Component/constants.dart` — add `const String libSearchPrefix = "search_results_"`.
- `test/epub_search_controller_test.dart` — unit tests.

### EpubSearchController behavior
- Fields: `String query`, `List<SearchResult> results`, `int activeResultIndex`, `bool isLoading`, `bool isActive`, `String? errorMessage`.
- Constructor: injects `SearchService` (from Work Item 1).
- `Future<void> search(String query, List<LocalChapterModel> chapters)`:
  - If `query` is empty/blank, sets `errorMessage = "Please enter a search term"` and returns.
  - Sets `isLoading = true`, clears previous `errorMessage`.
  - Uses a **search-token pattern**: an `int _searchToken` incremented on each call. After `SearchService.searchAllChapters` completes, if the token no longer matches, the result is discarded (supports cancellation on re-query).
  - On success: sets `results`, clears `errorMessage`.
  - On error: sets `errorMessage` from exception, clears `results`.
  - Sets `isLoading = false` and notifies listeners in all paths.
- `void clear()` — resets query, results, errorMessage, isLoading to defaults.
- `Future<void> saveToStorage(String bookId)` — serializes `{"query": query, "results": results.map((r) => r.toJson()).toList(), "activeResultIndex": activeResultIndex}` as JSON to GetStorage under `${libSearchPrefix}$bookId`.
- `Future<void> loadFromStorage(String bookId)` — reads JSON from GetStorage, deserializes, restores fields. If no saved data, no-op.
- `void selectResult(int index)` — sets `activeResultIndex`, persists via `saveToStorage`.

### SearchResult serialization
- Add `Map<String, dynamic> toJson()` and `factory SearchResult.fromJson(Map<String, dynamic> json)` to the `SearchResult` model (modify `lib/Model/search_result.dart`). Handle `pageIndex` as nullable.

### GetStorage note
- GetStorage does NOT need to be injectable for unit tests — the controller reads/writes through a `GetStorage` instance. For testing, mock the storage path by providing test values directly, or test the JSON serialization round-trip without GetStorage.

## Required context

- `lib/Component/constants.dart` — contains existing storage keys: `libTheme`, `libFont`, `libFontSize`. Add `libSearchPrefix` here.
- `GetStorage` is already initialized in `CosmosEpub.initialize()`. The controller simply calls `GetStorage().read()` / `GetStorage().write()` — no separate init needed.
- The controller will be created and held by `ShowEpubState` (in Work Item 4).
- `pubspec.yaml` has `get_storage: ^2.1.1`.

## Acceptance criteria

- [ ] `libSearchPrefix` constant added to `lib/Component/constants.dart`.
- [ ] `EpubSearchController` in `lib/Helpers/epub_search_controller.dart` extends `ChangeNotifier`, injects `SearchService`.
- [ ] `search()` with empty/blank query sets `errorMessage = "Please enter a search term"` and does not call `SearchService`.
- [ ] `search()` sets `isLoading = true`, calls `SearchService.searchAllChapters`, sets `isLoading = false` on completion, updates `results`.
- [ ] Search-token pattern: calling `search()` while a previous search is in-flight discards the previous result.
- [ ] `clear()` resets all fields to defaults.
- [ ] `toJson()` and `fromJson()` on `SearchResult` serialize/deserialize all fields. `pageIndex` is `null` in JSON when not yet resolved.
- [ ] `saveToStorage(bookId)` writes valid JSON to GetStorage under `${libSearchPrefix}$bookId`.
- [ ] `loadFromStorage(bookId)` restores query, results, and activeResultIndex from GetStorage.
- [ ] `selectResult(index)` updates `activeResultIndex` and persists.
- [ ] Unit tests pass: search triggers loading → results, search triggers loading → error, empty query sets error, cancellation token pattern, save/load round-trip preserves data, `fromJson` / `toJson` round-trip.
- [ ] `dart run build_runner build` completes without errors.

## Covers

- User Stories: 5, 6
- Requirements: 7, 10
- Tech Decisions: 3, 7
- Interview Ledger: L5, L6, L7, L11, L12

## Blocked by

1 — Search data layer (Work Item 1)

## Blocking decisions

None
