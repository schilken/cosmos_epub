# AGENTS.md — cosmos_epub

## Flutter version
Pinned via FVM: **3.35.0**. Run `fvm use` before any `flutter` commands, or prefix with `fvm flutter`.

## Package layout
- **Library root:** `lib/cosmos_epub.dart` — public API (`CosmosEpub` class)
- **Core reader widget:** `lib/show_epub.dart` (894 lines, `ShowEpub` StatefulWidget)
- **Example app:** `example/lib/main.dart` — single screen, opens `assets/book.epub`
- **Generated file:** `lib/Model/book_progress_model.g.dart` — Isar adapter, do not edit manually

## Essential commands

```bash
# From repo root (library)
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate Isar model after schema changes

# From example/
fvm flutter pub get
fvm flutter run
```

## Code generation
`lib/Model/book_progress_model.dart` uses `isar_community_generator`. After any change to that model, regenerate:
```bash
dart run build_runner build --delete-conflicting-outputs
```
The `.g.dart` file is committed; keep it in sync.

## Storage backends
- **Reading progress:** `isar_community` (no web support — blocked by Isar)
- **Highlights + preferences:** `get_storage`
- **Web is unsupported** — do not add web platform targets

## Initialization requirement
`CosmosEpub.initialize()` **must** be called once in `main()` before any other API call. Missing this causes silent failures.

## Global mutable state
`show_epub.dart` uses file-scope global variables (`bookProgress`, `selectedFont`, `backColor`, `fontColor`, `staticThemeId`). `ShowEpub` has `// ignore: must_be_immutable` — mutable fields on the widget itself. Be careful with widget rebuilds and state management around this file.

## Design dimensions
`flutter_screenutil` is initialized with `designSize: Size(375, 812)` (`DESIGN_WIDTH`/`DESIGN_HEIGHT` constants). All sizing in the reader uses `.sp`/`.w`/`.h` extensions.

## Chapter parsing (3-tier fallback)
`lib/Helpers/chapters.dart` tries: NCX NavMap → epubx chapter list → Spine. Understand this before touching chapter navigation logic.

## Tests & CI
No tests exist. No CI workflows configured. No linting beyond `flutter_lints` defaults.

## Example app assets
Two test EPUBs live in `example/assets/`: `book.epub` and `book_nested.epub`. Asset paths are also in `example/lib/generated/assets.dart` (auto-generated, do not edit).

## Known quirks
- `example/README.md` is stale boilerplate (mentions FlutterToast) — ignore it.
- `pubspec.lock` in `example/` still shows `cosmos_epub: 0.0.3` even though root is `1.0.0` — this is a display artefact of path dependencies.
- `generated/assets.dart` in the example is generated (likely `flutter_gen`); do not edit manually.
