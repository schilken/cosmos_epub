import 'package:flutter/material.dart';

import '../Model/highlight_model.dart';
import '../cosmos_epub.dart';

class NotesListScreen extends StatefulWidget {
  final String bookId;
  final List<HighlightModel> Function(String)? noteProvider;

  const NotesListScreen({
    super.key,
    required this.bookId,
    this.noteProvider,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  late List<HighlightModel> _notes;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    final provider = widget.noteProvider ?? CosmosEpub.getBookNotes;
    _notes = provider(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text('No notes yet for this book.'),
            )
          : ListView.builder(
              key: const Key('notes_list'),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                final subtitle = 'Ch. ${note.chapterIndex + 1}'
                    ' · ${note.selectedText.length > 60 ? '${note.selectedText.substring(0, 60)}…' : note.selectedText}';
                return ListTile(
                  key: Key('note_${note.id}'),
                  title: Text(note.noteText ?? ''),
                  subtitle: Text(subtitle),
                  trailing: IconButton(
                    key: Key('note_delete_${note.id}'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      CosmosEpub.removeNote(note.id);
                      setState(() {
                        _notes.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
    );
  }
}
