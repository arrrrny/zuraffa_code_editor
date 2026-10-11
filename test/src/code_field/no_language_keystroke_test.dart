import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight_core.dart' show Mode, highlight;
import 'package:highlight/languages/java.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';

/// What one keystroke costs with **no language selected**, and the pin that
/// keeps it that way.
///
/// Fork issue
/// [#111](https://github.com/arrrrny/zuraffa_code_editor/issues/111) (upstream
/// `akvelon/flutter-code-editor#246`) reports that `highlight.parse()` still
/// runs with no language set, so an unhighlighted 4800-line document hangs
/// "~20 s" per keystroke, and proposes skipping the parse when the language is
/// null.
///
/// **The premise does not hold on this fork**, and the numbers say so:
/// `CodeController._createCode`
/// (`lib/src/code_field/code_controller.dart:1013`) does call
/// `highlight.parse` unconditionally, but `_languageId` stays `''` until a
/// non-null language is set, and `highlight` 0.7.0 resolves an unknown name to
/// `plaintext` — `_getLanguage(language) ?? plaintext`
/// (`highlight-0.7.0/lib/src/highlight.dart:271`), where `plaintext = Mode(
/// refs: {}, disableAutodetect: true)`
/// (`highlight-0.7.0/lib/languages/plaintext.dart:6`). An empty mode has no
/// keywords to match, no sub-modes to push and no auto-detection to attempt,
/// so the parse is one walk that produces a single text node.
///
/// Measured on a 4800-line / 84 552-char document (the fixture shape of
/// `test/src/code_field/edit_latency_test.dart`, five consecutive runs),
/// `flutter test` (unoptimized JIT), median of 5 after a warm-up run:
///
/// | path | `highlight.parse` | one keystroke |
/// |---|---|---|
/// | no language (`_languageId == ''`) | 11–18 µs | 13.1–14.5 ms |
/// | `java` | 80.7–96.5 ms | 122.7–129.5 ms |
///
/// So the parse is ~0.1% of the no-language keystroke and skipping it could
/// save essentially nothing — there is no multi-second stall on *either* path
/// at this size, and the reported symptom is not reachable on this code. Note
/// also that the with-language keystroke is itself ~125 ms, some two orders of
/// magnitude below the "~20 s" the issue reports: whichever path the report's
/// author was on, the stall this fork exhibits is not the one described. The
/// remaining ~14 ms of the no-language keystroke is the same whole-document
/// work `test/src/code_field/edit_latency_test.dart` decomposes for the
/// with-language path — `Code(...)` construction, fold re-application,
/// hidden-range recomputation and text-span building — none of which the parse
/// drives.
///
/// Fault injection, so the bounds above are not vacuous: registering `java`
/// under the empty language id in the test process (`highlight.registerLanguage(
/// '', java)` — the shape of a change that made the no-language fallback
/// resolve to a real language) moves the no-language parse to 80 532 µs against
/// the with-language parse's 76 120 µs (ratio 1.06), the keystroke to 109 045 µs
/// and the parse's share of that keystroke to 73.9%. That reddens SC-002 (109
/// 045 µs against a 100 000 µs bound) and would redden SC-001 as well (80 532 µs
/// against a 3 806 µs budget), while SC-003 holds — the two paths are then
/// genuinely the same work — which is why SC-001 and SC-002, not the ordering
/// alone, carry the tripwire.
///
/// This file is the **pin**, not the fix. The assertions below are ratios
/// between two measurements taken on the same document in the same test body,
/// never absolute millisecond budgets: `flutter test` runs the unoptimized JIT
/// and CI hardware has been observed to differ by more than 2× from the
/// author's machine for identical code (see the comment in
/// `edit_latency_test.dart`). A ratio between paths measured microseconds
/// apart is stable to a few percent, which is what makes it a gate rather than
/// a coin flip. A change that makes the no-language parse do token-level work
/// — a fallback to auto-detection, or registering a real language under the
/// empty name — pushes the ratio toward the with-language path's and reddens
/// this file.

/// A Java-like document of [lines] lines, shaped like the file the issue
/// reports typing into: short lines, comments, and one block every five lines.
/// The same fixture shape as
/// `test/src/code_field/edit_latency_test.dart`, at the size the issue names.
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

/// The median time [text] takes to highlight with the language registered
/// under [languageId] on the `highlight` instance the controller uses.
///
/// The controller imports `highlight_core.dart`, whose `highlight` is a
/// separate instance from the one `highlight.dart` exports — and unlike that
/// one it ships with no registered languages, so `java` is only reachable here
/// through the id `CodeController.setLanguage` generated for it.
int _medianParseMicros(String text, String languageId, int reps) {
  final samples = <int>[];
  final stopwatch = Stopwatch();

  for (int i = 0; i < reps; i++) {
    stopwatch
      ..reset()
      ..start();
    highlight.parse(text, language: languageId);
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }

  return _median(samples);
}

/// The median time one keystroke takes on [controller].
///
/// A keystroke here is a single character inserted in the middle of the
/// document — the shape of typing, where the visible text grows by one
/// character and everything after it shifts. The controller is measured on its
/// own because that is where the work that grows with the document lives.
int _medianKeystrokeMicros(CodeController controller, int reps) {
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

/// The median time one paste of [document] into an empty controller takes —
/// the shape upstream issue #246 actually reports ("4800+ lines of output into
/// the editor"), as distinct from a keystroke: the whole document arrives in a
/// single `value` assignment, so every whole-document term is paid once and in
/// the same frame.
CodeController _pasteTarget(Mode? language) {
  return CodeController(
    text: '',
    language: language,
    namedSectionParser: const BracketsStartEndNamedSectionParser(),
  );
}

int _medianPasteMicros(String document, Mode? language, int reps) {
  final samples = <int>[];
  final stopwatch = Stopwatch();

  for (int i = 0; i < reps; i++) {
    final controller = _pasteTarget(language);

    stopwatch
      ..reset()
      ..start();
    controller.value = TextEditingValue(
      text: document,
      selection: TextSelection.collapsed(offset: document.length),
    );
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);

    controller.dispose();
  }

  return _median(samples);
}

/// A controller that never had a language set — the public
/// zero-configuration path the issue reports.
///
/// `CodeController`'s constructor calls `setLanguage(language, ...)`, which
/// leaves `_languageId` at its `''` initializer when `language` is null, so
/// this is exactly what a consumer gets by omitting the `language` argument.
CodeController _controllerWithoutLanguage(String text) {
  return CodeController(
    text: text,
    namedSectionParser: const BracketsStartEndNamedSectionParser(),
  );
}

void main() {
  // The size the issue names. Measured largest first, and after a warm-up run,
  // because building and dropping a large document leaves the debug heap
  // churned enough that a measurement taken after a bigger one reads up to 2.5x
  // slower than the same size measured first — an artifact of the harness, not
  // of the editor.
  const lines = 4800;
  const reps = 5;

  test('No language selected does not make a keystroke expensive', () {
    final document = _document(lines);

    // Warm up both paths so the comparison is not paying for JIT compilation.
    // `_medianKeystrokeMicros` disposes what it measures, the same way
    // `edit_latency_test.dart` does.
    _medianKeystrokeMicros(_controllerWithoutLanguage(document), 1);

    final noLanguage = _controllerWithoutLanguage(document);
    final withJava = CodeController(
      text: document,
      language: java,
      namedSectionParser: const BracketsStartEndNamedSectionParser(),
    );

    final noLanguageParse = _medianParseMicros(
      document,
      noLanguage.languageId,
      reps,
    );
    final javaParse = _medianParseMicros(document, withJava.languageId, reps);

    final noLanguageKeystroke = _medianKeystrokeMicros(noLanguage, reps);
    final javaKeystroke = _medianKeystrokeMicros(withJava, reps);

    // ignore: avoid_print
    print(
      'no-language keystroke pin: $lines lines\n'
      '  languageId  no language: "${noLanguage.languageId}"\n'
      '  highlight.parse  no language: ${noLanguageParse}us\n'
      '  highlight.parse  java:        ${javaParse}us\n'
      '  keystroke median  no language: ${noLanguageKeystroke}us\n'
      '  keystroke median  java:        ${javaKeystroke}us\n'
      '  parse share of no-language keystroke: '
      '${(noLanguageParse / noLanguageKeystroke * 100).toStringAsFixed(1)}%',
    );

    // SC-002 / FR-002: a keystroke with no language completes well inside a
    // tenth of a second. The measured value is 13.1–14.5 ms and the bound is
    // absolute, not a ratio, because the absolute stall is what the issue
    // reports: a ratio gate alone would stay green while both paths crawled.
    expect(noLanguageKeystroke, lessThan(100 * 1000));

    // SC-003: the no-language path is never slower than the with-language one.
    // It is roughly 9x faster here.
    expect(noLanguageKeystroke, lessThanOrEqualTo(javaKeystroke));

    // SC-001 / FR-004: the no-language parse costs a small fraction of the
    // with-language parse. Measured 10–18 µs against 78.9–96.5 ms, i.e.
    // 0.013–0.021%; the bound is 5% per the spec.
    expect(noLanguageParse, lessThan(javaParse * 0.05));

    // SC-004: the tripwire. The ratio between the two keystroke paths is
    // bounded well below 1, so a change that makes the no-language parse
    // expensive — a fallback to auto-detection, or a real language registered
    // under the empty name — pushes it toward 1 and reddens this file rather
    // than reaching users quietly. The measured ratio is 0.105–0.117, so the
    // 0.6 bound keeps ~5x of headroom for machine noise while staying far below
    // the 1.0 a regression would reach.
    expect(noLanguageKeystroke / javaKeystroke, lessThan(0.6));
  });

  test('An unresolvable language name costs the same as no language at all', () {
    // FR-003: a language name that does not resolve must be treated exactly
    // like no language. `highlight._getLanguage` returns null for a name that
    // is neither a registered language nor a registered alias, so an
    // unrecognised name lands on the same `plaintext` fallback the empty id
    // does.
    //
    // The bound is the 5% share of the with-language parse from SC-001 rather
    // than a window around the empty id's own median. Both are the same empty
    // mode, so their medians differ only by machine noise — and at ~10 µs each
    // that noise is large enough relative to the signal that a ratio between
    // the two is flaky under the concurrent load of a full `flutter test` run
    // (this file measures it and it fails that way). Anchoring both against the
    // ~79 ms with-language parse keeps the assertion exact about what it is
    // guarding: an unresolvable name must not start doing token-level work.
    final document = _document(lines);

    final reference = _controllerWithoutLanguage(document);
    final noLanguageParse = _medianParseMicros(
      document,
      reference.languageId,
      reps,
    );
    reference.dispose();

    final unresolvableParse = _medianParseMicros(
      document,
      'not-a-language-that-is-registered',
      reps,
    );

    // Its own controller, not the first test's: `highlight` is a process-wide
    // instance, but relying on another test to have registered `java` would
    // make this one order-dependent.
    final javaReference = CodeController(
      text: document,
      language: java,
      namedSectionParser: const BracketsStartEndNamedSectionParser(),
    );
    final javaParse = _medianParseMicros(
      document,
      javaReference.languageId,
      reps,
    );
    javaReference.dispose();

    // ignore: avoid_print
    print(
      'unresolvable-language pin: no language ${noLanguageParse}us, '
      'unresolvable ${unresolvableParse}us, java ${javaParse}us',
    );

    // The same 5% share SC-001 pins for the empty id. Auto-detection — the
    // obvious "helpful" fallback, which would parse with every registered
    // language — costs roughly as much as the with-language parse and would
    // blow through this by two orders of magnitude.
    expect(unresolvableParse, lessThan(javaParse * 0.05));
    expect(noLanguageParse, lessThan(javaParse * 0.05));
  });

  test('Pasting a large document with no language does not block', () {
    // Upstream issue #246 (fork #111 and #93) reports the stall on a *paste* —
    // "4800+ lines of output into the editor" — not on a keystroke. A paste
    // pays every whole-document term once, in the same frame, so it is the
    // shape most likely to turn into the multi-second freeze the report
    // describes. This pins it separately from the keystroke.
    final document = _document(lines);

    // Warm up: the first paste of a fresh document pays for JIT compilation of
    // the whole path.
    _medianPasteMicros(document, null, 1);

    final noLanguagePaste = _medianPasteMicros(document, null, reps);
    final javaPaste = _medianPasteMicros(document, java, reps);

    // ignore: avoid_print
    print(
      'no-language paste pin: $lines lines\n'
      '  paste median  no language: ${noLanguagePaste}us\n'
      '  paste median  java:        ${javaPaste}us',
    );

    // The acceptance criterion of fork #93: a paste with no language selected
    // must not block for seconds. Measured in the high tens of milliseconds;
    // the bound is one second, a full order of magnitude of headroom, because
    // the absolute stall is what is being ruled out and a CI machine a few
    // times slower than this one must still be able to pass.
    expect(noLanguagePaste, lessThan(1000 * 1000));

    // The no-language paste is not slower than the highlighted one — it is
    // cheaper, because the highlighted paste also pays for the lexer.
    expect(noLanguagePaste, lessThanOrEqualTo(javaPaste));

    // The tripwire. A paste pays the whole-document terms once each, so a
    // change that makes the no-language path do token-level work moves this
    // ratio toward 1. Measured 0.128–0.137; the 0.5 bound keeps the same
    // headroom as the keystroke pin above.
    expect(noLanguagePaste / javaPaste, lessThan(0.5));
  });
}
