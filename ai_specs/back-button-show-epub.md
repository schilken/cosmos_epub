<goal>
Add a platform-adaptive back IconButton to the ShowEpub AppBar so readers can navigate back to the ebook list without relying on OS gestures or hardware buttons.

The current `leading` slot holds the table-of-contents hamburger menu. The back button replaces it; the hamburger moves to the start of the `actions` list.
</goal>

<background>
Flutter package: cosmos_epub
Tech: Flutter + flutter_screenutil (designSize 375×812)
Key file: lib/show_epub.dart (~922 lines)

Relevant section: `ShowEpubState` builds an `AnimatedContainer` wrapping an `AppBar` (lines ~822–896).
- `leading`: currently `IconButton` with `Icons.menu` → calls `openTableOfContents`
- `actions`: currently contains "Aa" font button, brightness button

`ShowEpub` is a StatefulWidget with `// ignore: must_be_immutable`. New parameters must be added to the widget class constructor, not the state class.

Sizing convention: all sizes use `.h`, `.w`, `.sp` from `flutter_screenutil`. The existing icon uses `size: 20.h` — match this.

Platform imports: `dart:io show Platform` is already imported at line 1.
</background>

<user_flows>
Primary flow:
1. User is reading an ebook inside ShowEpub
2. User taps back arrow (leading slot of AppBar)
3. If `onBack` callback was provided by caller → `onBack()` is called
4. If no `onBack` → `Navigator.pop(context)` is called
5. User returns to the ebook list screen

Alternative flows:
- Caller provides `onBack` callback: full control over destination (e.g. named route, custom animation)
- No `onBack` provided: standard Navigator pop; works for any push-based navigation

Edge case:
- If `Navigator.canPop()` is false and no `onBack` is set: back button is still shown but tap is a no-op (no crash). This is an unlikely edge case; the caller is responsible for not pushing ShowEpub without a back destination.
</user_flows>

<requirements>
**Functional:**
1. Add optional `VoidCallback? onBack` parameter to `ShowEpub` widget constructor.
2. Replace the current `leading` `IconButton` (hamburger/menu) in the AppBar with a back-arrow `IconButton`.
3. Back button icon: `Icons.arrow_back_ios` on iOS and macOS; `Icons.arrow_back` on all other platforms. Use `Platform.isIOS || Platform.isMacOS` (already imported via `dart:io`).
4. Back button `onPressed`: calls `widget.onBack?.call() ?? Navigator.pop(context)`.
5. Back button icon color: `fontColor` (matches existing icon styling).
6. Back button icon size: `20.h` (matches existing icon sizing).
7. Move the existing hamburger `IconButton` (opens table of contents) to the beginning of the `actions` list, keeping its current `Icon`, color, and size unchanged.

**Error Handling:**
8. If `Navigator.pop()` is called when the route cannot be popped, Flutter handles this gracefully (no-op); no additional guard required.

**Edge Cases:**
9. `onBack` is nullable — callers that do not pass it receive the default `Navigator.pop(context)` behavior.
10. The `Platform.isMacOS` branch already has a conditional elsewhere in the file (line 872) — the same guard pattern may be reused for icon selection.
</requirements>

<boundaries>
Edge cases:
- `showHeader == false` (header hidden): back button is not visible when `AnimatedContainer` height is 0 — this is existing behavior, no change needed.
- Caller passes `onBack` that doesn't navigate away: acceptable, caller's responsibility.

Error scenarios:
- Navigator stack is empty and no `onBack` provided: `Navigator.pop()` is effectively a no-op in this state; no crash, no user feedback required.
</boundaries>

<implementation>
**File to modify:** `lib/show_epub.dart`

**Changes required:**

1. In `ShowEpub` widget class (around line 51–71):
   - Add field: `final VoidCallback? onBack;`
   - Add parameter to constructor: `this.onBack,`

2. In the `AppBar` widget (around line 830–894):
   - Replace the `leading:` `IconButton` block with a new `IconButton` using:
     ```dart
     leading: IconButton(
       onPressed: () => widget.onBack?.call() ?? Navigator.pop(context),
       icon: Icon(
         Platform.isIOS || Platform.isMacOS
             ? Icons.arrow_back_ios
             : Icons.arrow_back,
         color: fontColor,
         size: 20.h,
       ),
     ),
     ```
   - In the `actions:` list, insert a new `IconButton` at index 0 (before "Aa"):
     ```dart
     IconButton(
       onPressed: openTableOfContents,
       icon: Icon(
         Icons.menu,
         color: fontColor,
         size: 20.h,
       ),
     ),
     ```

**What to avoid:**
- Do not add `leading` back as an `InkWell` — use `IconButton` for consistent tap-target and accessibility semantics.
- Do not change the hamburger icon's visual style (color, size, icon name) — only relocate it.
- Do not add a `willPopScope` or `PopScope` wrapper — not in scope.
</implementation>

<validation>
**Manual verification:**
1. Hot-restart the example app (`example/`), open an ebook → confirm back arrow appears in AppBar leading slot.
2. Tap back arrow → app returns to list screen (Navigator.pop).
3. Confirm hamburger menu still appears in AppBar (now in actions) and still opens table of contents.
4. Run on iOS simulator: confirm `arrow_back_ios` is used. Run on Android: confirm `arrow_back` is used.
5. Pass a custom `onBack` callback in `example/lib/main.dart`: confirm custom callback fires instead of pop.

**Widget tests (write these):**

Test file: `test/show_epub_back_button_test.dart`

Behavior slices (RED → GREEN → REFACTOR order):

- **Slice 1 (happy path):** `ShowEpub` renders an `IconButton` whose icon is `Icons.arrow_back` (Android) in the AppBar leading area.
- **Slice 2 (pop behavior):** Tapping the back button triggers `Navigator.pop` when no `onBack` callback is provided.
- **Slice 3 (callback override):** Tapping the back button invokes the provided `onBack` callback and does NOT call `Navigator.pop`.
- **Slice 4 (table of contents still present):** `Icons.menu` IconButton exists in the AppBar actions after the move.

Testability seams:
- Inject a mock `Navigator` observer or use `NavigatorObserver` to assert pop calls.
- Provide a fake `onBack` callback via a captured `VoidCallback` variable.
- Use `Key` values on the back `IconButton` and the hamburger `IconButton` for stable selectors (e.g. `Key('back_button')`, `Key('toc_button')`).
- Stub `DriftProgressService` / `bookProgress` to satisfy `initState` without real DB.

Mocking policy: prefer fakes for DB/storage; only mock navigator observer at the true external boundary.
</validation>

<done_when>
- `ShowEpub` constructor accepts optional `onBack` parameter.
- AppBar leading shows a platform-adaptive back arrow at all times when `showHeader == true`.
- Tapping the back arrow: calls `onBack()` if set, otherwise calls `Navigator.pop(context)`.
- Hamburger menu icon is present in AppBar actions and still opens table of contents.
- `fvm flutter analyze` reports no new errors or warnings.
- All four widget test slices pass.
</done_when>
