import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seven_epubs/bookmark_service.dart';
import 'package:seven_epubs/settings_screen.dart';

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

class _FakeBookmarks implements SecureBookmarksInterface {
  int _callCount = 0;

  @override
  Future<String> bookmark(FileSystemEntity entity) async {
    _callCount++;
    return 'dir-bookmark-$_callCount';
  }

  @override
  Future<FileSystemEntity> resolveBookmark(String bookmark,
      {bool isDirectory = false}) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> startAccessingSecurityScopedResource(
      FileSystemEntity entity) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> stopAccessingSecurityScopedResource(
      FileSystemEntity entity) async {
    throw UnimplementedError();
  }
}

void main() {
  group('SettingsScreen', () {
    late _FakeStorage fakeStorage;
    late BookmarkService bookmarkService;

    setUp(() {
      fakeStorage = _FakeStorage();
      bookmarkService = BookmarkService(
        bookmarks: _FakeBookmarks(),
        storage: fakeStorage,
        isMacOS: true,
      );
    });

    testWidgets('shows empty state when no directories authorized',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(bookmarkService: bookmarkService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No directories authorized'), findsOneWidget);
    });

    testWidgets('renders list tiles when bookmarked directories exist',
        (tester) async {
      await fakeStorage.write('authorized_directories', [
        {'key': 'bookmark_dir_aaa', 'path': '/Users/test/books'},
        {'key': 'bookmark_dir_bbb', 'path': '/Users/test/docs'},
      ]);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(bookmarkService: bookmarkService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No directories authorized'), findsNothing);
      expect(find.text('/Users/test/books'), findsOneWidget);
      expect(find.text('/Users/test/docs'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNWidgets(2));
    });

    testWidgets('tapping delete on a directory tile removes it',
        (tester) async {
      await fakeStorage.write('authorized_directories', [
        {'key': 'bookmark_dir_aaa', 'path': '/Users/test/books'},
        {'key': 'bookmark_dir_bbb', 'path': '/Users/test/docs'},
      ]);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(bookmarkService: bookmarkService),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      expect(find.text('Remove directory?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('/Users/test/books'), findsNothing);
      expect(find.text('/Users/test/docs'), findsOneWidget);
    });

    testWidgets('"Allow access to directory" button is visible',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(bookmarkService: bookmarkService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Allow access to directory'), findsOneWidget);
      expect(find.byKey(const Key('allow-directory-btn')), findsOneWidget);
    });
  });
}
