import 'package:cosmos_epub/Database/app_database.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:drift/drift.dart';

class DriftProgressService {
  final AppDatabase _db;

  DriftProgressService(this._db);

  Future<bool> setCurrentChapterIndex(String bookId, int chapterIndex) async {
    try {
      await _db.into(_db.bookProgressTable).insertOnConflictUpdate(
            BookProgressTableCompanion.insert(
              bookId: bookId,
              currentChapterIndex: Value(chapterIndex),
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setCurrentPageIndex(String bookId, int pageIndex) async {
    try {
      await _db.into(_db.bookProgressTable).insertOnConflictUpdate(
            BookProgressTableCompanion.insert(
              bookId: bookId,
              currentPageIndex: Value(pageIndex),
            ),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<BookProgressModel> getBookProgress(String bookId) async {
    final defaults = BookProgressModel(
      bookId: bookId,
      currentChapterIndex: 0,
      currentPageIndex: 0,
    );
    try {
      final row = await (_db.select(_db.bookProgressTable)
            ..where((t) => t.bookId.equals(bookId)))
          .getSingleOrNull();
      if (row == null) return defaults;
      return BookProgressModel(
        bookId: row.bookId,
        currentChapterIndex: row.currentChapterIndex,
        currentPageIndex: row.currentPageIndex,
      );
    } catch (_) {
      return defaults;
    }
  }

  Future<bool> deleteBookProgress(String bookId) async {
    try {
      await (_db.delete(_db.bookProgressTable)
            ..where((t) => t.bookId.equals(bookId)))
          .go();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAllBooksProgress() async {
    try {
      await _db.delete(_db.bookProgressTable).go();
      return true;
    } catch (_) {
      return false;
    }
  }
}
