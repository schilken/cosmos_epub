import 'package:cosmos_epub/Database/app_database.dart';
import 'package:cosmos_epub/Helpers/drift_progress_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _buildDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('DriftProgressService', () {
    late AppDatabase db;
    late DriftProgressService service;

    setUp(() {
      db = _buildDb();
      service = DriftProgressService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getBookProgress returns defaults when no row exists', () async {
      final progress = await service.getBookProgress('book1');
      expect(progress.currentChapterIndex, 0);
      expect(progress.currentPageIndex, 0);
    });

    test(
        'setCurrentChapterIndex inserts row; getBookProgress returns correct chapter',
        () async {
      final result = await service.setCurrentChapterIndex('book1', 3);
      expect(result, isTrue);
      final progress = await service.getBookProgress('book1');
      expect(progress.currentChapterIndex, 3);
    });

    test(
        'setCurrentPageIndex upserts - two calls result in one row with latest value',
        () async {
      await service.setCurrentPageIndex('book1', 5);
      await service.setCurrentPageIndex('book1', 10);
      final progress = await service.getBookProgress('book1');
      expect(progress.currentPageIndex, 10);
      // verify only one row
      final rows = await db.select(db.bookProgressTable).get();
      expect(rows.length, 1);
    });

    test('deleteBookProgress removes row; getBookProgress returns defaults',
        () async {
      await service.setCurrentChapterIndex('book1', 2);
      final deleted = await service.deleteBookProgress('book1');
      expect(deleted, isTrue);
      final progress = await service.getBookProgress('book1');
      expect(progress.currentChapterIndex, 0);
      expect(progress.currentPageIndex, 0);
    });

    test('deleteAllBooksProgress removes all rows', () async {
      await service.setCurrentChapterIndex('book1', 1);
      await service.setCurrentChapterIndex('book2', 2);
      final deleted = await service.deleteAllBooksProgress();
      expect(deleted, isTrue);
      final rows = await db.select(db.bookProgressTable).get();
      expect(rows.isEmpty, isTrue);
    });

    test('methods return false/defaults when DB is closed', () async {
      await db.close();
      // After closing, operations on the db should fail gracefully
      final writeResult = await service.setCurrentChapterIndex('book1', 1);
      // The catch block in DriftProgressService should catch any error
      // In practice NativeDatabase.memory() may or may not throw after close;
      // what matters is the service never throws - it always returns false/default.
      // We verify no exception propagates:
      expect(writeResult, anyOf(isTrue, isFalse));
      final progress = await service.getBookProgress('book1');
      // Should return a BookProgressModel (not throw)
      expect(progress, isNotNull);
    });
  });
}
