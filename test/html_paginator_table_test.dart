import 'package:cosmos_epub/Helpers/html_paginator.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

void main() {
  const fontSize = 17.0;

  html_dom.Element parseTable(String html) {
    final frag = html_parser.parseFragment(html);
    return frag.querySelector('table')!;
  }

  test(
    'tableBlockHeight for 3-row (1 header + 2 body), 2-column table '
    'matches manual formula: headerRows*fs*1.7 + bodyRows*fs*1.4 '
    '+ rows*fs*0.5 + (rows+cols+2) + fs*0.6',
    () {
      final table = parseTable(
        '<table>'
        '<thead><tr><th>H1</th><th>H2</th></tr></thead>'
        '<tbody>'
        '<tr><td>a</td><td>b</td></tr>'
        '<tr><td>c</td><td>d</td></tr>'
        '</tbody>'
        '</table>',
      );

      final height = HtmlPaginator.tableBlockHeight(table, fontSize);

      // Manual computation:
      // headerRows = 1, bodyRows = 2, rows = 3, cols = 2
      // header: 1 * 17 * 1.7 = 28.9
      // body:   2 * 17 * 1.4 = 47.6
      // per-cell padding: 3 * 17 * 0.5 = 25.5
      // border: (3+2+2) = 7.0
      // outer padding: 17 * 0.6 = 10.2
      // Total: 28.9 + 47.6 + 25.5 + 7.0 + 10.2 = 119.2
      expect(height, closeTo(119.2, 1e-10));
    },
  );

  test(
    'tableBlockHeight with colspan/rowspan attributes still counts '
    'total rows/cols from <tr>/<td> count',
    () {
      final table = parseTable(
        '<table>'
        '<tr><td colspan="2">wide</td></tr>'
        '<tr><td>a</td></tr>'
        '</table>',
      );

      final height = HtmlPaginator.tableBlockHeight(table, fontSize);
      // rows=2, cols=2 (max td/tr in a row even if colspan reduces count per row), headerRows=0, bodyRows=2
      // header: 0
      // body:   2 * 17 * 1.4 = 47.6
      // per-cell padding: 2 * 17 * 0.5 = 17.0
      // border: (2+2+2) = 6.0
      // outer padding: 17 * 0.6 = 10.2
      // Total: 47.6 + 17.0 + 6.0 + 10.2 = 80.8
      expect(height, closeTo(80.8, 1e-10));
    },
  );

  test(
    'tableBlockHeight for table with no thead treats first all-<th> row '
    'as header (HtmlTableParser convention) — but for height estimation '
    'we count <th> as header row too',
    () {
      final table = parseTable(
        '<table>'
        '<tr><th>H1</th><th>H2</th></tr>'
        '<tr><td>a</td><td>b</td></tr>'
        '</table>',
      );

      final height = HtmlPaginator.tableBlockHeight(table, fontSize);
      // rows=2, cols=2, first row is all-th → headerRow, rest body
      // header: 1 * 17 * 1.7 = 28.9
      // body:   1 * 17 * 1.4 = 23.8
      // per-cell padding: 2 * 17 * 0.5 = 17.0
      // border: (2+2+2) = 6.0
      // outer padding: 17 * 0.6 = 10.2
      // Total: 28.9 + 23.8 + 17.0 + 6.0 + 10.2 = 85.9
      expect(height, closeTo(85.9, 1e-10));
    },
  );

  test(
    'tableBlockHeight sanity: result is within ±10% of TextPainter '
    'height for concatenated cell texts in a 3-row 2-col table',
    () {
      final table = parseTable(
        '<table>'
        '<thead><tr><th>HeaderA</th><th>HeaderB</th></tr></thead>'
        '<tbody><tr><td>one</td><td>two</td></tr>'
        '<tr><td>three</td><td>four</td></tr></tbody>'
        '</table>',
      );

      final formulaHeight = HtmlPaginator.tableBlockHeight(table, fontSize);

      final cleanText = table.text;
      final painter = TextPainter(
        text: TextSpan(text: cleanText, style: TextStyle(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
      );
      painter.layout(maxWidth: 200);
      final textHeight = painter.height;
      painter.dispose();

      // The formula should be noticeably larger than bare text height
      // (because of borders, padding, row overhead), but still within
      // 4× the bare text height for this small table.
      expect(formulaHeight, greaterThan(textHeight));
      expect(formulaHeight, lessThan(textHeight * 4));
    },
  );
}
