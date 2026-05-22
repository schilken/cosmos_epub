## Overview

Add platform-adaptive back `IconButton` to `ShowEpub` AppBar leading slot; move hamburger (TOC) icon to `actions[0]`; expose optional `onBack` callback.

**Spec**: `ai_specs/back-button-show-epub.md`

## Context

- **Structure**: Single library package; all reader logic in `lib/show_epub.dart`
- **State management**: `StatefulWidget` with file-scope globals; no Riverpod/Bloc
- **Reference implementations**: `lib/show_epub.dart:845–892` (existing AppBar)
- **Assumptions/Gaps**: none — spec is fully resolved

## Plan

### Phase 1: Widget parameter + AppBar changes

- **Goal**: Add `onBack` to `ShowEpub`, swap leading/actions icons, add stable `Key`s for tests
- [x] `lib/show_epub.dart` — add `final VoidCallback? onBack;` field to `ShowEpub` widget class (~line 57)
- [x] `lib/show_epub.dart` — add `this.onBack,` to constructor (~line 65)
- [x] `lib/show_epub.dart` — replace `leading:` `IconButton` (hamburger) with back-arrow `IconButton`; icon: `Platform.isIOS || Platform.isMacOS ? Icons.arrow_back_ios : Icons.arrow_back`; `onPressed: () => widget.onBack?.call() ?? Navigator.pop(context)`; color: `fontColor`; size: `20.h`; key: `const Key('back_button')`
- [x] `lib/show_epub.dart` — insert hamburger `IconButton` (same icon/color/size, key: `const Key('toc_button')`) at index 0 of `actions:` list
- [x] TDD Slice 1: test `ShowEpub` renders `Icons.arrow_back` in leading on non-iOS → then implement
- [x] TDD Slice 2: test tapping `Key('back_button')` calls `Navigator.pop` when no `onBack` → then implement
- [x] TDD Slice 3: test tapping `Key('back_button')` calls `onBack` callback and NOT `Navigator.pop` → then implement
- [x] TDD Slice 4: test `Key('toc_button')` exists in AppBar actions → then implement
- [x] Test file: `test/show_epub_back_button_test.dart` — stub `DriftProgressService`/`bookProgress`, use `NavigatorObserver` for pop assertions
- [x] Verify: `fvm flutter analyze && fvm flutter test`

## Risks / Out of scope

- **Risks**: `bookProgress` global requires `CosmosEpub.initialize()` before widget tests pump — stub carefully to avoid `LateInitializationError`
- **Out of scope**: PopScope/WillPopScope wrapping, named-route navigation, visual redesign of AppBar
