import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa_code_editor/src/analyzer/models/issue.dart';
import 'package:zuraffa_code_editor/src/analyzer/models/issue_type.dart';

void main() {
  group('issueLineComparator', () {
    test('sorts ascending by line', () {
      final issues = [
        Issue(line: 10, message: 'b', type: IssueType.error),
        Issue(line: 2, message: 'a', type: IssueType.warning),
      ]..sort(issueLineComparator);

      expect(issues.map((i) => i.line).toList(), [2, 10]);
    });

    test('returns 0 for equal lines', () {
      final first = Issue(line: 3, message: 'a', type: IssueType.error);
      final second = Issue(line: 3, message: 'b', type: IssueType.warning);

      expect(issueLineComparator(first, second), 0);
    });
  });

  group('Issue', () {
    test('suggestion and url default to null', () {
      const issue = Issue(line: 1, message: 'm', type: IssueType.error);

      expect(issue.suggestion, isNull);
      expect(issue.url, isNull);
    });

    test('optional fields round-trip', () {
      const issue = Issue(
        line: 1,
        message: 'm',
        type: IssueType.info,
        suggestion: 'do this',
        url: 'https://example.com',
      );

      expect(issue.suggestion, 'do this');
      expect(issue.url, 'https://example.com');
    });
  });
}
