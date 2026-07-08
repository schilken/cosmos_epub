library cosmos_epub;

import 'dart:io';

import 'package:cosmos_epub/Component/constants.dart';
import 'package:cosmos_epub/Database/app_database.dart';
import 'package:cosmos_epub/Helpers/drift_progress_service.dart';
import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:cosmos_epub/Model/highlight_model.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

/// Main entry point for the CosmosEpub reader.
///
/// Call [initialize] once before using any other methods.
/// Then use [openAssetBook], [openLocalBook], [openFileBook], or [openURLBook]
/// to open an EPUB file in the reader.
class CosmosEpub {
  static bool _initialized = false;
  static final GlobalKey<ShowEpubState> _showEpubKey =
      GlobalKey<ShowEpubState>();

  // ──── Initialization ────

  /// Initialize the reader. Must be called once before opening any book.
  static Future<bool> initialize() async {
    await GetStorage.init();
    final db = AppDatabase();
    bookProgress = DriftProgressService(db);
    _initialized = true;
    return true;
  }

  // ──── Open Book ────

  /// Open an EPUB from a local file path.
  static Future<void> openLocalBook({
    required String localPath,
    required BuildContext context,
    required String bookId,
    Color accentColor = Colors.indigoAccent,
    Function(int currentPage, int totalPages)? onPageFlip,
    Function(int lastPageIndex)? onLastPage,
    String chapterListTitle = 'Table of Contents',
    bool shouldOpenDrawer = false,
    int starterChapter = -1,
  }) async {
    var bytes = File(localPath).readAsBytesSync();
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());
    if (!context.mounted) return;
    _openBook(
      context: context,
      epubBook: epubBook,
      bookId: bookId,
      shouldOpenDrawer: shouldOpenDrawer,
      starterChapter: starterChapter,
      chapterListTitle: chapterListTitle,
      onPageFlip: onPageFlip,
      onLastPage: onLastPage,
      accentColor: accentColor,
    );
  }

  /// Open an EPUB from raw bytes (Uint8List).
  static Future<void> openFileBook({
    required Uint8List bytes,
    required BuildContext context,
    required String bookId,
    Color accentColor = Colors.indigoAccent,
    Function(int currentPage, int totalPages)? onPageFlip,
    Function(int lastPageIndex)? onLastPage,
    String chapterListTitle = 'Table of Contents',
    bool shouldOpenDrawer = false,
    int starterChapter = -1,
  }) async {
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());
    if (!context.mounted) return;
    _openBook(
      context: context,
      epubBook: epubBook,
      bookId: bookId,
      shouldOpenDrawer: shouldOpenDrawer,
      starterChapter: starterChapter,
      chapterListTitle: chapterListTitle,
      onPageFlip: onPageFlip,
      onLastPage: onLastPage,
      accentColor: accentColor,
    );
  }

  /// Open an EPUB from a URL.
  static Future<void> openURLBook({
    required String urlPath,
    required BuildContext context,
    required String bookId,
    Color accentColor = Colors.indigoAccent,
    Function(int currentPage, int totalPages)? onPageFlip,
    Function(int lastPageIndex)? onLastPage,
    String chapterListTitle = 'Table of Contents',
    bool shouldOpenDrawer = false,
    int starterChapter = -1,
  }) async {
    final result = await http.get(Uri.parse(urlPath));
    final bytes = result.bodyBytes;
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());
    if (!context.mounted) return;
    _openBook(
      context: context,
      epubBook: epubBook,
      bookId: bookId,
      shouldOpenDrawer: shouldOpenDrawer,
      starterChapter: starterChapter,
      chapterListTitle: chapterListTitle,
      onPageFlip: onPageFlip,
      onLastPage: onLastPage,
      accentColor: accentColor,
    );
  }

  /// Open an EPUB from Flutter assets.
  static Future<void> openAssetBook({
    required String assetPath,
    required BuildContext context,
    required String bookId,
    Color accentColor = Colors.indigoAccent,
    Function(int currentPage, int totalPages)? onPageFlip,
    Function(int lastPageIndex)? onLastPage,
    String chapterListTitle = 'Table of Contents',
    bool shouldOpenDrawer = false,
    int starterChapter = -1,
  }) async {
    var bytes = await rootBundle.load(assetPath);
    EpubBook epubBook = await EpubReader.readBook(bytes.buffer.asUint8List());
    if (!context.mounted) return;
    _openBook(
      context: context,
      epubBook: epubBook,
      bookId: bookId,
      shouldOpenDrawer: shouldOpenDrawer,
      starterChapter: starterChapter,
      chapterListTitle: chapterListTitle,
      onPageFlip: onPageFlip,
      onLastPage: onLastPage,
      accentColor: accentColor,
    );
  }

  // ──── Progress Management ────

  /// Get the reading progress for a book.
  static Future<BookProgressModel> getBookProgress(String bookId) async {
    return await bookProgress.getBookProgress(bookId);
  }

  /// Set the current page index for a book.
  static Future<bool> setCurrentPageIndex(String bookId, int index) async {
    return await bookProgress.setCurrentPageIndex(bookId, index);
  }

  /// Set the current chapter index for a book.
  static Future<bool> setCurrentChapterIndex(String bookId, int index) async {
    return await bookProgress.setCurrentChapterIndex(bookId, index);
  }

  /// Jump to a specific chapter and page in the currently open book.
  static void jumpToChapter(String bookId, int chapterIndex, int pageIndex) {
    _checkInitialization();
    _showEpubKey.currentState?.jumpToChapter(chapterIndex, pageIndex);
  }

  /// Delete reading progress for a specific book.
  static Future<bool> deleteBookProgress(String bookId) async {
    return await bookProgress.deleteBookProgress(bookId);
  }

  /// Delete reading progress for all books.
  static Future<bool> deleteAllBooksProgress() async {
    return await bookProgress.deleteAllBooksProgress();
  }

  // ──── Highlight Management ────

  /// Get all highlights for a book.
  static List<HighlightModel> getBookHighlights(String bookId) {
    return HighlightStorage.getBookHighlights(bookId);
  }

  /// Remove a specific highlight by ID.
  static void removeHighlight(String highlightId) {
    HighlightStorage.removeHighlight(highlightId);
  }

  /// Remove all highlights for a book.
  static void removeAllHighlights(String bookId) {
    HighlightStorage.removeAllForBook(bookId);
  }

  // ──── Note Management ────

  /// Get all notes for a book.
  static List<HighlightModel> getBookNotes(String bookId) {
    return HighlightStorage.getBookNotes(bookId);
  }

  /// Remove a note by ID.
  static void removeNote(String id) {
    HighlightStorage.removeNote(id);
  }

  // ──── Theme ────

  /// Clear cached theme, font, and font size preferences.
  static Future<bool> clearThemeCache() async {
    if (await GetStorage().initStorage) {
      var get = GetStorage();
      await get.remove(libTheme);
      await get.remove(libFont);
      await get.remove(libFontSize);
      return true;
    }
    return false;
  }

  // ──── Internal ────

  static void _checkInitialization() {
    if (!_initialized) {
      throw Exception(
        'CosmosEpub is not initialized. '
        'Call CosmosEpub.initialize() before using other methods.',
      );
    }
  }

  static _openBook({
    required BuildContext context,
    required EpubBook epubBook,
    required String bookId,
    required bool shouldOpenDrawer,
    required Color accentColor,
    required int starterChapter,
    required String chapterListTitle,
    Function(int currentPage, int totalPages)? onPageFlip,
    Function(int lastPageIndex)? onLastPage,
  }) async {
    _checkInitialization();

    if (starterChapter != -1) {
      await bookProgress.setCurrentChapterIndex(bookId, starterChapter);
      await bookProgress.setCurrentPageIndex(bookId, 0);
    }

    final progress = await bookProgress.getBookProgress(bookId);
    var route = MaterialPageRoute(
      builder: (context) {
        return ShowEpub(
          key: _showEpubKey,
          epubBook: epubBook,
          starterChapter: starterChapter >= 0
              ? starterChapter
              : progress.currentChapterIndex ?? 0,
          shouldOpenDrawer: shouldOpenDrawer,
          bookId: bookId,
          accentColor: accentColor,
          chapterListTitle: chapterListTitle,
          onPageFlip: onPageFlip,
          onLastPage: onLastPage,
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      shouldOpenDrawer || starterChapter != -1
          ? Navigator.pushReplacement(context, route)
          : Navigator.push(context, route);
    });
  }
}
