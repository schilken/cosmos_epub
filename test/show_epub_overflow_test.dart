import 'dart:io';

import 'package:cosmos_epub/Database/app_database.dart';
import 'package:cosmos_epub/Helpers/drift_progress_service.dart';
import 'package:cosmos_epub/show_epub.dart' as show_epub_lib;
import 'package:cosmos_epub/show_epub.dart';
import 'package:drift/native.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

EpubBook _minimalBook() {
  return EpubBook()
    ..Title = 'Test Book'
    ..Chapters = []
    ..Content = (EpubContent()
      ..Html = {}
      ..Css = {}
      ..Images = {}
      ..Fonts = {}
      ..AllFiles = {});
}

Widget _buildHarness({VoidCallback? onBack}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      home: ShowEpub(
        epubBook: _minimalBook(),
        accentColor: Colors.blue,
        bookId: 'test_book',
        chapterListTitle: 'Contents',
        onBack: onBack,
      ),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('gs_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    await GetStorage.init();
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    show_epub_lib.bookProgress = DriftProgressService(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('reader_overflow_menu PopupMenuButton exists in AppBar actions',
      (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pump();

    expect(find.byKey(const Key('reader_overflow_menu')), findsOneWidget);
  });

  testWidgets(
      'overflow menu items include notes, export_md, export_json values',
      (tester) async {
    await tester.pumpWidget(_buildHarness());
    await tester.pump();

    final popupButton = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('reader_overflow_menu')),
    );
    final items =
        popupButton.itemBuilder(tester.element(find.byType(MaterialApp)));
    final values =
        items.whereType<PopupMenuItem<String>>().map((e) => e.value).toList();
    expect(values, contains('notes'));
    expect(values, contains('export_md'));
    expect(values, contains('export_json'));
  });
}
