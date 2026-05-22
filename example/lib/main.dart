import 'dart:io';

import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show basename;

import 'shelf_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CosmosEpub.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmosEpub Reader Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0a0e21),
        ),
        scaffoldBackgroundColor: const Color(0xff0a0e21),
      ),
      home: const ShelfScreen(),
    );
  }
}

// ──── Data class for a shelf entry ────

class _ShelfEntry {
  final String path;
  final bool exists;
  final String? progressText;

  const _ShelfEntry({
    required this.path,
    required this.exists,
    this.progressText,
  });
}

// ──── ShelfScreen ────

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({Key? key}) : super(key: key);

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  List<_ShelfEntry> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShelf();
  }

  Future<void> _loadShelf() async {
    final paths = ShelfService.getShelf();
    final entries = <_ShelfEntry>[];
    for (final path in paths) {
      final exists = File(path).existsSync();
      String? progressText;
      if (exists) {
        try {
          final progress = await CosmosEpub.getBookProgress(path);
          if (progress.currentChapterIndex != null ||
              progress.currentPageIndex != null) {
            final chap = (progress.currentChapterIndex ?? 0) + 1;
            final page = (progress.currentPageIndex ?? 0) + 1;
            progressText = 'Chapter $chap, Page $page';
          }
        } catch (_) {
          // Non-fatal — show "Not started"
        }
      }
      entries.add(_ShelfEntry(
        path: path,
        exists: exists,
        progressText: progressText,
      ));
    }
    if (mounted) {
      setState(() {
        _books = entries;
        _loading = false;
      });
    }
  }

  Future<void> _removeBook(String path) async {
    await ShelfService.removeBook(path);
    await CosmosEpub.deleteBookProgress(path);
    CosmosEpub.removeAllHighlights(path);
    await _loadShelf();
  }

  Future<void> _pickAndOpenEpub() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file picker: $e')),
      );
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    await ShelfService.addBook(path);

    if (!mounted) return;
    try {
      await CosmosEpub.openLocalBook(
        localPath: path,
        bookId: path,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open book: $e')),
      );
    }
    await _loadShelf();
  }

  Future<void> _openBook(String path) async {
    if (!mounted) return;
    try {
      await CosmosEpub.openLocalBook(
        localPath: path,
        bookId: path,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open book: $e')),
      );
    }
    await _loadShelf();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear database'),
        content: const Text(
            'This will delete all reading progress and highlights. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final paths = ShelfService.getShelf();
    for (final path in paths) {
      try {
        await CosmosEpub.deleteBookProgress(path);
        CosmosEpub.removeAllHighlights(path);
      } catch (e) {
        debugPrint('Error clearing $path: $e');
      }
    }
    await CosmosEpub.deleteAllBooksProgress();
    await ShelfService.clearShelf();
    await _loadShelf();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All books and progress cleared.')),
    );
  }

  void _onTap(_ShelfEntry entry) {
    if (!entry.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File not found.'),
          action: SnackBarAction(
            label: 'Remove',
            onPressed: () => _removeBook(entry.path),
          ),
        ),
      );
      return;
    }
    _openBook(entry.path);
  }

  Future<void> _onLongPress(_ShelfEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from shelf?'),
        content: Text(basename(entry.path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _removeBook(entry.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosmosEpub Reader Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear database',
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? const Center(
                  child: Text(
                    'No books yet. Tap + to pick an EPUB.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (ctx, i) {
                    final entry = _books[i];
                    final color = entry.exists ? null : Colors.white38;
                    return ListTile(
                      leading: entry.exists
                          ? null
                          : const Icon(Icons.warning_amber,
                              color: Colors.orange),
                      title: Text(
                        basename(entry.path),
                        style: TextStyle(color: color),
                      ),
                      subtitle: Text(
                        entry.progressText ?? 'Not started',
                        style: TextStyle(color: color),
                      ),
                      onTap: () => _onTap(entry),
                      onLongPress: () => _onLongPress(entry),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpenEpub,
        icon: const Icon(Icons.add),
        label: const Text('Pick EPUB'),
      ),
    );
  }
}
