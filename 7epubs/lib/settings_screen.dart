import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'bookmark_service.dart';

class SettingsScreen extends StatefulWidget {
  final BookmarkService bookmarkService;

  const SettingsScreen({Key? key, required this.bookmarkService})
      : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<AuthorizedDirectory> _directories = [];

  @override
  void initState() {
    super.initState();
    _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    final dirs = await widget.bookmarkService.getAuthorizedDirectories();
    if (mounted) {
      setState(() => _directories = dirs);
    }
  }

  Future<void> _pickDirectory() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;

      await widget.bookmarkService.addDirectoryBookmark(path);
      await _loadDirectories();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Directory access granted: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not secure access to this directory.')),
      );
    }
  }

  Future<void> _removeDirectory(AuthorizedDirectory dir) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove directory?'),
        content: Text(dir.path),
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
    if (confirmed != true) return;

    await widget.bookmarkService.removeDirectoryBookmark(dir.key);
    await _loadDirectories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  key: const Key('allow-directory-btn'),
                  onPressed: _pickDirectory,
                  child: const Text('Allow access to directory'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authorizing your home directory grants access to all EPUB files within it.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _directories.isEmpty
                ? const Center(
                    child: Text(
                      'No directories authorized',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView(
                    key: const Key('directory-list'),
                    children: _directories.map((dir) {
                      return ListTile(
                        title: Text(dir.path),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeDirectory(dir),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
