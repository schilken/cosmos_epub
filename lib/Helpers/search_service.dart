import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../Model/chapter_model.dart';
import '../Model/search_result.dart';

class SearchService {
  List<SearchResult> searchAllChapters(
      List<LocalChapterModel> chapters, String query) {
    if (query.isEmpty) return [];

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (var chapterIdx = 0; chapterIdx < chapters.length; chapterIdx++) {
      final chapter = chapters[chapterIdx];
      try {
        final doc = html_parser.parse(chapter.htmlContent);
        final body = doc.body ?? doc.documentElement;
        if (body == null) continue;

        _removeNonContentElements(body);

        final plainText = body.text;
        if (plainText.isEmpty) continue;

        final lowerText = plainText.toLowerCase();
        if (lowerText.isEmpty) continue;

        var searchFrom = 0;
        while (true) {
          final matchIdx = lowerText.indexOf(lowerQuery, searchFrom);
          if (matchIdx == -1) break;

          final matchEnd = matchIdx + query.length;
          final matchedText = plainText.substring(matchIdx, matchEnd);
          final before = _contextBefore(plainText, matchIdx);
          final after = _contextAfter(plainText, matchEnd);

          results.add(SearchResult(
            chapterIndex: chapterIdx,
            matchStart: matchIdx,
            matchEnd: matchEnd,
            matchedText: matchedText,
            contextBefore: before,
            contextAfter: after,
          ));

          searchFrom = matchEnd;
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  static void _removeNonContentElements(html_dom.Element body) {
    final toRemove =
        body.querySelectorAll('script, style, head, meta, link, title');
    for (final el in toRemove) {
      el.remove();
    }
  }

  static String _contextBefore(String text, int matchStart) {
    final target = (matchStart - 100).clamp(0, matchStart);
    if (target == 0) return text.substring(0, matchStart);

    var start = target;

    if (start > 0 && text[start] != ' ' && text[start] != '\n') {
      final prevSpace = start > 0 ? text.lastIndexOf(' ', start - 1) : -1;
      final prevPara = start > 1 ? text.lastIndexOf('\n\n', start - 1) : -1;

      int boundary;
      if (prevSpace >= 0 && prevPara >= 0) {
        boundary = prevSpace > prevPara ? prevSpace : prevPara + 1;
      } else if (prevSpace >= 0) {
        boundary = prevSpace;
      } else if (prevPara >= 0) {
        boundary = prevPara + 1;
      } else {
        boundary = -1;
      }

      if (boundary >= 0 && boundary < start) {
        start = boundary + 1;
      } else {
        start = 0;
      }
    }

    final paraIdx = text.indexOf('\n\n', start);
    if (paraIdx >= 0 && paraIdx < matchStart) {
      start = paraIdx + 2;
    }

    while (start < matchStart && (text[start] == ' ' || text[start] == '\n')) {
      start++;
    }

    if (start >= matchStart) return '';
    return text.substring(start, matchStart);
  }

  static String _contextAfter(String text, int matchEnd) {
    final target = (matchEnd + 100).clamp(0, text.length);
    if (target >= text.length) return text.substring(matchEnd);

    var end = target;

    if (end < text.length && text[end] != ' ' && text[end] != '\n') {
      final nextSpace = text.indexOf(' ', end);
      final nextPara = text.indexOf('\n\n', end);

      int boundary;
      if (nextSpace >= 0 && nextPara >= 0) {
        boundary = nextSpace < nextPara ? nextSpace : nextPara;
      } else if (nextSpace >= 0) {
        boundary = nextSpace;
      } else if (nextPara >= 0) {
        boundary = nextPara;
      } else {
        boundary = text.length;
      }

      end = boundary;
    }

    final paraIdx = text.indexOf('\n\n', matchEnd);
    if (paraIdx >= 0 && paraIdx < end) {
      end = paraIdx;
    }

    return text.substring(matchEnd, end);
  }
}

int findPageContainingMatch(List<String> pageHtmlFragments, String matchText) {
  if (pageHtmlFragments.isEmpty || matchText.isEmpty) return -1;

  final query = matchText.toLowerCase();

  for (var i = 0; i < pageHtmlFragments.length; i++) {
    try {
      final doc = html_parser.parse(pageHtmlFragments[i]);
      final body = doc.body ?? doc.documentElement;
      if (body == null) continue;

      SearchService._removeNonContentElements(body);

      final text = body.text;
      if (text.isEmpty) continue;

      if (text.toLowerCase().contains(query)) return i;
    } catch (_) {
      continue;
    }
  }

  return -1;
}
