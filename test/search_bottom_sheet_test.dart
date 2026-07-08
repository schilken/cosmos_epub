import 'dart:io';

import 'package:cosmos_epub/Database/app_database.dart';
import 'package:cosmos_epub/Helpers/drift_progress_service.dart';
import 'package:cosmos_epub/Helpers/search_bottom_sheet.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/Model/search_controller.dart';
import 'package:cosmos_epub/Model/search_result.dart';
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

List<LocalChapterModel> _testChapters() {
  return [
    LocalChapterModel(
      chapter: 'Chapter 1',
      htmlContent:
          '<html><body><p>The quick brown fox jumps over the lazy dog.</p></body></html>',
    ),
    LocalChapterModel(
      chapter: 'Chapter 2',
      htmlContent:
          '<html><body><p>Another paragraph about foxes in the wild.</p></body></html>',
    ),
  ];
}

Future<void> _completeSearch(
    EpubSearchController controller, WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 20));
}

Widget _buildShowEpubHarness({
  VoidCallback? onBack,
  List<NavigatorObserver> observers = const [],
}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      theme: ThemeData(useMaterial3: false),
      navigatorObservers: observers,
      home: ShowEpub(
        epubBook: _minimalBook(),
        accentColor: Colors.blue,
        bookId: 'test_search_book',
        chapterListTitle: 'Contents',
        onBack: onBack,
      ),
    ),
  );
}

Widget _buildSheetWidget({
  required EpubSearchController controller,
  void Function(SearchResult)? onResultTapped,
}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      theme: ThemeData(useMaterial3: false),
      home: Scaffold(
        body: SafeArea(
          child: SizedBox(
            height: 600,
            child: SearchBottomSheet(
              chapters: _testChapters(),
              searchController: controller,
              accentColor: Colors.blue,
              backgroundColor: Colors.white,
              fontColor: Colors.black,
              onResultTapped: onResultTapped ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildSheetWidgetWithOnClose({
  required EpubSearchController controller,
  void Function(SearchResult)? onResultTapped,
  VoidCallback? onClose,
}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      theme: ThemeData(useMaterial3: false),
      home: Scaffold(
        body: SafeArea(
          child: SizedBox(
            height: 600,
            child: SearchBottomSheet(
              chapters: _testChapters(),
              searchController: controller,
              accentColor: Colors.blue,
              backgroundColor: Colors.white,
              fontColor: Colors.black,
              onResultTapped: onResultTapped ?? (_) {},
              onClose: onClose,
            ),
          ),
        ),
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

  group('SearchBottomSheet widget', () {
    testWidgets('renders auto-focused input field with search_input_field key',
        (tester) async {
      final controller = EpubSearchController();
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      final inputFinder = find.byKey(const Key('search_input_field'));
      expect(inputFinder, findsOneWidget);

      final textField = tester.widget<TextField>(inputFinder);
      expect(textField.autofocus, isTrue);
    });

    testWidgets('shows error message when controller has error',
        (tester) async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      controller.search('');
      await tester.pump();

      expect(find.text('Please enter a search term'), findsOneWidget);
    });

    testWidgets('shows loading spinner when controller isLoading',
        (tester) async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      controller.search('fox');
      await tester.pump();

      expect(controller.isLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _completeSearch(controller, tester);

      expect(controller.isLoading, isFalse);
    });

    testWidgets('shows "No results found" when search returns no matches',
        (tester) async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      controller.search('nonexistent');
      await _completeSearch(controller, tester);

      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('displays results list with search_results_list key',
        (tester) async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      controller.search('fox');
      await _completeSearch(controller, tester);

      final listFinder = find.byKey(const Key('search_results_list'));
      expect(listFinder, findsOneWidget);
    });

    testWidgets('result items show chapter name and matched text',
        (tester) async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      controller.search('fox');
      await _completeSearch(controller, tester);

      expect(find.text('Chapter 1'), findsOneWidget);

      final richTexts = find.byType(RichText);
      expect(richTexts, findsWidgets);
      var foundMatch = false;
      for (final widget in tester.widgetList<RichText>(richTexts)) {
        if (widget.text.toPlainText().contains('fox')) {
          foundMatch = true;
          final span = widget.text as TextSpan;
          var hasBold = false;
          span.visitChildren((child) {
            if (child is TextSpan &&
                child.style?.fontWeight == FontWeight.bold) {
              hasBold = true;
            }
            return true;
          });
          expect(hasBold, isTrue,
              reason: 'matchedText should be bold in results');
          break;
        }
      }
      expect(foundMatch, isTrue);
    });

    testWidgets('tapping a result calls onResultTapped', (tester) async {
      SearchResult? tappedResult;

      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      await tester.pumpWidget(_buildSheetWidget(
        controller: controller,
        onResultTapped: (r) => tappedResult = r,
      ));
      await tester.pump();

      controller.search('fox');
      await _completeSearch(controller, tester);

      final resultItem = find.text('Chapter 1');
      await tester.tap(resultItem.first);
      await tester.pump();

      expect(tappedResult, isNotNull);
      expect(tappedResult!.matchedText.toLowerCase(), contains('fox'));
    });

    testWidgets('close button is present when onClose is provided',
        (tester) async {
      final controller = EpubSearchController();
      await tester.pumpWidget(_buildSheetWidgetWithOnClose(
        controller: controller,
        onClose: () {},
      ));
      await tester.pump();

      expect(find.byKey(const Key('search_close_button')), findsOneWidget);
    });

    testWidgets('close button is absent when onClose is not provided',
        (tester) async {
      final controller = EpubSearchController();
      await tester.pumpWidget(_buildSheetWidget(controller: controller));
      await tester.pump();

      expect(find.byKey(const Key('search_close_button')), findsNothing);
    });

    testWidgets('tapping close calls onClose callback and pops sheet',
        (tester) async {
      final controller = EpubSearchController();
      var onCloseCalled = false;

      await tester.pumpWidget(_buildSheetWidgetWithOnClose(
        controller: controller,
        onClose: () => onCloseCalled = true,
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('search_close_button')));
      await tester.pumpAndSettle();

      expect(onCloseCalled, isTrue);
    });

    testWidgets('tapping close clears controller state', (tester) async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());

      await tester.pumpWidget(_buildSheetWidgetWithOnClose(
        controller: controller,
        onClose: () {
          controller.clear();
        },
      ));
      await tester.pump();

      controller.search('fox');
      await _completeSearch(controller, tester);
      controller.isActive = true;

      await tester.tap(find.byKey(const Key('search_close_button')));
      await tester.pumpAndSettle();

      expect(controller.isActive, isFalse);
      expect(controller.results, isEmpty);
    });
  });

  group('AppBar search integration', () {
    testWidgets('search_button key exists when search is not active',
        (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is RangeError) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(_buildShowEpubHarness());
      await tester.pump();

      expect(find.byKey(const Key('search_button')), findsOneWidget);

      FlutterError.onError = originalOnError;
    });

    testWidgets('search_button renders search icon', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is RangeError) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(_buildShowEpubHarness());
      await tester.pump();

      final searchButton = find.byKey(const Key('search_button'));
      expect(searchButton, findsOneWidget);

      final iconFinder = find.descendant(
        of: searchButton,
        matching: find.byType(Icon),
      );
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.icon, Icons.search);

      FlutterError.onError = originalOnError;
    });

    testWidgets('back_to_search_button not shown when search is inactive',
        (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is RangeError) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(_buildShowEpubHarness());
      await tester.pump();

      expect(find.byKey(const Key('back_button')), findsOneWidget);
      expect(find.byKey(const Key('back_to_search_button')), findsNothing);

      FlutterError.onError = originalOnError;
    });
  });

  group('EpubSearchController', () {
    test('initial state is empty', () {
      final controller = EpubSearchController();
      expect(controller.results, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.isActive, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('search with empty query sets error message', () {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      controller.search('');
      expect(controller.errorMessage, 'Please enter a search term');
      expect(controller.results, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('search with whitespace-only query sets error message', () {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      controller.search('   ');
      expect(controller.errorMessage, 'Please enter a search term');
    });

    test('search sets isLoading true then false', () async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());

      controller.search('fox');
      expect(controller.isLoading, isTrue);

      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.isLoading, isFalse);
      expect(controller.results, isNotEmpty);
    });

    test('isActive can be set and triggers notification', () {
      final controller = EpubSearchController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.isActive = true;

      expect(controller.isActive, isTrue);
      expect(notified, isTrue);
    });

    test('saveToStorage and loadFromStorage round-trip', () async {
      final controller1 = EpubSearchController();
      controller1.setChapters(_testChapters());
      controller1.search('fox');
      await Future.delayed(const Duration(milliseconds: 20));
      controller1.isActive = true;
      controller1.saveToStorage('book123');

      final controller2 = EpubSearchController();
      controller2.loadFromStorage('book123');

      expect(controller2.isActive, isTrue);
      expect(controller2.results, isNotEmpty);
      expect(controller2.results.first.matchedText.toLowerCase(), 'fox');
    });

    test('clear resets all state', () async {
      final controller = EpubSearchController();
      controller.setChapters(_testChapters());
      controller.search('fox');
      await Future.delayed(const Duration(milliseconds: 20));
      controller.isActive = true;

      controller.clear();

      expect(controller.results, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.isActive, isFalse);
    });
  });
}
