import 'package:cosmos_epub/Component/highlight_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('highlightColors palette', () {
    test('contains exactly 3 colors', () {
      expect(highlightColors.length, 3);
    });

    test('contains yellow, green, red', () {
      expect(highlightColors[0], const Color(0xFFFFEB3B));
      expect(highlightColors[1], const Color(0xFF81C784));
      expect(highlightColors[2], const Color(0xFFE57373));
    });

    test('does not contain blue, orange, or purple', () {
      for (final c in highlightColors) {
        expect(c, isNot(const Color(0xFF64B5F6)));
        expect(c, isNot(const Color(0xFFFFAB91)));
        expect(c, isNot(const Color(0xFFCE93D8)));
      }
    });
  });

  group('noteAnchorColor', () {
    test('is the defined blue constant', () {
      expect(noteAnchorColor, const Color(0xFF64B5F6));
    });
  });

  group('HighlightToolbar widget', () {
    testWidgets('renders exactly 3 color dots (circles)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HighlightToolbar(
              onDismiss: () {},
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      final circles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      expect(circles, findsNWidgets(3));
    });
  });
}
