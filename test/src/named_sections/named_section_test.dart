import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NamedSection', () {
    const section = NamedSection(firstLine: 3, lastLine: 7, name: 'body');

    test('renders its range and its name', () {
      expect(section.toString(), '3-7: "body"');
    });

    test(
      'a section that runs to the end of the document renders a null end',
      () {
        const open = NamedSection(firstLine: 2, lastLine: null, name: 'open');

        expect(open.toString(), '2-null: "open"');
      },
    );
  });
}
