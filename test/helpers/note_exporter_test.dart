import 'dart:convert';

import 'package:cosmos_epub/Helpers/note_exporter.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:flutter_test/flutter_test.dart';

HighlightModel _note({
  String id = 'n1',
  int chapterIndex = 1,
  String selectedText = 'Hello world',
  String noteText = 'My note',
  int startIndex = 0,
  int endIndex = 11,
}) =>
    HighlightModel(
      id: id,
      bookId: 'book1',
      chapterIndex: chapterIndex,
      paragraphKey: 'pk',
      startIndex: startIndex,
      endIndex: endIndex,
      selectedText: selectedText,
      colorValue: 0xFF64B5F6,
      noteText: noteText,
    );

final _fakeNow = DateTime(2026, 6, 30, 12, 0);

void main() {
  group('notesToMarkdown', () {
    test('empty notes produces minimal output', () {
      final md = notesToMarkdown('Test Book', [], now: () => _fakeNow);
      expect(md, contains('# Notes — Test Book'));
    });

    test('one note produces section with quote and note body', () {
      final md = notesToMarkdown(
        'Test Book',
        [_note()],
        now: () => _fakeNow,
      );
      expect(md, contains('# Notes — Test Book'));
      expect(md, contains('## Chapter 2'));
      expect(md, contains('> Hello world'));
      expect(md, contains('My note'));
      expect(md, contains('---'));
    });

    test('multiple notes are ordered by chapterIndex', () {
      final md = notesToMarkdown(
        'Book',
        [
          _note(id: 'n2', chapterIndex: 3, selectedText: 'chap3'),
          _note(id: 'n1', chapterIndex: 1, selectedText: 'chap1'),
        ],
        now: () => _fakeNow,
      );
      final ch2pos = md.indexOf('Chapter 2');
      final ch4pos = md.indexOf('Chapter 4');
      expect(ch2pos, greaterThan(-1));
      expect(ch4pos, greaterThan(-1));
      expect(ch2pos, lessThan(ch4pos));
    });

    test('unicode text is preserved', () {
      final md = notesToMarkdown(
        'Книга',
        [_note(selectedText: 'Привет мир', noteText: 'Заметка')],
        now: () => _fakeNow,
      );
      expect(md, contains('Привет мир'));
      expect(md, contains('Заметка'));
    });

    test('output is deterministic with injected clock', () {
      final md1 = notesToMarkdown('Book', [], now: () => _fakeNow);
      final md2 = notesToMarkdown('Book', [], now: () => _fakeNow);
      expect(md1, md2);
    });
  });

  group('notesToJson', () {
    test('empty notes produces valid JSON with book title and exportedAt', () {
      final json = notesToJson('Test Book', [], now: () => _fakeNow);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['book'], 'Test Book');
      expect(decoded['exportedAt'], _fakeNow.toIso8601String());
      expect(decoded['notes'], isEmpty);
    });

    test('one note produces correct JSON structure', () {
      final json = notesToJson(
        'Test Book',
        [_note()],
        now: () => _fakeNow,
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final notes = decoded['notes'] as List;
      expect(notes.length, 1);
      expect(notes[0]['chapterIndex'], 1);
      expect(notes[0]['selectedText'], 'Hello world');
      expect(notes[0]['noteText'], 'My note');
      expect(notes[0]['paragraphKey'], 'pk');
      expect(notes[0]['startIndex'], 0);
      expect(notes[0]['endIndex'], 11);
    });

    test('multiple notes produce matching count in JSON', () {
      final notes = [
        _note(id: 'n1', chapterIndex: 1),
        _note(id: 'n2', chapterIndex: 2, selectedText: 'Second'),
      ];
      final json = notesToJson('Book', notes, now: () => _fakeNow);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect((decoded['notes'] as List).length, 2);
    });

    test('ordered by chapterIndex ascending', () {
      final json = notesToJson(
        'Book',
        [
          _note(id: 'n2', chapterIndex: 3),
          _note(id: 'n1', chapterIndex: 1),
        ],
        now: () => _fakeNow,
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final list = decoded['notes'] as List;
      expect(list[0]['chapterIndex'], 1);
      expect(list[1]['chapterIndex'], 3);
    });

    test('unicode is preserved', () {
      final json = notesToJson(
        'カード',
        [_note(selectedText: '日本語', noteText: 'メモ')],
        now: () => _fakeNow,
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final list = decoded['notes'] as List;
      expect(list[0]['selectedText'], '日本語');
    });

    test('output is deterministic with injected clock', () {
      final json1 = notesToJson('Book', [], now: () => _fakeNow);
      final json2 = notesToJson('Book', [], now: () => _fakeNow);
      expect(json1, json2);
    });
  });
}
