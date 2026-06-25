import 'dart:io';

import 'package:seven_epubs/bookmark_service.dart';

class FakeSecureBookmarks implements SecureBookmarksInterface {
  final Map<String, String> _bookmarks = {};
  final Map<String, FileSystemEntity> _resolvedEntities = {};
  bool startAccessResult = true;

  @override
  Future<String> bookmark(FileSystemEntity entity) async {
    final data = 'bookmark-${entity.path}';
    _bookmarks[entity.path] = data;
    _resolvedEntities[data] = entity;
    return data;
  }

  @override
  Future<FileSystemEntity> resolveBookmark(String bookmark,
      {bool isDirectory = false}) async {
    return _resolvedEntities[bookmark] ??
        (throw StateError('Bookmark not found: $bookmark'));
  }

  @override
  Future<bool> startAccessingSecurityScopedResource(
      FileSystemEntity entity) async {
    return startAccessResult;
  }

  @override
  Future<bool> stopAccessingSecurityScopedResource(
      FileSystemEntity entity) async {
    return true;
  }
}

class FakeStorage implements BookmarkStorageInterface {
  final Map<String, dynamic> data = {};

  @override
  dynamic read(String key) => data[key];

  @override
  Future<void> write(String key, dynamic value) async {
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }

  @override
  List<String> getKeys() => data.keys.toList();
}

class BookmarkTestHarness {
  final FakeSecureBookmarks fakeBookmarks = FakeSecureBookmarks();
  final FakeStorage fakeStorage = FakeStorage();

  BookmarkService createService() {
    return BookmarkService(
      bookmarks: fakeBookmarks,
      storage: fakeStorage,
      isMacOS: true,
    );
  }
}
