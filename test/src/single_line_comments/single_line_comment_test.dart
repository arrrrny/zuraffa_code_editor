import 'package:zuraffa_code_editor/src/single_line_comments/single_line_comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SingleLineComment.cut', () {
    test('extracts the inner content after the sequence', () {
      final comment = SingleLineComment.cut(
        '// hello',
        characterIndex: 3,
        lineIndex: 1,
        sequences: const ['//', '/*'],
      );

      expect(comment.innerContent, ' hello');
      expect(comment.outerContent, '// hello');
      expect(comment.characterIndex, 3);
      expect(comment.lineIndex, 1);
    });

    test('the second sequence matches when the first does not', () {
      final comment = SingleLineComment.cut(
        '/* block */',
        characterIndex: 0,
        lineIndex: 0,
        sequences: const ['//', '/*'],
      );

      expect(comment.innerContent, ' block */');
    });

    test('carries the parser source through', () {
      final source = Object();

      final comment = SingleLineComment.cut(
        '// read only',
        characterIndex: 0,
        lineIndex: 0,
        sequences: const ['//'],
        source: source,
      );

      expect(comment.source, same(source));
    });
  });

  group('SingleLineComment isReadonly', () {
    test('is true when the first word is the readonly token', () {
      final comment = SingleLineComment.cut(
        '// readonly',
        characterIndex: 0,
        lineIndex: 0,
        sequences: const ['//'],
      );

      expect(comment.isReadonly, true);
    });

    test('is false without the token', () {
      final comment = SingleLineComment.cut(
        '// editable',
        characterIndex: 0,
        lineIndex: 0,
        sequences: const ['//'],
      );

      expect(comment.isReadonly, false);
    });
  });

  group('SingleLineComment equality and rendering', () {
    test('equality compares all four fields', () {
      SingleLineComment make({String inner = ' a', String outer = '// a'}) {
        return SingleLineComment(
          innerContent: inner,
          lineIndex: 1,
          characterIndex: 2,
          outerContent: outer,
        );
      }

      final left = make();

      expect(left, make());
      expect(left.hashCode, make().hashCode);
      expect(left, isNot(make(inner: ' b')));
      expect(left, isNot(make(outer: '// b')));
      expect(
        left,
        isNot(
          SingleLineComment(
            innerContent: ' a',
            lineIndex: 2,
            characterIndex: 2,
            outerContent: '// a',
          ),
        ),
      );
      expect(
        left,
        isNot(
          SingleLineComment(
            innerContent: ' a',
            lineIndex: 1,
            characterIndex: 3,
            outerContent: '// a',
          ),
        ),
      );
      expect(left, isNot('not a comment'));
    });

    test('toString names the line and the outer content', () {
      final comment = SingleLineComment(
        innerContent: ' x',
        lineIndex: 4,
        outerContent: '// x',
      );

      expect(comment.toString(), 'Line 4: "// x"');
    });
  });

  test('cut throws when no sequence matches', () {
    expect(
      () => SingleLineComment.cut(
        '# not a comment',
        characterIndex: 0,
        lineIndex: 0,
        sequences: const ['//', '/*'],
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('# not a comment does not start with any of [//, /*]'),
        ),
      ),
    );
  });

  group('SingleLineCommentIterable.sources', () {
    test('collects the distinct sources', () {
      final a = Object();
      final b = Object();

      final sources = [
        SingleLineComment(innerContent: ' a', lineIndex: 0, source: a),
        SingleLineComment(innerContent: ' b', lineIndex: 1, source: b),
        SingleLineComment(innerContent: ' c', lineIndex: 2, source: a),
      ].sources;

      expect(sources, {a, b});
    });

    test('an empty iterable has no sources', () {
      expect(const <SingleLineComment>[].sources, isEmpty);
    });
  });
}
