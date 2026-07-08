import 'package:cosmos_epub/Helpers/html_text_builder.dart';
import 'package:cosmos_epub/Helpers/soft_hyphen_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HtmlTextBuilder newBuilder({String? searchQuery}) {
  return HtmlTextBuilder(
    fontSize: 17,
    textColor: const Color(0xFF000000),
    searchQuery: searchQuery,
  );
}

TextSpan? _findSpanWithText(List<InlineSpan> spans, String text) {
  for (final span in spans) {
    if (span is TextSpan) {
      if (span.text == text) return span;
      if (span.children != null) {
        final found = _findSpanWithText(span.children!, text);
        if (found != null) return found;
      }
    }
  }
  return null;
}

SoftHyphenParagraph? _findParagraph(Widget widget) {
  if (widget is SoftHyphenParagraph) return widget;
  Widget? child;
  if (widget is Listener) child = widget.child;
  if (widget is Padding) child = widget.child;
  if (widget is ColoredBox) child = widget.child;
  if (child != null) return _findParagraph(child);
  return null;
}

List<InlineSpan> _collectSpans(Widget widget) {
  final para = _findParagraph(widget);
  if (para != null) {
    final textSpan = para.textSpan;
    return textSpan.children ?? [textSpan];
  }
  return [];
}

void main() {
  group('HtmlTextBuilder searchQuery', () {
    test('no query → single TextSpan per text node', () {
      final b = newBuilder();
      final widgets = b.build('<p>Hello World</p>');
      expect(widgets, isNotEmpty);
      expect(b.lastBuiltCleanText, 'Hello World');
    });

    test('null query → unchanged spans', () {
      final b = newBuilder(searchQuery: null);
      final widgets = b.build('<p>Hello World</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);
      expect(spans.length, 1);
      final span = spans.first as TextSpan;
      expect(span.text, 'Hello World');
      expect(span.style?.fontWeight, isNull);
    });

    test('empty query → unchanged spans', () {
      final b = newBuilder(searchQuery: '');
      final widgets = b.build('<p>Hello World</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);
      expect(spans.length, 1);
      final span = spans.first as TextSpan;
      expect(span.text, 'Hello World');
      expect(span.style?.fontWeight, isNull);
    });

    test('single match bolds the matched text', () {
      final b = newBuilder(searchQuery: 'Hello');
      final widgets = b.build('<p>Hello World</p>');
      expect(widgets, isNotEmpty);
      final firstWidget = widgets.first;
      // Navigate to SoftHyphenParagraph
      final listener = firstWidget as Listener;
      final padding = listener.child! as Padding;
      final para = padding.child! as SoftHyphenParagraph;
      final textSpan = para.textSpan;
      final spans = textSpan.children ?? [textSpan];

      expect(spans.length, 2);

      final hello = spans[0] as TextSpan;
      expect(hello.text, 'Hello');
      expect(hello.style?.fontWeight, FontWeight.bold);

      final rest = spans[1] as TextSpan;
      expect(rest.text, ' World');
      expect(rest.style?.fontWeight, isNull);
    });

    test('case-insensitive matching', () {
      final b = newBuilder(searchQuery: 'hello');
      final widgets = b.build('<p>Hello World</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);
      expect(spans.length, 2);

      final hello = spans[0] as TextSpan;
      expect(hello.text, 'Hello');
      expect(hello.style?.fontWeight, FontWeight.bold);
    });

    test('multiple matches in one text node', () {
      final b = newBuilder(searchQuery: 'fox');
      final widgets = b.build(
        '<p>The fox and another fox are both here.</p>',
      );
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);

      final boldSpans = spans.whereType<TextSpan>().where((s) {
        final t = s.text ?? '';
        return t.toLowerCase() == 'fox' &&
            s.style?.fontWeight == FontWeight.bold;
      });
      expect(boldSpans.length, 2);
    });

    test('no match returns single span unchanged', () {
      final b = newBuilder(searchQuery: 'elephant');
      final widgets = b.build('<p>Hello World</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);
      expect(spans.length, 1);
      final span = spans.first as TextSpan;
      expect(span.text, 'Hello World');
      expect(span.style?.fontWeight, isNull);
    });

    test('handles special regex characters as literal text', () {
      final b = newBuilder(searchQuery: '[hello]');
      final widgets = b.build('<p>Text with [hello] inside</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);

      final bold = spans[1] as TextSpan;
      expect(bold.text, '[hello]');
      expect(bold.style?.fontWeight, FontWeight.bold);
    });

    test('handles parentheses as literal text', () {
      final b = newBuilder(searchQuery: '(test)');
      final widgets = b.build('<p>This is a (test) of parens</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);

      final bold = spans[1] as TextSpan;
      expect(bold.text, '(test)');
      expect(bold.style?.fontWeight, FontWeight.bold);
    });

    test('handles asterisk as literal text', () {
      final b = newBuilder(searchQuery: '*star*');
      final widgets = b.build('<p>Look at *star* here</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);

      final bold = spans[1] as TextSpan;
      expect(bold.text, '*star*');
      expect(bold.style?.fontWeight, FontWeight.bold);
    });

    test('match across inline elements with b tag untouched', () {
      final b = newBuilder(searchQuery: 'bold');
      final widgets = b.build('<p>Some <b>bold</b> text here</p>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);

      final boldSpan = _findSpanWithText(spans, 'bold');
      expect(boldSpan, isNotNull);
      expect(boldSpan!.style?.fontWeight, FontWeight.bold);
    });

    test('match in direct text node (not wrapped in element)', () {
      // Direct text inside body (not in <p>) — exercises the _collectWidgets
      // direct Text node path
      final b = newBuilder(searchQuery: 'needle');
      final widgets = b.build('<body>Find the needle here</body>');
      expect(widgets, isNotEmpty);
      final spans = _collectSpans(widgets.first);

      final boldSpan = _findSpanWithText(spans, 'needle');
      expect(boldSpan, isNotNull);
      expect(boldSpan!.style?.fontWeight, FontWeight.bold);
    });
  });
}
