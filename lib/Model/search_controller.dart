import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../Component/constants.dart';
import '../Helpers/search_service.dart';
import 'chapter_model.dart';
import 'search_result.dart';

class EpubSearchController extends ChangeNotifier {
  final SearchService _searchService = SearchService();
  List<LocalChapterModel> _chapters = [];

  List<SearchResult> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isActive = false;

  List<SearchResult> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isActive => _isActive;

  set isActive(bool value) {
    _isActive = value;
    notifyListeners();
  }

  void setChapters(List<LocalChapterModel> chapters) {
    _chapters = chapters;
  }

  void search(String query) {
    if (query.trim().isEmpty) {
      _errorMessage = 'Please enter a search term';
      _results = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 10), () {
      _results = _searchService.searchAllChapters(_chapters, query.trim());
      _isLoading = false;
      notifyListeners();
    });
  }

  void loadFromStorage(String bookId) {
    final gs = GetStorage();
    final key = '$libSearchPrefix$bookId';
    final raw = gs.read<String>(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        _results = list;
        _isActive = true;
        notifyListeners();
      } catch (_) {
        _results = [];
        _isActive = false;
      }
    }
  }

  void saveToStorage(String bookId) {
    final gs = GetStorage();
    final key = '$libSearchPrefix$bookId';
    final encoded = jsonEncode(_results.map((r) => r.toJson()).toList());
    gs.write(key, encoded);
  }

  void clear() {
    _results = [];
    _isLoading = false;
    _errorMessage = null;
    _isActive = false;
    notifyListeners();
  }

  void clearStorage(String bookId) {
    final gs = GetStorage();
    final key = '$libSearchPrefix$bookId';
    gs.remove(key);
  }
}
