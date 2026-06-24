import 'package:cosmos_epub/Helpers/html_text_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpBuilder(
  WidgetTester tester,
  String html, {
  double maxWidth = 600,
}) async {
  final builder = HtmlTextBuilder(
    fontSize: 17,
    textColor: const Color(0xFF000000),
    maxWidth: maxWidth,
  );
  final widgets = builder.build(html);

  tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;

  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          child: SelectionArea(
            child: ListView(
              children: [
                ...widgets,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Table renders with non-null border, header ColoredBox background, '
    'and SelectableText.rich cells inside SelectionArea',
    (tester) async {
      await _pumpBuilder(
        tester,
        '<table>'
        '<thead><tr><th>H1</th><th>H2</th></tr></thead>'
        '<tbody><tr><td>1</td><td>2</td></tr></tbody>'
        '</table>',
        maxWidth: 600,
      );
      await tester.pump();

      final tableFinder = find.byType(Table);
      expect(tableFinder, findsOneWidget);
      final table = tester.widget<Table>(tableFinder);
      expect(table.border, isNotNull,
          reason: 'Table should be bordered (TableBorder.all)');

      // Each header cell is wrapped in a ColoredBox with header background.
      final coloredBoxes = find.descendant(
        of: tableFinder,
        matching: find.byType(ColoredBox),
      );
      expect(coloredBoxes, findsNWidgets(2),
          reason: 'one ColoredBox per header cell');

      // Cells render as Text.rich so they participate in SelectionArea.
      final textRichCells = find.descendant(
        of: tableFinder,
        matching: find.byType(Text),
      );
      // 2 header + 2 body cells = 4 Text.rich (Text widget renders Text.rich)
      expect(textRichCells, findsNWidgets(4));
    },
  );

  testWidgets(
    'Wide table (content wider than maxWidth) is wrapped in a horizontal '
    'SingleChildScrollView; narrow table is not',
    (tester) async {
      // ── Narrow table (fits within maxWidth=600) ──
      await _pumpBuilder(
        tester,
        '<table>'
        '<thead><tr><th>H1</th><th>H2</th></tr></thead>'
        '<tbody><tr><td>1</td><td>2</td></tr></tbody>'
        '</table>',
        maxWidth: 600,
      );
      await tester.pump();

      final tableFinder = find.byType(Table);
      expect(tableFinder, findsOneWidget);
      expect(
        find.ancestor(
          of: tableFinder,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
        reason: 'narrow table must NOT be horizontally scrollable',
      );

      // ── Wide table ── build with a very narrow maxWidth ──
      await _pumpBuilder(
        tester,
        '<table>'
        '<thead><tr>'
        '<th>HeaderA</th><th>HeaderB</th><th>HeaderC</th>'
        '<th>HeaderD</th>'
        '</tr></thead>'
        '<tbody><tr>'
        '<td>alpha-one</td><td>alpha-two</td><td>alpha-three</td>'
        '<td>alpha-four</td>'
        '</tr></tbody>'
        '<tbody><tr>'
        '<td>beta-one-with-long-text</td>'
        '<td>beta-two-with-long-text</td>'
        '<td>beta-three-with-long-text</td>'
        '<td>beta-four-with-long-text</td>'
        '</tr></tbody>'
        '</table>',
        // Deliberately tiny to force the scroll-wrap branch.
        maxWidth: 80,
      );
      await tester.pump();

      final wideTableFinder = find.byType(Table);
      expect(wideTableFinder, findsOneWidget);
      expect(
        find.ancestor(
          of: wideTableFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsOneWidget,
        reason: 'wide table must be wrapped in a horizontal '
            'SingleChildScrollView',
      );
    },
  );
}
