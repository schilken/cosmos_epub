import 'dart:io';

import 'package:get_storage/get_storage.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

abstract class SecureBookmarksInterface {
  Future<String> bookmark(FileSystemEntity entity);
  Future<FileSystemEntity> resolveBookmark(String bookmark,
      {bool isDirectory = false});
  Future<bool> startAccessingSecurityScopedResource(FileSystemEntity entity);
  Future<bool> stopAccessingSecurityScopedResource(FileSystemEntity entity);
}

abstract class BookmarkStorageInterface {
  dynamic read(String key);
  Future<void> write(String key, dynamic value);
  Future<void> remove(String key);
  List<String> getKeys();
}

class _RealSecureBookmarks implements SecureBookmarksInterface {
  final SecureBookmarks _delegate = SecureBookmarks();

  @override
  Future<String> bookmark(FileSystemEntity entity) =>
      _delegate.bookmark(entity);

  @override
  Future<FileSystemEntity> resolveBookmark(String bookmark,
          {bool isDirectory = false}) =>
      _delegate.resolveBookmark(bookmark, isDirectory: isDirectory);

  @override
  Future<bool> startAccessingSecurityScopedResource(FileSystemEntity entity) =>
      _delegate.startAccessingSecurityScopedResource(entity);

  @override
  Future<bool> stopAccessingSecurityScopedResource(FileSystemEntity entity) =>
      _delegate.stopAccessingSecurityScopedResource(entity);
}

class _GetStorageAdapter implements BookmarkStorageInterface {
  final GetStorage _storage;

  _GetStorageAdapter(this._storage);

  @override
  dynamic read(String key) => _storage.read(key);

  @override
  Future<void> write(String key, dynamic value) => _storage.write(key, value);

  @override
  Future<void> remove(String key) => _storage.remove(key);

  @override
  List<String> getKeys() => _storage.getKeys().whereType<String>().toList();
}

class BookmarkService {
  final SecureBookmarksInterface _bookmarks;
  final BookmarkStorageInterface _storage;
  final bool _isMacOS;

  BookmarkService({
    SecureBookmarksInterface? bookmarks,
    BookmarkStorageInterface? storage,
    bool? isMacOS,
  })  : _bookmarks = bookmarks ?? _RealSecureBookmarks(),
        _storage = storage ?? _GetStorageAdapter(GetStorage()),
        _isMacOS = isMacOS ?? Platform.isMacOS;

  Future<String?> bookmarkFile(String path) async {
    if (!_isMacOS) return null;

    final file = File(path);
    final key = 'bookmark_$path';
    final data = await _bookmarks.bookmark(file);
    await _storage.write(key, data);
    return data;
  }

  Future<bool> resolveAndAccess(String path) async {
    if (!_isMacOS) return false;

    final key = 'bookmark_$path';
    final data = _storage.read(key) as String?;
    if (data == null) return false;

    final entity = await _bookmarks.resolveBookmark(data);
    return _bookmarks.startAccessingSecurityScopedResource(entity);
  }

  Future<String?> getBookmark(String path) async {
    if (!Platform.isMacOS) return null;

    final key = 'bookmark_$path';
    return _storage.read(key) as String?;
  }

  Future<void> stopAccessing(String path) async {
    if (!Platform.isMacOS) return;

    final key = 'bookmark_$path';
    final data = _storage.read(key) as String?;
    if (data == null) return;

    final entity = await _bookmarks.resolveBookmark(data);
    await _bookmarks.stopAccessingSecurityScopedResource(entity);
  }

  Future<void> removeBookmark(String path) async {
    if (!Platform.isMacOS) return;

    final key = 'bookmark_$path';
    await _storage.remove(key);
  }

  Future<void> addDirectoryBookmark(String dirPath) async {
    if (!Platform.isMacOS) return;

    final dir = Directory(dirPath);
    final bookmarkData = await _bookmarks.bookmark(dir);
    final uuid = _uuid();
    final key = 'bookmark_dir_$uuid';
    await _storage.write(key, bookmarkData);

    final dirs = _readDirectoryEntries();
    dirs.add({'key': key, 'path': dirPath});
    await _writeDirectoryEntries(dirs);
  }

  Future<void> clearAll() async {
    if (!Platform.isMacOS) return;

    final keys = _storage.getKeys();
    for (final key in keys) {
      if (key.startsWith('bookmark_') || key == 'authorized_directories') {
        await _storage.remove(key);
      }
    }
  }

  Future<void> removeDirectoryBookmark(String entryKey) async {
    if (!Platform.isMacOS) return;

    await _storage.remove(entryKey);
    final dirs = _readDirectoryEntries();
    dirs.removeWhere((e) => e['key'] == entryKey);
    await _writeDirectoryEntries(dirs);
  }

  Future<List<AuthorizedDirectory>> getAuthorizedDirectories() async {
    final dirs = _readDirectoryEntries();
    return dirs
        .map((e) => AuthorizedDirectory(
              key: e['key'] as String,
              path: e['path'] as String,
            ))
        .toList();
  }

  List<Map<String, dynamic>> _readDirectoryEntries() {
    final raw = _storage.read('authorized_directories');
    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<void> _writeDirectoryEntries(
      List<Map<String, dynamic>> entries) async {
    await _storage.write('authorized_directories', entries);
  }

  String _uuid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      final idx = DateTime.now().microsecondsSinceEpoch % chars.length;
      buf.write(chars[idx]);
    }
    return buf.toString();
  }
}

class AuthorizedDirectory {
  final String key;
  final String path;

  const AuthorizedDirectory({required this.key, required this.path});
}
