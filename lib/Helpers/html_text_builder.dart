import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

import '../Model/highlight_model.dart';
import 'html_table_parser.dart';
import 'soft_hyphen_text.dart';

/// Converts HTML content to Flutter widgets using native SelectableText.rich.
/// Each block element becomes a SoftHyphenParagraph with highlight support.
class HtmlTextBuilder {
  final double fontSize;
  final String? fontFamily;
  final String? fontPackage;
  final Color textColor;
  final TextAlign textAlign;
  final Color? accentColor;
  final VoidCallback? onTextTap;
  final List<HighlightModel> highlights;
  final void Function()? onHighlightChanged;
  final void Function(int paragraphStart, int paragraphEnd)? onParagraphTapped;

  /// Optional page content width used to decide whether a `<table>` needs a
  /// horizontal scroll wrapper. When null, tables always wrap-fit the page
  /// width (no scroll). The temp + final builders must be passed the same
  /// value so highlight offsets and the page key text stay identical.
  final double? maxWidth;

  /// When non-null, all occurrences of this text are rendered in bold
  /// (case-insensitive, exact match). Used by search result highlighting.
  final String? searchQuery;

  /// Cumulative offset tracking across blocks for highlight matching.
  int _pageOffset = 0;
  final StringBuffer _pageTextBuf = StringBuffer();

  /// The clean text built from blocks (same as what _pageOffset tracks).
  String get lastBuiltCleanText => _pageTextBuf.toString();

  HtmlTextBuilder({
    required this.fontSize,
    this.fontFamily,
    this.fontPackage,
    required this.textColor,
    this.textAlign = TextAlign.justify,
    this.accentColor,
    this.onTextTap,
    this.highlights = const [],
    this.onHighlightChanged,
    this.onParagraphTapped,
    this.maxWidth,
    this.searchQuery,
  });

  TextStyle get _baseStyle => TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        package: fontPackage,
        color: textColor,
        height: 1.4,
      );

  List<Widget> build(String html) {
    _pageOffset = 0;
    _pageTextBuf.clear();
    final fixedHtml = _fixXhtml(html);
    final doc = html_parser.parse(fixedHtml);
    final body = doc.body ?? doc.documentElement;
    if (body == null) return [Text(html, style: _baseStyle)];

    final widgets = <Widget>[];
    _collectWidgets(body, widgets);
    if (widgets.isEmpty) {
      final text = body.text.trim();
      if (text.isNotEmpty) {
        widgets.add(Text(text, style: _baseStyle, textAlign: textAlign));
      }
    }
    return widgets;
  }

  void _collectWidgets(html_dom.Node node, List<Widget> widgets) {
    for (final child in node.nodes) {
      if (child is html_dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';

        if (const {'script', 'style', 'head', 'meta', 'link', 'title'}
            .contains(tag)) continue;
        if (_isContainer(child)) {
          _collectWidgets(child, widgets);
          continue;
        }
        if (tag == 'img') {
          _addImage(child, widgets);
          continue;
        }
        if (tag == 'hr') {
          widgets.add(const Divider());
          continue;
        }
        if (tag == 'br') {
          widgets.add(SizedBox(height: fontSize * 0.5));
          continue;
        }
        if (tag == 'table') {
          _addTable(child, widgets);
          continue;
        }

        // Block element → build paragraph
        final spans = <InlineSpan>[];
        _buildSpans(child, spans, _styleForTag(tag));
        if (spans.isNotEmpty) {
          final span = TextSpan(children: spans);
          final blockClean = child.text.replaceAll('\u00AD', '');
          final blockStart = _pageOffset;
          _pageOffset += blockClean.length;
          _pageTextBuf.write(blockClean);

          final blockEnd = _pageOffset;
          final blockHighlights =
              _getBlockHighlights(blockStart, blockClean.length);

          widgets.add(Listener(
            onPointerDown: (_) => onParagraphTapped?.call(blockStart, blockEnd),
            child: Padding(
              padding: _paddingForTag(tag),
              child: SoftHyphenParagraph(
                textSpan: span,
                textAlign: textAlign,
                highlights: blockHighlights,
              ),
            ),
          ));
        }
      } else if (child is html_dom.Text) {
        final text = child.text.trim();
        if (text.isNotEmpty) {
          final searchSpans = _buildSearchSpans(text, _baseStyle);
          final span = TextSpan(children: searchSpans, style: _baseStyle);
          final blockClean = text.replaceAll('\u00AD', '');
          final blockStart = _pageOffset;
          _pageOffset += blockClean.length;
          _pageTextBuf.write(blockClean);

          final blockEnd = _pageOffset;
          final blockHighlights =
              _getBlockHighlights(blockStart, blockClean.length);

          widgets.add(Listener(
            onPointerDown: (_) => onParagraphTapped?.call(blockStart, blockEnd),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: fontSize * 0.3),
              child: SoftHyphenParagraph(
                textSpan: span,
                textAlign: textAlign,
                highlights: blockHighlights,
              ),
            ),
          ));
        }
      }
    }
  }

  /// Get highlights that overlap this block, with offsets adjusted to block-local.
  List<HighlightModel> _getBlockHighlights(int blockStart, int blockLen) {
    if (highlights.isEmpty) return [];
    final blockEnd = blockStart + blockLen;
    return highlights
        .where((h) => h.startIndex < blockEnd && h.endIndex > blockStart)
        .map((h) => HighlightModel(
              id: h.id,
              bookId: h.bookId,
              chapterIndex: h.chapterIndex,
              paragraphKey: h.paragraphKey,
              startIndex: (h.startIndex - blockStart).clamp(0, blockLen),
              endIndex: (h.endIndex - blockStart).clamp(0, blockLen),
              selectedText: h.selectedText,
              colorValue: h.colorValue,
              noteText: h.noteText,
            ))
        .toList();
  }

  void _buildSpans(
      html_dom.Node node, List<InlineSpan> spans, TextStyle style) {
    for (final child in node.nodes) {
      if (child is html_dom.Text) {
        final text = child.text;
        if (text.isNotEmpty) spans.addAll(_buildSearchSpans(text, style));
      } else if (child is html_dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';
        if (tag == 'br') {
          spans.add(const TextSpan(text: '\n'));
          continue;
        }
        if (tag == 'img') continue;
        _buildSpans(child, spans, _applyInlineTag(tag, style));
      }
    }
  }

  TextStyle _applyInlineTag(String tag, TextStyle base) {
    switch (tag) {
      case 'b' || 'strong':
        return base.copyWith(fontWeight: FontWeight.bold);
      case 'i' || 'em' || 'cite':
        return base.copyWith(fontStyle: FontStyle.italic);
      case 'u' || 'ins':
        return base.copyWith(decoration: TextDecoration.underline);
      case 's' || 'del' || 'strike':
        return base.copyWith(decoration: TextDecoration.lineThrough);
      case 'sup':
        return base.copyWith(fontSize: (base.fontSize ?? fontSize) * 0.7);
      case 'sub':
        return base.copyWith(fontSize: (base.fontSize ?? fontSize) * 0.7);
      case 'code':
        return base.copyWith(
            fontFamily: 'monospace',
            package: null,
            backgroundColor: textColor.withValues(alpha: 0.1));
      default:
        return base;
    }
  }

  List<InlineSpan> _buildSearchSpans(String text, TextStyle style) {
    final query = searchQuery;
    if (query == null || query.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    const shy = '\u00AD';
    final buffer = StringBuffer();
    for (int i = 0; i < query.length; i++) {
      if (i > 0) buffer.write('$shy?');
      buffer.write(RegExp.escape(query[i]));
    }
    final regex = RegExp(buffer.toString(), caseSensitive: false);

    final matches = regex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: style.copyWith(fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return spans;
  }

  TextStyle _styleForTag(String tag) {
    switch (tag) {
      case 'h1':
        return _baseStyle.copyWith(
            fontSize: fontSize * 2.0, fontWeight: FontWeight.bold);
      case 'h2':
        return _baseStyle.copyWith(
            fontSize: fontSize * 1.5, fontWeight: FontWeight.bold);
      case 'h3':
        return _baseStyle.copyWith(
            fontSize: fontSize * 1.17, fontWeight: FontWeight.bold);
      case 'h4':
        return _baseStyle.copyWith(fontWeight: FontWeight.bold);
      case 'h5':
        return _baseStyle.copyWith(
            fontSize: fontSize * 0.83, fontWeight: FontWeight.bold);
      case 'h6':
        return _baseStyle.copyWith(
            fontSize: fontSize * 0.67, fontWeight: FontWeight.bold);
      case 'blockquote':
        return _baseStyle.copyWith(fontStyle: FontStyle.italic);
      case 'pre' || 'code':
        return _baseStyle.copyWith(fontFamily: 'monospace', package: null);
      default:
        return _baseStyle;
    }
  }

  EdgeInsets _paddingForTag(String tag) {
    switch (tag) {
      case 'h1':
        return EdgeInsets.symmetric(vertical: fontSize * 0.8);
      case 'h2':
        return EdgeInsets.symmetric(vertical: fontSize * 0.6);
      case 'h3' || 'h4' || 'h5' || 'h6':
        return EdgeInsets.symmetric(vertical: fontSize * 0.4);
      case 'blockquote':
        return EdgeInsets.only(
            left: fontSize, top: fontSize * 0.3, bottom: fontSize * 0.3);
      case 'li':
        return EdgeInsets.only(
            left: fontSize, top: fontSize * 0.1, bottom: fontSize * 0.1);
      default:
        return EdgeInsets.symmetric(vertical: fontSize * 0.3);
    }
  }

  bool _isContainer(html_dom.Element element) {
    final tag = element.localName?.toLowerCase();
    if (const {
      'body',
      'html',
      'section',
      'article',
      'main',
      'aside',
      'nav',
      'header',
      'footer'
    }.contains(tag)) return true;
    if (tag == 'div' || tag == 'span') {
      final hasDirectText = element.nodes
          .any((n) => n is html_dom.Text && n.text.trim().isNotEmpty);
      if (!hasDirectText && element.children.isNotEmpty) return true;
    }
    return false;
  }

  /// Builds a Flutter `Table` widget from a `<table>` element.
  ///
  /// Each cell becomes a [SoftHyphenParagraph] so it participates in the
  /// surrounding selection area and keeps highlight offsets stable. Page text
  /// and `_pageOffset` are advanced per cell in reading order (thead first,
  /// then tbody/tfoot, top→bottom, left→right in DOM source order).
  ///
  /// When [maxWidth] is set and the table's intrinsic content width exceeds
  /// it, the table is wrapped in a horizontal [SingleChildScrollView] so wide
  /// tables can be panned without triggering the parent page-flip gesture.
  void _addTable(html_dom.Element tableEl, List<Widget> widgets) {
    final borderColor = textColor.withValues(alpha: 0.4);
    final headerBg = textColor.withValues(alpha: 0.08);

    final parser = HtmlTableParser(
      baseStyle: _baseStyle,
      spanBuilder: (cell, style) {
        final spans = <InlineSpan>[];
        _buildSpans(cell, spans, style);
        return spans;
      },
    );
    final parsed = parser.parse(tableEl);

    final tableRows = <TableRow>[];
    final colCount = _columnCount(parsed);
    final colWidths = _computeColumnWidths(parsed, colCount);
    final colWidthMap = <int, TableColumnWidth>{};
    for (var i = 0; i < colCount; i++) {
      colWidthMap[i] = FixedColumnWidth(colWidths[i]);
    }

    for (final row in parsed.rows) {
      final cellWidgets = <Widget>[];
      for (final cell in row.cells) {
        final cellClean = cell.cleanText;
        final blockStart = _pageOffset;
        _pageOffset += cellClean.length;
        _pageTextBuf.write(cellClean);
        final blockHighlights =
            _getBlockHighlights(blockStart, cellClean.length);

        Widget cellChild = Listener(
          onPointerDown: (_) =>
              onParagraphTapped?.call(blockStart, _pageOffset),
          child: Padding(
            padding: EdgeInsets.all(fontSize * 0.25),
            child: SoftHyphenParagraph(
              textSpan: TextSpan(children: cell.textSpans),
              textAlign: textAlign,
              highlights: blockHighlights,
            ),
          ),
        );

        if (cell.isHeader) {
          cellChild = ColoredBox(
            color: headerBg,
            child: cellChild,
          );
        }
        cellWidgets.add(cellChild);
      }
      tableRows.add(TableRow(children: cellWidgets));
    }

    final table = Table(
      border: TableBorder.all(width: 1, color: borderColor),
      columnWidths: colWidthMap,
      defaultColumnWidth: const FixedColumnWidth(0),
      children: tableRows,
    );

    Widget tableWidget;
    final maxWidth = this.maxWidth;
    if (maxWidth != null && maxWidth.isFinite && maxWidth > 0) {
      // Sum pre-measured column widths to decide whether a horizontal scroll
      // wrapper is needed. Doing this at build time avoids the
      // LayoutBuilder/IntrinsicWidth interaction that breaks Table layout when
      // cells use SoftHyphenParagraph (which itself wraps content in a
      // LayoutBuilder that doesn't support intrinsic dimensions).
      final measured = colWidths.fold<double>(1.0, (a, b) => a + b);
      if (measured <= maxWidth) {
        tableWidget = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: table,
        );
      } else {
        tableWidget = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(child: table),
        );
      }
    } else {
      tableWidget = table;
    }

    widgets.add(Padding(
      padding: EdgeInsets.symmetric(vertical: fontSize * 0.3),
      child: tableWidget,
    ));
  }

  /// Number of columns the parsed table occupies. Honors colspan.
  int _columnCount(ParsedTable parsed) {
    var maxCols = 0;
    for (final row in parsed.rows) {
      var cols = 0;
      for (final cell in row.cells) {
        cols += cell.columnSpan;
      }
      if (cols > maxCols) maxCols = cols;
    }
    return maxCols;
  }

  /// Per-column max cell content width in px. Accounts for the cell horizontal
  /// padding (`fontSize * 0.25` on each side) plus one border width (1.0).
  /// For colspan > 1, distributes the cell width across the spanned columns.
  List<double> _computeColumnWidths(ParsedTable parsed, int colCount) {
    final widths = List<double>.filled(colCount, 0.0);
    for (final row in parsed.rows) {
      var colIndex = 0;
      for (final cell in row.cells) {
        final painter = TextPainter(
          text: TextSpan(
            children: cell.textSpans,
            style: cell.isHeader
                ? _baseStyle.copyWith(fontWeight: FontWeight.bold)
                : _baseStyle,
          ),
          textAlign: textAlign,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        painter.layout(maxWidth: double.infinity);
        final cellWidth =
            painter.width + fontSize * 0.5 /* padding L+R */ + 1.0 /* border */;
        painter.dispose();
        final span = cell.columnSpan;
        for (var s = 0; s < span && colIndex < colCount; s++) {
          if (cellWidth > widths[colIndex]) widths[colIndex] = cellWidth;
          colIndex++;
        }
      }
    }
    return widths;
  }

  void _addImage(html_dom.Element img, List<Widget> widgets) {
    final src = img.attributes['src'] ?? '';
    if (src.startsWith('data:')) {
      try {
        if (src.split(',').length == 2) {
          final bytes = UriData.parse(src).contentAsBytes();
          widgets.add(Padding(
            padding: EdgeInsets.symmetric(vertical: fontSize * 0.3),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ));
        }
      } catch (_) {}
    }
  }

  static String getPageCleanText(String pageHtml) {
    final fixed = _fixXhtml(pageHtml);
    final doc = html_parser.parse(fixed);
    return (doc.body ?? doc.documentElement)?.text.replaceAll('\u00AD', '') ??
        '';
  }

  static String _fixXhtml(String html) {
    html = html.replaceAllMapped(
      RegExp(
          r'<(title|script|textarea|style|div|span|p|a|table|tbody|tr|td|th|ul|ol|li|h[1-6]|section|article|aside|header|footer|nav|main|blockquote|pre|code|em|strong|b|i|u|sub|sup|dd|dt|dl|figure|figcaption|details|summary)(\s[^>]*)?\s*/>',
          caseSensitive: false),
      (match) =>
          '<${match.group(1)}${match.group(2) ?? ''}></${match.group(1)}>',
    );
    html = html.replaceAll(RegExp(r'<\?xml[^?]*\?>'), '');
    return html;
  }
}
