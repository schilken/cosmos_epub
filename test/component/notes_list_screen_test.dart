import 'package:cosmos_epub/Component/notes_list_screen.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HighlightModel _note({
  String id = 'n1',
  int chapterIndex = 0,
  String selectedText = 'selection',
  String noteText = 'my note',
}) =>
    HighlightModel(
      id: id,
      bookId: 'book1',
      chapterIndex: chapterIndex,
      paragraphKey: 'pk',
      startIndex: 0,
      endIndex: 4,
      selectedText: selectedText,
      colorValue: 0xFF64B5F6,
      noteText: noteText,
    );

Widget _buildHarness({
  required List<HighlightModel> Function(String) noteProvider,
  String bookId = 'book1',
  void Function(HighlightModel)? onNoteTapped,
}) =>
    MaterialApp(
      home: NotesListScreen(
        bookId: bookId,
        noteProvider: noteProvider,
        onNoteTapped: onNoteTapped,
      ),
    );

void main() {
  testWidgets('shows note rows when provider returns notes', (tester) async {
    final notes = [
      _note(
          id: 'n1',
          chapterIndex: 0,
          selectedText: 'hello',
          noteText: 'note one'),
      _note(
          id: 'n2',
          chapterIndex: 1,
          selectedText: 'world',
          noteText: 'note two'),
    ];

    await tester.pumpWidget(_buildHarness(noteProvider: (_) => notes));
    await tester.pumpAndSettle();

    expect(find.text('note one'), findsOneWidget);
    expect(find.text('note two'), findsOneWidget);
    expect(find.byKey(const Key('notes_list')), findsOneWidget);
    expect(find.byKey(const Key('note_n1')), findsOneWidget);
    expect(find.byKey(const Key('note_n2')), findsOneWidget);
  });

  testWidgets('delete button removes note from list', (tester) async {
    final notes = <HighlightModel>[_note(id: 'n1')];

    await tester.pumpWidget(_buildHarness(noteProvider: (_) => List.of(notes)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_n1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('note_delete_n1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_n1')), findsNothing);
  });

  testWidgets('tapping a note calls onNoteTapped with correct HighlightModel',
      (tester) async {
    final notes = [_note(id: 'n1', noteText: 'tap note')];
    HighlightModel? receivedNote;

    await tester.pumpWidget(_buildHarness(
      noteProvider: (_) => notes,
      onNoteTapped: (note) => receivedNote = note,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note_n1')));
    await tester.pumpAndSettle();

    expect(receivedNote, isNotNull);
    expect(receivedNote!.id, 'n1');
    expect(receivedNote!.noteText, 'tap note');
  });

  testWidgets('empty notes shows empty-state message', (tester) async {
    await tester.pumpWidget(_buildHarness(noteProvider: (_) => []));
    await tester.pumpAndSettle();

    expect(find.text('No notes yet for this book.'), findsOneWidget);
  });
}
