import 'dart:io';

import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

HighlightModel _model({
  String? noteText,
  String bookId = 'bookA',
  String id = 'id1',
  int startIndex = 0,
  int endIndex = 4,
}) =>
    HighlightModel(
      id: id,
      bookId: bookId,
      chapterIndex: 2,
      paragraphKey: 'pk',
      startIndex: startIndex,
      endIndex: endIndex,
      selectedText: 'sel',
      colorValue: 0xFF64B5F6,
      noteText: noteText,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('HighlightModel noteText', () {
    test('round-trips a non-null noteText through toJson/fromJson', () {
      final m = _model(noteText: 'my note');
      final json = m.toJson();
      expect(json['noteText'], 'my note');
      final back = HighlightModel.fromJson(json);
      expect(back.noteText, 'my note');
    });

    test('fromJson with absent noteText key defaults to null', () {
      final json = _model().toJson()..remove('noteText');
      final m = HighlightModel.fromJson(json);
      expect(m.noteText, isNull);
    });

    test('fromJson with empty noteText defaults to null', () {
      final json = _model().toJson()..['noteText'] = '';
      final m = HighlightModel.fromJson(json);
      expect(m.noteText, isNull);
    });

    test('isNote returns true only when noteText is non-blank', () {
      expect(_model().isNote, false);
      expect(_model(noteText: '').isNote, false);
      expect(_model(noteText: '   ').isNote, false);
      expect(_model(noteText: 'hi').isNote, true);
    });
  });

  group('HighlightStorage notes', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = Directory.systemTemp.createTempSync('gs_test_');
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

    test('getBookNotes returns only notes for the given bookId', () {
      HighlightStorage.addOrUpdate(
          _model(noteText: 'n1', bookId: 'bookA', id: 'h1', startIndex: 0));
      HighlightStorage.addOrUpdate(
          _model(noteText: null, bookId: 'bookA', id: 'h2', startIndex: 1));
      HighlightStorage.addOrUpdate(
          _model(noteText: 'n2', bookId: 'bookB', id: 'h3', startIndex: 2));
      HighlightStorage.addOrUpdate(
          _model(noteText: '  ', bookId: 'bookA', id: 'h4', startIndex: 3));

      final notesA = HighlightStorage.getBookNotes('bookA');
      expect(notesA.length, 1);
      expect(notesA.first.id, 'h1');
    });

    test('getBookNotes returns empty list when no notes exist', () {
      HighlightStorage.addOrUpdate(
          _model(noteText: null, bookId: 'bookA', id: 'h1'));
      expect(HighlightStorage.getBookNotes('bookA'), isEmpty);
    });

    test('removeNote delegates to removeHighlight', () {
      HighlightStorage.addOrUpdate(
          _model(noteText: 'n1', bookId: 'bookA', id: 'h1'));
      HighlightStorage.removeNote('h1');
      expect(HighlightStorage.getBookNotes('bookA'), isEmpty);
    });

    test('toJson omits noteText when null', () {
      final json = _model(noteText: null).toJson();
      expect(json.containsKey('noteText'), isFalse);
    });

    test('toJson includes noteText when non-null', () {
      final json = _model(noteText: 'hi').toJson();
      expect(json['noteText'], 'hi');
    });
  });
}
