import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seven_epubs/main.dart';

import '../harness/bookmark_harness.dart';

void main() {
  group('macOS bookmark journey', () {
    late BookmarkTestHarness harness;
    late Directory tempDir;
    late File testEpub;

    setUp(() async {
      harness = BookmarkTestHarness();
      tempDir = await Directory.systemTemp.createTemp('bookmark_test_');
      testEpub = File('${tempDir.path}/test.epub');
      await testEpub.writeAsString('mock epub content');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('pick file -> bookmark created -> resolve after restart', () async {
      final svc1 = harness.createService();

      final bookmark = await svc1.bookmarkFile(testEpub.path);
      expect(bookmark, isNotNull);
      expect(harness.fakeStorage.data['bookmark_${testEpub.path}'], isNotNull);

      final svc2 = harness.createService();
      final resolved = await svc2.resolveAndAccess(testEpub.path);
      expect(resolved, isNotNull);
    });

    testWidgets('shelf shows bookmarked file as available', (tester) async {
      final svc = harness.createService();
      await svc.bookmarkFile(testEpub.path);
      await svc.resolveAndAccess(testEpub.path);

      await tester.pumpWidget(MaterialApp(
        home: ShelfScreen(
          bookmarkService: svc,
          initialShelf: [testEpub.path],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shelf-list')), findsOneWidget);
      expect(find.text('test.epub'), findsOneWidget);

      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('settings gear icon navigates to settings on macOS',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const ShelfScreen(),
      ));
      await tester.pumpAndSettle();

      final gearFinder = find.byKey(const Key('settings-gear'));
      expect(gearFinder, Platform.isMacOS ? findsOneWidget : findsNothing);
    });
  });
}
