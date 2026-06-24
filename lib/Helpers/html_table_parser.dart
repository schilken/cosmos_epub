import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html_dom;

/// Builds the inline spans for a single table cell element.
///
/// The parser stays pure (no widget dependencies); callers (e.g.
/// [HtmlTextBuilder]) inject this so cell text formatting matches the
/// surrounding reader while keeping the parser testable in isolation.
typedef HtmlTableSpanBuilder = List<InlineSpan> Function(
  html_dom.Element cellElement,
  TextStyle baseStyle,
);

/// Structured representation of a parsed `<table>` element.
class ParsedTable {
  final List<ParsedTableRow> rows;
  ParsedTable(this.rows);
}

/// A single row inside a [ParsedTable].
class ParsedTableRow {
  final List<ParsedCell> cells;
  final bool isHeader;
  ParsedTableRow(this.cells, {required this.isHeader});
}

/// A single `<td>`/`<th>` cell inside a [ParsedTableRow].
class ParsedCell {
  final List<InlineSpan> textSpans;
  final String cleanText;
  final bool isHeader;
  final int columnSpan;
  final int rowSpan;

  ParsedCell({
    required this.textSpans,
    required this.cleanText,
    required this.isHeader,
    this.columnSpan = 1,
    this.rowSpan = 1,
  });
}

/// Pure helper that converts an `<table>` element into a structured
/// [ParsedTable]. Reads `<thead>/<tbody>/<tfoot>/<tr>/<th>/<td>`. Treats
/// `<th>` cells (anywhere) and every row inside `<thead>` as header.
/// Honors `colspan`/`rowspan` via [columnSpan]/[rowSpan].
class HtmlTableParser {
  final TextStyle baseStyle;
  final HtmlTableSpanBuilder spanBuilder;

  HtmlTableParser({
    required this.baseStyle,
    required this.spanBuilder,
  });
  ParsedTable parse(html_dom.Element tableElement) {
    final rows = <ParsedTableRow>[];

    // Walk direct children once. Direct `<tr>` (no section) form an implicit
    // body whose first row counts as the header only when its cells are `<th>`.
    // `<thead>/<tbody>/<tfoot>` are processed in source order; rows inside
    // `<thead>` are always header rows.
    final directRows = <html_dom.Element>[];
    final sections = <html_dom.Element>[];

    for (final child in tableElement.children) {
      final tag = child.localName?.toLowerCase() ?? '';
      if (tag == 'tr') {
        directRows.add(child);
      } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
        sections.add(child);
      }
    }

    if (sections.isEmpty) {
      for (var i = 0; i < directRows.length; i++) {
        final tr = directRows[i];
        final cells = _parseCells(tr, isSectionHeader: false);
        rows.add(
            ParsedTableRow(cells, isHeader: _rowIsHeaderByTh(cells, i == 0)));
      }
    } else {
      for (final section in sections) {
        final sectionTag = section.localName?.toLowerCase() ?? '';
        final isThead = sectionTag == 'thead';
        var trIndexInSection = 0;
        for (final tr in section.children) {
          if ((tr.localName?.toLowerCase() ?? '') != 'tr') continue;
          final cells = _parseCells(tr, isSectionHeader: isThead);
          // A row is a header row when:
          //  - it's inside <thead>, OR
          //  - it's the first row of an implicit <tbody>/<tfoot> AND all of
          //    its cells are <th> (HTML convention: missing <thead> → header).
          final rowIsHeader = isThead ||
              (trIndexInSection == 0 && _rowIsHeaderByTh(cells, true));
          rows.add(ParsedTableRow(cells, isHeader: rowIsHeader));
          trIndexInSection++;
        }
      }
    }

    return ParsedTable(rows);
  }

  List<ParsedCell> _parseCells(
    html_dom.Element tr, {
    required bool isSectionHeader,
  }) {
    final cells = <ParsedCell>[];
    for (final cellEl in tr.children) {
      final tag = cellEl.localName?.toLowerCase() ?? '';
      if (tag != 'td' && tag != 'th') continue;
      final isHeader = isSectionHeader || tag == 'th';
      final spans = spanBuilder(
          cellEl,
          isHeader
              ? baseStyle.copyWith(fontWeight: FontWeight.bold)
              : baseStyle);
      cells.add(ParsedCell(
        textSpans: spans,
        cleanText: cellEl.text.replaceAll('\u00AD', ''),
        isHeader: isHeader,
        columnSpan: _parseInt(cellEl.attributes['colspan'], 1),
        rowSpan: _parseInt(cellEl.attributes['rowspan'], 1),
      ));
    }
    return cells;
  }

  /// A direct row (no section) is considered a header row only if all its
  /// cells are `<th>` — and its index matches `[firstRowIsHeader]` (true for
  /// row 0). We follow the HTML convention `<th>` everywhere = header cell;
  /// first row inside an implicit body counts as header row here only when
  /// at least one cell is a `<th>`.
  bool _rowIsHeaderByTh(List<ParsedCell> cells, bool firstRowIsHeader) {
    if (cells.isEmpty) return false;
    final allTh = cells.every((c) => c.isHeader);
    return allTh && firstRowIsHeader;
  }

  int _parseInt(String? raw, int fallback) {
    if (raw == null) return fallback;
    final v = int.tryParse(raw.trim());
    return v == null || v < 1 ? fallback : v;
  }
}
