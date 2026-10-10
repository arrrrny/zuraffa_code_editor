import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbstractAnalyzer', () {
    test('dispose() is a no-op unless the subclass overrides it', () {
      final analyzer = _NoOpAnalyzer();

      // The base implementation is what an analyzer that holds no resources
      // inherits; it must not throw.
      expect(analyzer.dispose, returnsNormally);
    });
  });
}

class _NoOpAnalyzer extends AbstractAnalyzer {
  @override
  Future<AnalysisResult> analyze(Code code) async =>
      const AnalysisResult(issues: []);
}
