import 'dart:convert';

import '../Model/highlight_model.dart';

String notesToMarkdown(
  String bookTitle,
  List<HighlightModel> notes, {
  DateTime Function() now = DateTime.now,
}) {
  final sorted = [...notes]
    ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
  final buf = StringBuffer();
  buf.writeln('# Notes — $bookTitle');
  buf.writeln();
  for (final note in sorted) {
    buf.writeln('## Chapter ${note.chapterIndex + 1}');
    buf.writeln('> ${note.selectedText}');
    buf.writeln();
    buf.writeln(note.noteText);
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
  }
  return buf.toString();
}

String notesToJson(
  String bookTitle,
  List<HighlightModel> notes, {
  DateTime Function() now = DateTime.now,
}) {
  final sorted = [...notes]
    ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
  return jsonEncode({
    'book': bookTitle,
    'exportedAt': now().toIso8601String(),
    'notes': sorted
        .map((n) => {
              'chapterIndex': n.chapterIndex,
              'selectedText': n.selectedText,
              'noteText': n.noteText,
              'paragraphKey': n.paragraphKey,
              'startIndex': n.startIndex,
              'endIndex': n.endIndex,
            })
        .toList(),
  });
}
