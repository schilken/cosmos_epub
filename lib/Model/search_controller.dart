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
  String? _lastQuery;

  List<SearchResult> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isActive => _isActive;
  String? get query => _lastQuery;

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
      _lastQuery = null;
      notifyListeners();
      return;
    }

    _lastQuery = query.trim();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 10), () {
      _results = _searchService.searchAllChapters(_chapters, _lastQuery!);
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
    final queryKey = '${key}_query';
    _lastQuery = gs.read<String>(queryKey);
  }

  void saveToStorage(String bookId) {
    final gs = GetStorage();
    final key = '$libSearchPrefix$bookId';
    final encoded = jsonEncode(_results.map((r) => r.toJson()).toList());
    gs.write(key, encoded);
    final queryKey = '${key}_query';
    if (_lastQuery != null) {
      gs.write(queryKey, _lastQuery);
    } else {
      gs.remove(queryKey);
    }
  }

  void clear() {
    _results = [];
    _isLoading = false;
    _errorMessage = null;
    _isActive = false;
    _lastQuery = null;
    notifyListeners();
  }

  void clearStorage(String bookId) {
    final gs = GetStorage();
    final key = '$libSearchPrefix$bookId';
    gs.remove(key);
    gs.remove('${key}_query');
  }
}
