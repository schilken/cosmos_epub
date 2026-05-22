// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BookProgressTableTable extends BookProgressTable
    with TableInfo<$BookProgressTableTable, BookProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentChapterIndexMeta =
      const VerificationMeta('currentChapterIndex');
  @override
  late final GeneratedColumn<int> currentChapterIndex = GeneratedColumn<int>(
      'current_chapter_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currentPageIndexMeta =
      const VerificationMeta('currentPageIndex');
  @override
  late final GeneratedColumn<int> currentPageIndex = GeneratedColumn<int>(
      'current_page_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [bookId, currentChapterIndex, currentPageIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_progress_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<BookProgressTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('current_chapter_index')) {
      context.handle(
          _currentChapterIndexMeta,
          currentChapterIndex.isAcceptableOrUnknown(
              data['current_chapter_index']!, _currentChapterIndexMeta));
    }
    if (data.containsKey('current_page_index')) {
      context.handle(
          _currentPageIndexMeta,
          currentPageIndex.isAcceptableOrUnknown(
              data['current_page_index']!, _currentPageIndexMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  BookProgressTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookProgressTableData(
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      currentChapterIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_chapter_index'])!,
      currentPageIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_page_index'])!,
    );
  }

  @override
  $BookProgressTableTable createAlias(String alias) {
    return $BookProgressTableTable(attachedDatabase, alias);
  }
}

class BookProgressTableData extends DataClass
    implements Insertable<BookProgressTableData> {
  final String bookId;
  final int currentChapterIndex;
  final int currentPageIndex;
  const BookProgressTableData(
      {required this.bookId,
      required this.currentChapterIndex,
      required this.currentPageIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['current_chapter_index'] = Variable<int>(currentChapterIndex);
    map['current_page_index'] = Variable<int>(currentPageIndex);
    return map;
  }

  BookProgressTableCompanion toCompanion(bool nullToAbsent) {
    return BookProgressTableCompanion(
      bookId: Value(bookId),
      currentChapterIndex: Value(currentChapterIndex),
      currentPageIndex: Value(currentPageIndex),
    );
  }

  factory BookProgressTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookProgressTableData(
      bookId: serializer.fromJson<String>(json['bookId']),
      currentChapterIndex:
          serializer.fromJson<int>(json['currentChapterIndex']),
      currentPageIndex: serializer.fromJson<int>(json['currentPageIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'currentChapterIndex': serializer.toJson<int>(currentChapterIndex),
      'currentPageIndex': serializer.toJson<int>(currentPageIndex),
    };
  }

  BookProgressTableData copyWith(
          {String? bookId, int? currentChapterIndex, int? currentPageIndex}) =>
      BookProgressTableData(
        bookId: bookId ?? this.bookId,
        currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
        currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      );
  BookProgressTableData copyWithCompanion(BookProgressTableCompanion data) {
    return BookProgressTableData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      currentChapterIndex: data.currentChapterIndex.present
          ? data.currentChapterIndex.value
          : this.currentChapterIndex,
      currentPageIndex: data.currentPageIndex.present
          ? data.currentPageIndex.value
          : this.currentPageIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookProgressTableData(')
          ..write('bookId: $bookId, ')
          ..write('currentChapterIndex: $currentChapterIndex, ')
          ..write('currentPageIndex: $currentPageIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookId, currentChapterIndex, currentPageIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookProgressTableData &&
          other.bookId == this.bookId &&
          other.currentChapterIndex == this.currentChapterIndex &&
          other.currentPageIndex == this.currentPageIndex);
}

class BookProgressTableCompanion
    extends UpdateCompanion<BookProgressTableData> {
  final Value<String> bookId;
  final Value<int> currentChapterIndex;
  final Value<int> currentPageIndex;
  final Value<int> rowid;
  const BookProgressTableCompanion({
    this.bookId = const Value.absent(),
    this.currentChapterIndex = const Value.absent(),
    this.currentPageIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookProgressTableCompanion.insert({
    required String bookId,
    this.currentChapterIndex = const Value.absent(),
    this.currentPageIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<BookProgressTableData> custom({
    Expression<String>? bookId,
    Expression<int>? currentChapterIndex,
    Expression<int>? currentPageIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (currentChapterIndex != null)
        'current_chapter_index': currentChapterIndex,
      if (currentPageIndex != null) 'current_page_index': currentPageIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookProgressTableCompanion copyWith(
      {Value<String>? bookId,
      Value<int>? currentChapterIndex,
      Value<int>? currentPageIndex,
      Value<int>? rowid}) {
    return BookProgressTableCompanion(
      bookId: bookId ?? this.bookId,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (currentChapterIndex.present) {
      map['current_chapter_index'] = Variable<int>(currentChapterIndex.value);
    }
    if (currentPageIndex.present) {
      map['current_page_index'] = Variable<int>(currentPageIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookProgressTableCompanion(')
          ..write('bookId: $bookId, ')
          ..write('currentChapterIndex: $currentChapterIndex, ')
          ..write('currentPageIndex: $currentPageIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $BookProgressTableTable bookProgressTable =
      $BookProgressTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [bookProgressTable];
}
