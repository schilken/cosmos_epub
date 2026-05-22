import 'package:drift/drift.dart';

import 'connection/connection.dart' as impl;

part 'app_database.g.dart';

class BookProgressTable extends Table {
  TextColumn get bookId => text()();
  IntColumn get currentChapterIndex =>
      integer().withDefault(const Constant(0))();
  IntColumn get currentPageIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bookId};
}

@DriftDatabase(tables: [BookProgressTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.openConnection());

  @override
  int get schemaVersion => 1;
}
