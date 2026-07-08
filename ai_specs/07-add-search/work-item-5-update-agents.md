---
type: Work Item
parent: spec.md
---

## What to build

Update the stale `AGENTS.md` to reflect that reading progress uses Drift (SQLite), not `isar_community`.

### File to modify
- `AGENTS.md` — replace the "Storage backends" section.

### Change
From:
```
- **Reading progress:** `isar_community` (no web support -- blocked by Isar)
```
To:
```
- **Reading progress:** Drift (SQLite via `sqlite3_flutter_libs`)
```

Also update any other stale `isar_community` references in the file if present.

## Required context

- The codebase was migrated from Isar to Drift. Evidence: `lib/Database/app_database.dart`, `lib/Database/app_database.g.dart`, `lib/Helpers/drift_progress_service.dart`, `build.yaml`. No `isar_community` in `pubspec.yaml`.
- `lib/Model/book_progress_model.g.dart` no longer exists (deleted during migration). Remove the reference to it in "Generated file" if still present.
- The "Code generation" section references `isar_community_generator` — check if this is still accurate or should reference `drift_dev` instead.

## Acceptance criteria

- [ ] "Storage backends" section in `AGENTS.md` correctly states Drift (SQLite) as the reading progress backend.
- [ ] "Code generation" section references `drift_dev` and `build_runner` instead of `isar_community_generator`.
- [ ] "Generated file" accurately describes `lib/Database/app_database.g.dart` instead of the old Isar `.g.dart`.
- [ ] No remaining `isar_community` references in `AGENTS.md`.

## Covers

- Cross-Cutting Notes (from spec.md)

## Blocked by

None — ready to start
