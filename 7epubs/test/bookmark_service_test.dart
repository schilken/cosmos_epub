import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seven_epubs/bookmark_service.dart';

class _FakeBookmarks implements SecureBookmarksInterface {
  String _nextBookmark = 'fake-bookmark-data';
  FileSystemEntity? _resolvedEntity;
  bool _startAccessResult = true;
  bool _stopAccessResult = true;
  bool _throwOnBookmark = false;

  @override
  Future<String> bookmark(FileSystemEntity entity) async {
    if (_throwOnBookmark) {
      throw Exception('bookmark failed');
    }
    return _nextBookmark;
  }

  @override
  Future<FileSystemEntity> resolveBookmark(String bookmark,
      {bool isDirectory = false}) async {
    return _resolvedEntity ?? (throw StateError('_resolvedEntity not set'));
  }

  @override
  Future<bool> startAccessingSecurityScopedResource(
      FileSystemEntity entity) async {
    return _startAccessResult;
  }

  @override
  Future<bool> stopAccessingSecurityScopedResource(
      FileSystemEntity entity) async {
    return _stopAccessResult;
  }
}

class _FakeStorage implements BookmarkStorageInterface {
  final Map<String, dynamic> _data = {};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  List<String> getKeys() => _data.keys.toList();
}

void main() {
  group('BookmarkService', () {
    late _FakeBookmarks fakeBookmarks;
    late _FakeStorage fakeStorage;
    late BookmarkService bookmarkService;

    setUp(() {
      fakeBookmarks = _FakeBookmarks();
      fakeStorage = _FakeStorage();
      bookmarkService = BookmarkService(
        bookmarks: fakeBookmarks,
        storage: fakeStorage,
        isMacOS: true,
      );
    });

    test('bookmarkFile returns bookmark string for valid file', () async {
      final tempFile = File('test_epub.epub');
      try {
        await tempFile.writeAsString('mock epub content');
        final result = await bookmarkService.bookmarkFile(tempFile.path);
        expect(result, isNotNull);
        expect(result, 'fake-bookmark-data');
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    });

    test('bookmarkFile stores bookmark in storage', () async {
      final tempFile = File('test_epub2.epub');
      try {
        await tempFile.writeAsString('mock epub content');
        await bookmarkService.bookmarkFile(tempFile.path);
        final key = 'bookmark_${tempFile.path}';
        expect(fakeStorage.read(key), 'fake-bookmark-data');
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    });

    test('resolveAndAccess returns true with stored bookmark', () async {
      final tempFile = File('test_resolve.epub');
      try {
        await tempFile.writeAsString('mock epub content');
        fakeBookmarks._resolvedEntity = tempFile;
        fakeBookmarks._startAccessResult = true;

        await fakeStorage.write('bookmark_${tempFile.path}', 'stored-bookmark');

        final result = await bookmarkService.resolveAndAccess(tempFile.path);
        expect(result, true);
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    });

    test('resolveAndAccess returns false with no stored bookmark', () async {
      final result =
          await bookmarkService.resolveAndAccess('/nonexistent/file.epub');
      expect(result, false);
    });

    test('bookmarkFile propagates exception from SecureBookmarks', () {
      fakeBookmarks._throwOnBookmark = true;
      expect(
        bookmarkService.bookmarkFile('/some/path.epub'),
        throwsA(isA<Exception>()),
      );
    });

    test('addDirectoryBookmark and getAuthorizedDirectories round-trip',
        () async {
      await bookmarkService.addDirectoryBookmark('/Users/test/books');
      final dirs = await bookmarkService.getAuthorizedDirectories();
      expect(dirs.length, 1);
      expect(dirs.first.path, '/Users/test/books');
    });

    test('removeDirectoryBookmark removes only targeted entry', () async {
      await bookmarkService.addDirectoryBookmark('/Users/test/books');
      await bookmarkService.addDirectoryBookmark('/Users/test/docs');
      var dirs = await bookmarkService.getAuthorizedDirectories();
      expect(dirs.length, 2);

      await bookmarkService.removeDirectoryBookmark(dirs.first.key);
      dirs = await bookmarkService.getAuthorizedDirectories();
      expect(dirs.length, 1);
      expect(dirs.first.path, '/Users/test/docs');
    });

    test('clearAll removes all bookmark keys but leaves non-bookmark keys',
        () async {
      await bookmarkService.bookmarkFile('/tmp/test.epub');
      await bookmarkService.addDirectoryBookmark('/Users/test');
      fakeStorage.write('other_key', 'should-survive');

      await bookmarkService.clearAll();

      expect(fakeStorage.read('bookmark_/tmp/test.epub'), isNull);
      expect(fakeStorage.read('authorized_directories'), isNull);
      expect(fakeStorage.read('other_key'), 'should-survive');
    });
  });
}
