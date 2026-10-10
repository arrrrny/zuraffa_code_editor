import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/java.dart';

import '../common/create_app.dart';

/// A Java-like document of [lines] lines, shaped like the file the issue
/// reports typing into: short lines, comments, and one block every five lines.
String _document(int lines) {
  final buffer = StringBuffer();

  for (int i = 0; i < lines; i++) {
    switch (i % 5) {
      case 0:
        buffer.writeln('// comment line $i');
      case 1:
        buffer.writeln('void method$i() {');
      case 2:
        buffer.writeln('  final value$i = $i; // inline');
      case 3:
        buffer.writeln('  return;');
      default:
        buffer.writeln('}');
    }
  }

  return buffer.toString();
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

/// The median time one keystroke takes in a document of [lines] lines.
///
/// A keystroke here is a single character inserted in the middle of the
/// document: the shape of typing, where the visible text grows by one character
/// and everything after it shifts. The controller is measured on its own
/// because that is where the work that grows with the document lives — parsing
/// the changed text, rebuilding the lines, folds and hidden ranges.
Future<int> _medianKeystrokeMicros(int lines, int reps) async {
  final controller = createController(_document(lines), language: java);
  final samples = <int>[];
  final stopwatch = Stopwatch();

  for (int i = 0; i < reps; i++) {
    final position = controller.value.text.length ~/ 2;
    final edited = controller.value.text.replaceRange(position, position, 'x');

    stopwatch
      ..reset()
      ..start();
    controller.value = TextEditingValue(
      text: edited,
      selection: TextSelection.collapsed(offset: position + 1),
    );
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }

  // The analysis debounce leaves a timer behind, and the test framework refuses
  // to end a test with one pending.
  controller.dispose();

  return _median(samples);
}

void main() {
  // Sizes from the report: it says typing turns sluggish "past a few hundred
  // rows" and users hit a few thousand. These bracket that range.
  //
  // Measured largest first. Building and dropping the large documents leaves
  // the debug heap churned enough that a size measured after a bigger one reads
  // up to 2.5x slower than the same size measured first, which is an artifact
  // of the harness and not of the editor.
  const sizes = [3000, 1000, 200];
  const reps = 5;

  testWidgets('A keystroke gets no more expensive per line as the document '
      'grows', (_) async {
    // Without this the first measured size pays for JIT compilation and reads
    // several times slower than the rest, which would make the comparison below
    // depend on the order of `sizes` rather than on the editor.
    await _medianKeystrokeMicros(1000, reps);

    final micros = <int, int>{};
    for (final lines in sizes) {
      micros[lines] = await _medianKeystrokeMicros(lines, reps);
    }

    for (final lines in sizes) {
      // ignore: avoid_print
      print(
        'keystroke benchmark: $lines lines '
        '-> ${micros[lines]}us '
        '(${(micros[lines]! / lines).toStringAsFixed(1)}us per line)',
      );
    }

    final perLineSmall = micros[sizes.last]! / sizes.last;
    final perLineLarge = micros[sizes.first]! / sizes.first;

    // Deliberately loose. `flutter test` runs on the unoptimized JIT, so these
    // numbers are about an order of magnitude above a release build and carry
    // the noise of a shared CI machine; the point of the bound is to fail on a
    // *super-linear* regression rather than to pin milliseconds. Fifteen times
    // the lines costing more than three times as much per line means a term
    // growing faster than the document — with this spread that is what a
    // quadratic step looks like (15x), while the linear behaviour this measures
    // sits near 1x.
    expect(perLineLarge, lessThan(perLineSmall * 3));
  });
}
