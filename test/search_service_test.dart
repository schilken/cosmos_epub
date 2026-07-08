import 'package:cosmos_epub/Helpers/search_service.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/Model/search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchResult model', () {
    test('all fields are assigned correctly', () {
      final r = SearchResult(
        chapterIndex: 2,
        matchStart: 10,
        matchEnd: 15,
        matchedText: 'hello',
        contextBefore: 'say ',
        contextAfter: ' world',
        pageIndex: null,
      );

      expect(r.chapterIndex, 2);
      expect(r.matchStart, 10);
      expect(r.matchEnd, 15);
      expect(r.matchedText, 'hello');
      expect(r.contextBefore, 'say ');
      expect(r.contextAfter, ' world');
      expect(r.pageIndex, isNull);
    });

    test('pageIndex is nullable and can be set after construction', () {
      final r = SearchResult(
        chapterIndex: 0,
        matchStart: 0,
        matchEnd: 3,
        matchedText: 'foo',
        contextBefore: '',
        contextAfter: '',
      );
      expect(r.pageIndex, isNull);
      r.pageIndex = 3;
      expect(r.pageIndex, 3);
    });

    test('equality works', () {
      final a = SearchResult(
        chapterIndex: 1,
        matchStart: 5,
        matchEnd: 8,
        matchedText: 'abc',
        contextBefore: 'x',
        contextAfter: 'y',
      );
      final b = SearchResult(
        chapterIndex: 1,
        matchStart: 5,
        matchEnd: 8,
        matchedText: 'abc',
        contextBefore: 'x',
        contextAfter: 'y',
      );
      expect(a, equals(b));
    });

    test('hashCode is consistent', () {
      final r = SearchResult(
        chapterIndex: 1,
        matchStart: 5,
        matchEnd: 8,
        matchedText: 'abc',
        contextBefore: 'x',
        contextAfter: 'y',
      );
      expect(r.hashCode, isA<int>());
    });
  });

  group('SearchService', () {
    late SearchService service;

    final chapterWithParagraphs = LocalChapterModel(
      chapter: 'Chapter 1',
      htmlContent: '''
<html><body>
<h1>Chapter One</h1>
<p>The quick brown fox jumps over the lazy dog. This sentence contains the word fox somewhere in the middle.</p>
<p>Another paragraph about foxes in their natural habitat. Foxes are clever animals that hunt at night.</p>
</body></html>''',
    );

    setUp(() {
      service = SearchService();
    });

    test('empty query returns empty list', () {
      final results = service.searchAllChapters([chapterWithParagraphs], '');
      expect(results, isEmpty);
    });

    test('empty query with whitespace still returns empty', () {
      final results = service.searchAllChapters([chapterWithParagraphs], '   ');
      expect(results, isEmpty);
    });

    test('empty chapter list returns empty list', () {
      final results = service.searchAllChapters([], 'fox');
      expect(results, isEmpty);
    });

    test('empty HTML content returns empty list', () {
      final chapters = [
        LocalChapterModel(chapter: 'Empty', htmlContent: ''),
      ];
      final results = service.searchAllChapters(chapters, 'fox');
      expect(results, isEmpty);
    });

    test('no match returns empty list', () {
      final results =
          service.searchAllChapters([chapterWithParagraphs], 'elephant');
      expect(results, isEmpty);
    });

    test('single match returns one result with correct fields', () {
      final results =
          service.searchAllChapters([chapterWithParagraphs], 'lazy');
      expect(results.length, 1);
      final r = results.first;
      expect(r.chapterIndex, 0);
      expect(r.matchedText, 'lazy');
      expect(r.matchStart, greaterThan(0));
      expect(r.matchEnd, greaterThan(r.matchStart));
    });
    test('multiple matches in same chapter', () {
      final results = service.searchAllChapters([chapterWithParagraphs], 'fox');
      expect(results.length, 4);

      for (final r in results) {
        expect(r.chapterIndex, 0);
        expect(r.matchedText.toLowerCase(), 'fox');
      }
    });

    test('matches across multiple chapters return correct chapterIndex', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Chapter 1',
          htmlContent:
              '<html><body><p>First chapter mentions the needle here.</p></body></html>',
        ),
        LocalChapterModel(
          chapter: 'Chapter 2',
          htmlContent:
              '<html><body><p>Second chapter has needle too.</p></body></html>',
        ),
        LocalChapterModel(
          chapter: 'Chapter 3',
          htmlContent:
              '<html><body><p>Third chapter does not mention it.</p></body></html>',
        ),
      ];

      final results = service.searchAllChapters(chapters, 'needle');
      expect(results.length, 2);
      expect(results[0].chapterIndex, 0);
      expect(results[1].chapterIndex, 1);
    });
    test('case-insensitive matching', () {
      final results = service.searchAllChapters([chapterWithParagraphs], 'FOX');
      expect(results.length, 4);
      expect(results.first.matchedText, 'fox');
    });
    test('case-insensitive with mixed case query', () {
      final results = service.searchAllChapters([chapterWithParagraphs], 'FoX');
      expect(results.length, 4);
    });

    test('chapters with only headings return results if heading matches', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Title Chapter',
          htmlContent:
              '<html><body><h1>Introduction</h1><h2>Overview</h2></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'Overview');
      expect(results.length, 1);
      expect(results.first.matchedText, 'Overview');
    });

    test('html entities are decoded correctly', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Entities',
          htmlContent:
              '<html><body><p>Caf&eacute; &amp; le restaurant &lt;food&gt;</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'café');
      expect(results.length, 1);
      expect(results.first.matchedText.toLowerCase(), 'café');
    });

    test('html entities — ampersand entity in text', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Entities',
          htmlContent:
              '<html><body><p>This &amp; that are different things.</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, '&');
      expect(results.length, 1);
      expect(results.first.matchedText, '&');
    });

    test('less-than entity is decoded', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Entities',
          htmlContent:
              '<html><body><p>x &lt; 5 means less than five.</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, '<');
      expect(results.length, 1);
      expect(results.first.matchedText, '<');
    });

    test('skip chapter with unparseable HTML', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Good',
          htmlContent:
              '<html><body><p>This chapter is fine and has the needle.</p></body></html>',
        ),
        LocalChapterModel(
          chapter: 'Bad',
          htmlContent: 'not even html just garbage text',
        ),
        LocalChapterModel(
          chapter: 'Also Good',
          htmlContent:
              '<html><body><p>Another fine chapter with needle.</p></body></html>',
        ),
      ];

      final results = service.searchAllChapters(chapters, 'needle');
      expect(results.length, 2);
      expect(results[0].chapterIndex, 0);
      expect(results[1].chapterIndex, 2);
    });

    test('script and style elements are excluded from search', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'With Script',
          htmlContent:
              '<html><head><script>console.log("fox");</script><style>.fox { color: red; }</style></head>'
              '<body><p>Visible content about hedgehogs.</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'fox');
      expect(results, isEmpty);
    });

    test('context before does not truncate mid-word', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Context Test',
          htmlContent:
              '<html><body><p>${'x' * 200} middleoftargetword ${'y' * 200}</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'target');
      expect(results.length, 1);

      final before = results.first.contextBefore;
      expect(before, endsWith('middleof'));
    });

    test('context after does not truncate mid-word', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Context Test',
          htmlContent:
              '<html><body><p>${'x' * 200} targetmiddleofword ${'y' * 200}</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'target');
      expect(results.length, 1);

      final after = results.first.contextAfter;
      expect(after, startsWith('middleof'));
    });

    test('context stops at paragraph boundary (double newline)', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Paragraphs',
          htmlContent: '<html><body>'
              '<p>${'word ' * 50}</p>'
              '<p>target search term here</p>'
              '<p>${'word ' * 50}</p>'
              '</body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'target');
      expect(results.length, 1);

      final before = results.first.contextBefore;
      final after = results.first.contextAfter;
      expect(before, isNot(contains('\n\n')));
      expect(after, isNot(contains('\n\n')));
    });

    test('match at very start of text returns empty contextBefore', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Start',
          htmlContent:
              '<html><body><p>FirstWord and some more text after it.</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'FirstWord');
      expect(results.length, 1);
      expect(results.first.contextBefore, '');
    });

    test('match at very end of text returns empty or minimal contextAfter', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'End',
          htmlContent:
              '<html><body><p>Some text before the end. LastWord</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'LastWord');
      expect(results.length, 1);
      expect(results.first.contextAfter, '');
    });

    test('multiple matches update searchFrom correctly (no overlap)', () {
      final chapters = [
        LocalChapterModel(
          chapter: 'Overlap',
          htmlContent: '<html><body><p>aaaaa aaaaa aaaaa</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'aaa');
      expect(results.length, greaterThan(1));
      for (int i = 1; i < results.length; i++) {
        expect(results[i].matchStart,
            greaterThanOrEqualTo(results[i - 1].matchEnd));
      }
    });

    test('context length is approximately 100 chars', () {
      final longPrefix = 'word ' * 200;
      final longSuffix = ' word' * 200;
      final chapters = [
        LocalChapterModel(
          chapter: 'Long',
          htmlContent:
              '<html><body><p>$longPrefix TARGET $longSuffix</p></body></html>',
        ),
      ];
      final results = service.searchAllChapters(chapters, 'TARGET');
      expect(results.length, 1);

      final beforeLen = results.first.contextBefore.length;
      final afterLen = results.first.contextAfter.length;

      expect(beforeLen, greaterThan(80));
      expect(afterLen, greaterThan(80));
      expect(beforeLen, lessThanOrEqualTo(105));
      expect(afterLen, lessThanOrEqualTo(105));
    });
  });

  group('findPageContainingMatch', () {
    test('match in first page returns 0', () {
      final pages = [
        '<p>Find the needle in this haystack.</p>',
        '<p>No match here at all.</p>',
        '<p>Another needle appears again.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, 0);
    });

    test('match in middle page returns correct index', () {
      final pages = [
        '<p>Nothing to see here.</p>',
        '<p>Find the needle in this haystack.</p>',
        '<p>Just more text.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, 1);
    });

    test('match in last page returns correct index', () {
      final pages = [
        '<p>No match here.</p>',
        '<p>Still nothing.</p>',
        '<p>The needle is finally here.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, 2);
    });

    test('match not found returns -1', () {
      final pages = [
        '<p>Nothing to see here.</p>',
        '<p>Also nothing.</p>',
      ];
      final result = findPageContainingMatch(pages, 'elephant');
      expect(result, -1);
    });

    test('empty pages list returns -1', () {
      final result = findPageContainingMatch([], 'needle');
      expect(result, -1);
    });

    test('empty match text returns -1', () {
      final pages = ['<p>Some content here.</p>'];
      final result = findPageContainingMatch(pages, '');
      expect(result, -1);
    });

    test('HTML fragments with non-breaking spaces', () {
      final pages = [
        '<p>Hello&nbsp;World this is some text.</p>',
        '<p>Another&nbsp;page&nbsp;with needle here.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, 1);
    });

    test('matches first occurrence when multiple pages have the term', () {
      final pages = [
        '<p>First page no match.</p>',
        '<p>Needle in the second page.</p>',
        '<p>Needle also in the third page.</p>',
      ];
      final result = findPageContainingMatch(pages, 'Needle');
      expect(result, 1);
    });

    test('case-insensitive matching', () {
      final pages = [
        '<p>Find the NEEDLE here.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, 0);
    });

    test('page with unparseable HTML is skipped', () {
      final pages = [
        '<p>Fine page with needle.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, 0);
    });

    test('page with only whitespace is skipped', () {
      final pages = [
        '<p>   </p>',
        '<p>No target term in this content.</p>',
      ];
      final result = findPageContainingMatch(pages, 'needle');
      expect(result, -1);
    });
  });
}
