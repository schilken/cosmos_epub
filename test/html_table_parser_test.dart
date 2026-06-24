import 'package:cosmos_epub/Helpers/html_table_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

void main() {
  html_dom.Element parseFragment(String html) {
    final frag = html_parser.parseFragment(html);
    return frag.querySelector('table')!;
  }

  HtmlTableParser newParser() => HtmlTableParser(
        baseStyle: const TextStyle(fontSize: 17),
        spanBuilder: (cell, style) => [TextSpan(text: cell.text, style: style)],
      );

  test(
      'HtmlTableParser parses simple thead/tbody table → 1 header + 1 body row, '
      'header cell flagged, body cell text preserved', () {
    final table = parseFragment(
      '<table>'
      '<thead><tr><th>A</th></tr></thead>'
      '<tbody><tr><td>1</td><td>2</td></tr></tbody>'
      '</table>',
    );
    final parsed = newParser().parse(table);

    expect(parsed.rows.length, 2, reason: 'thead row + tbody row');

    final headerRow = parsed.rows[0];
    expect(headerRow.isHeader, isTrue);
    expect(headerRow.cells.length, 1);
    expect(headerRow.cells[0].isHeader, isTrue);
    expect(headerRow.cells[0].cleanText, 'A');

    final bodyRow = parsed.rows[1];
    expect(bodyRow.isHeader, isFalse);
    expect(bodyRow.cells.length, 2);
    expect(bodyRow.cells[0].isHeader, isFalse);
    expect(bodyRow.cells[0].cleanText, '1');
    expect(bodyRow.cells[1].cleanText, '2');
  });

  test(
      'HtmlTableParser: missing <thead> → first <tr> becomes header; '
      '<th> anywhere (even in body) is treated as header cell', () {
    // No <thead>. First <tr> is all <th> → header row (HTML convention).
    final table = parseFragment(
      '<table>'
      '<tr><th>Header</th></tr>'
      '<tr><td>1</td><th>2</th></tr>'
      '</table>',
    );
    final parsed = newParser().parse(table);

    expect(parsed.rows.length, 2);

    final row0 = parsed.rows[0];
    expect(row0.isHeader, isTrue, reason: 'first all-<th> direct row → header');
    expect(row0.cells[0].cleanText, 'Header');
    expect(row0.cells[0].isHeader, isTrue);

    final row1 = parsed.rows[1];
    expect(row1.isHeader, isFalse,
        reason: 'second row mixes td/th → not a header row');
    expect(row1.cells[0].isHeader, isFalse, reason: '<td> is not a header');
    expect(row1.cells[0].cleanText, '1');
    expect(row1.cells[1].isHeader, isTrue, reason: '<th> anywhere is header');
    expect(row1.cells[1].cleanText, '2');
  });

  test(
      'HtmlTableParser: honors colspan="2" / rowspan="2" → '
      'Produces columnSpan/rowSpan metadata', () {
    final table = parseFragment(
      '<table>'
      '<tr><th>H1</th><th>H2</th></tr>'
      '<tr><td colspan="2">wide</td><td>last</td></tr>'
      '<tr><td rowspan="2">tall</td><td>b</td><td>c</td></tr>'
      '<tr><td>d</td><td>e</td></tr>'
      '</table>',
    );
    final parsed = newParser().parse(table);

    // Header row (all-<th> first row in implicit tbody) — no spans.
    expect(parsed.rows[0].cells[0].columnSpan, 1);
    expect(parsed.rows[0].cells[0].rowSpan, 1);

    // colspan=2
    expect(parsed.rows[1].cells[0].cleanText, 'wide');
    expect(parsed.rows[1].cells[0].columnSpan, 2);
    expect(parsed.rows[1].cells[0].rowSpan, 1);

    // rowspan=2
    expect(parsed.rows[2].cells[0].cleanText, 'tall');
    expect(parsed.rows[2].cells[0].columnSpan, 1);
    expect(parsed.rows[2].cells[0].rowSpan, 2);

    // Invalid span values fall back to 1.
    expect(parsed.rows[1].cells[1].columnSpan, 1);
    expect(parsed.rows[1].cells[1].rowSpan, 1);
  });
}
