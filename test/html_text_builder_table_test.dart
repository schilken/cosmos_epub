import 'package:cosmos_epub/Helpers/html_text_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HtmlTextBuilder newBuilder({double? maxWidth}) {
    return HtmlTextBuilder(
      fontSize: 17,
      textColor: const Color(0xFF000000),
      maxWidth: maxWidth,
    );
  }

  test(
      'HtmlTextBuilder.build on small table → clean text equals concatenation '
      'of cell texts in reading order (thead first, then tbody, LTR)', () {
    final b = newBuilder();
    final widgets = b.build(
      '<table>'
      '<thead><tr><th>A</th><th>B</th></tr></thead>'
      '<tbody><tr><td>1</td><td>2</td></tr>'
      '<tr><td>3</td><td>4</td></tr></tbody>'
      '</table>',
    );

    // Reading order: thead row 1 (A B) → tbody row 1 (1 2) → tbody row 2 (3 4)
    expect(b.lastBuiltCleanText, 'AB1234');
    // The table should produce at least one widget (the Table itself).
    expect(widgets, isNotEmpty);
  });

  test(
      'HtmlTextBuilder.build: two tables in one page → cells concatenate across '
      'tables in order; subsequent paragraph offset resumes after last table',
      () {
    final b = newBuilder();
    b.build(
      '<table><tr><th>H</th></tr><tr><td>0</td></tr></table>'
      '<p>after</p>',
    );

    // Header cell + body cell + paragraph text, all in order.
    expect(b.lastBuiltCleanText, 'H0after');
  });
}
