# Quickstart: per-line-background

Validation guide for the `lineBackgroundBuilder` feature. Every command below is
run from the repository root unless stated otherwise.

## Prerequisites

- Flutter on the pinned SDK (CI pins 3.19.6; local is 3.47.5 — do not use APIs
  newer than 3.19.6).
- Dependencies resolved: `flutter pub get`.

## The feature in one paragraph

A host assigns `controller.lineBackgroundBuilder`, a `Color? Function(int)?`
receiving a line's 0-based index in the full unfolded buffer. Returning a colour
tints that line's whole row; returning `null` leaves it alone; leaving the hook
`null` changes nothing at all.

## 1. Static gates

```bash
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
```

Both must be silent. Two files had pre-existing `dart format` drift on master
(`lib/src/code/code.dart`,
`test/src/folding/folded_closing_line_test.dart`) — if either shows up, it is not
yours.

## 2. The feature's tests

```bash
flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart
```

`--concurrency=2` is mandatory on this host; `flutter test` ignores
`dart_test.yaml`.

## 3. Full suite + coverage gate (CI-identical)

```bash
python3 - <<'EOF'
import os
files=[]
for root,dirs,fs in os.walk('lib'):
    dirs[:] = [d for d in dirs if d not in ('.dart_tool',)]
    for f in sorted(fs):
        if f.endswith('.dart') and not f.endswith('_web.dart'):
            files.append(os.path.join(root,f))
lines=["// GENERATED coverage helper — imports every lib file so lcov sees it all.",
       "// Temporary: deleted after the coverage gate run.",""]
for f in sorted(files):
    lines.append("import '%s';" % f.replace('lib/','package:zuraffa_code_editor/',1))
lines += ["", "void main() {}", ""]
open('test/coverage_helper_test.dart','w').write("\n".join(lines))
print("wrote helper with %d imports" % len(files))
EOF
flutter test --coverage --concurrency=2
python3 tool/coverage_gate.py --min 100
rm -f test/coverage_helper_test.dart
rm -rf coverage
```

The final line of the gate must read `Coverage gate: 100.00% >= 100.00% — OK`.
`flutter test` hides failures, so grep for `EXCEPTION CAUGHT` if the gate says
`All tests passed!` while coverage looks odd.

## 4. Manual end-to-end check (the example app)

```bash
cd example && flutter run -d macos   # or any device
```

In `example/lib/main.dart`, add to the `CodeController`:

```dart
..lineBackgroundBuilder = (line) => line == 3 ? Colors.yellow : null
```

Expected: line 4 of the document (index 3) is tinted across its entire row,
including the empty stretch past its last character; every other line is
untinted. Then fold a block covering line 4 — the tint disappears with the line.
Then open search and match text on line 4 — the matched run shows the search
colour, the rest of the row stays yellow.

## 5. What must fail if the implementation is wrong

| Broken implementation | Failing check |
| --- | --- |
| Tint via `TextStyle.backgroundColor` only | §2's full-row-width test — a one-character line's tint is glyph-width, not row-width |
| Index taken from `SpanBuilder._visibleLineIndex` unmapped | §2's fold test and multi-line-node test — a line under a fold or inside a block comment is not tinted |
| Padded characters widen the tint | §2's text-integrity test and the full suite's text assertions |
| Tint applied to the no-language path unconditionally | §3's default tree comparison and existing span tests |
| Tint drawn over search highlighting | §2's search-layering test |
