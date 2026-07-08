class SearchResult {
  final int chapterIndex;
  final int matchStart;
  final int matchEnd;
  final String matchedText;
  final String contextBefore;
  final String contextAfter;
  int? pageIndex;

  SearchResult({
    required this.chapterIndex,
    required this.matchStart,
    required this.matchEnd,
    required this.matchedText,
    required this.contextBefore,
    required this.contextAfter,
    this.pageIndex,
  });

  Map<String, dynamic> toJson() => {
        'chapterIndex': chapterIndex,
        'matchStart': matchStart,
        'matchEnd': matchEnd,
        'matchedText': matchedText,
        'contextBefore': contextBefore,
        'contextAfter': contextAfter,
        'pageIndex': pageIndex,
      };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        chapterIndex: json['chapterIndex'] as int,
        matchStart: json['matchStart'] as int,
        matchEnd: json['matchEnd'] as int,
        matchedText: json['matchedText'] as String,
        contextBefore: json['contextBefore'] as String,
        contextAfter: json['contextAfter'] as String,
        pageIndex: json['pageIndex'] as int?,
      );

  @override
  String toString() =>
      'SearchResult(chapter: $chapterIndex, match: "$matchedText")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          chapterIndex == other.chapterIndex &&
          matchStart == other.matchStart &&
          matchEnd == other.matchEnd &&
          matchedText == other.matchedText &&
          contextBefore == other.contextBefore &&
          contextAfter == other.contextAfter &&
          pageIndex == other.pageIndex;

  @override
  int get hashCode => Object.hash(
        chapterIndex,
        matchStart,
        matchEnd,
        matchedText,
        contextBefore,
        contextAfter,
        pageIndex,
      );
}
