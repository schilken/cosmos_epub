import 'dart:io';

import 'package:cosmos_epub/Component/highlight_toolbar.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  group('Note persistence via HighlightStorage', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = Directory.systemTemp.createTempSync('gs_note_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );
      await GetStorage.init();
    });

    setUp(() {
      GetStorage().erase();
      HighlightStorage.storageProvider = () => GetStorage();
    });

    test('saved note appears as isNote with blue color via getBookNotes', () {
      final highlight = HighlightModel(
        id: 'note1',
        bookId: 'bookA',
        chapterIndex: 0,
        paragraphKey: 'pk',
        startIndex: 5,
        endIndex: 10,
        selectedText: 'hello',
        colorValue: noteAnchorColor.toARGB32(),
        noteText: 'my note text',
      );

      HighlightStorage.addOrUpdate(highlight);

      final notes = HighlightStorage.getBookNotes('bookA');
      expect(notes.length, 1);
      expect(notes.first.isNote, isTrue);
      expect(notes.first.noteText, 'my note text');
      expect(notes.first.colorValue, noteAnchorColor.toARGB32());
    });

    test('addOrUpdate upgrades existing highlight to note with blue color', () {
      final yellowHighlight = HighlightModel(
        id: 'h1',
        bookId: 'bookA',
        chapterIndex: 0,
        paragraphKey: 'pk',
        startIndex: 5,
        endIndex: 10,
        selectedText: 'hello',
        colorValue: 0xFFFFEB3B, // yellow
      );

      HighlightStorage.addOrUpdate(yellowHighlight);

      final noteHighlight = HighlightModel(
        id: 'n1',
        bookId: 'bookA',
        chapterIndex: 0,
        paragraphKey: 'pk',
        startIndex: 5,
        endIndex: 10,
        selectedText: 'hello',
        colorValue: noteAnchorColor.toARGB32(),
        noteText: 'upgraded to note',
      );

      HighlightStorage.addOrUpdate(noteHighlight);

      final notes = HighlightStorage.getBookNotes('bookA');
      expect(notes.length, 1);
      expect(notes.first.colorValue, noteAnchorColor.toARGB32());
      expect(notes.first.noteText, 'upgraded to note');

      final allBookHighlights = HighlightStorage.getBookHighlights('bookA');
      expect(allBookHighlights.length, 1);
    });
  });
}
