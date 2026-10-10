#!/usr/bin/env python3
"""Line-coverage gate for zuraffa_code_editor.

Usage:
    flutter test --coverage
    ./tool/coverage_gate.py                 # report only
    ./tool/coverage_gate.py --min 88        # fail below 88%
    ./tool/coverage_gate.py --min 88 --per-file  # also list the worst files

Reads `coverage/lcov.info` (the file `flutter test --coverage` writes) and
computes line coverage the same way lcov does: a `DA:<line>,<count>` entry is
covered when its count is greater than zero, and ignored entirely when the count
is `-`... not applicable lines are simply absent from lcov.

Exit codes: 0 = threshold met (or not given), 1 = below threshold, 2 = no
coverage file / unreadable input.
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Dict, List, Optional, Tuple

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LCOV = os.path.join(REPO_ROOT, "coverage", "lcov.info")

# Files that cannot be covered on the test platform this gate runs on.
# Each entry needs a reason — keep this list short and honest.
EXEMPT_FILES = {
    # Reaches the DartPad service over HTTP; there is no network in CI.
    "lib/src/analyzer/dartpad_analyzer.dart",
    # The eight entries below are unreachable from the package's public API:
    # they are not exported by `zuraffa_code_editor.dart` and no file under
    # `lib/` imports them. They only show up in `coverage/lcov.info` because
    # the CI helper test imports every file under `lib/` to force coverage
    # collection. Heavily-used wip modules (`wip/autocomplete/*`) are wired
    # into `code_field.dart` / `code_controller.dart` and stay inside the
    # gate — close their gaps with tests, not exemptions.
    "lib/src/code/text_span.dart",
    "lib/src/wip/TooltipTextSpan.dart",
    "lib/src/wip/getErrorsMap.dart",
    "lib/src/wip/language_syntax/brackets_counting.dart",
    "lib/src/wip/language_syntax/golang_syntax.dart",
    "lib/src/wip/language_syntax/java_dart_syntax.dart",
    "lib/src/wip/language_syntax/python_syntax.dart",
    "lib/src/wip/language_syntax/scala_syntax.dart",
}

# Individual lines that cannot be covered on this platform, with the reason.
# Same contract as EXEMPT_FILES: keep the list short and honest, and prove the
# claim — if a line here becomes reachable later, the test that reaches it must
# be added and the entry dropped.
EXEMPT_LINES: Dict[str, Dict[int, str]] = {
    # `keywordSemantics` (lib/src/highlight/node.dart) only ever returns
    # `KeywordSemantics.import` or null: it maps `import`/`package` to
    # `.import` and everything else to null. Nothing in the package or in the
    # `highlight` modes can produce `possibleImport`, so this call site and the
    # branch it drives in TextFoldableBlockParser.submitCurrentLine() are dead
    # until a language is given that maps a keyword to it. The `possibleImport`
    # enum value itself is load-bearing elsewhere (LineSemantics,
    # AbstractFoldableBlockParser.endImportSequenceIfAny) so the branch stays.
    "lib/src/folding/parsers/highlight.dart": {
        93: "KeywordSemantics.possibleImport is never produced",
    },
    "lib/src/folding/parsers/text.dart": {
        27: "decorator of setFoundPossibleImport, only called from highlight.dart:93",
        28: "setFoundPossibleImport, only called from highlight.dart:93",
        49: "foundMultilineComment getter, never read from lib/",
        79: "the possibleImport branch of submitCurrentLine, unreachable",
        80: "the possibleImport branch of submitCurrentLine, unreachable",
    },
    # A private const constructor whose only job is to stop the class being
    # instantiated: every member is static, so there is no call site to cover.
    "lib/src/single_line_comments/parser/single_line_comments.dart": {
        14: "private constructor, never called",
    },
    # `select()` has already found `pattern` at `position` via `indexOf`, so
    # `matchAsPrefix` cannot return null there.
    "lib/src/code_field/text_editing_value.dart": {
        188: "matchAsPrefix cannot fail after indexOf matched",
    },
    # The only `ScrollablePositionedList` that can attach this controller is the
    # one built by `Popup` itself, and that list only receives the controller
    # through this very assignment — so there is no build in which it is already
    # attached. Attaching it to a second list instead trips
    # `ItemScrollController._attach`'s "already attached" assertion, so the
    # branch is dead both in production and in tests.
    "lib/src/wip/autocomplete/popup.dart": {
        76: "ItemScrollController can never be attached before it is assigned",
    },
    # `_visibleLineIndex` counts the newlines of the highlighted nodes, which
    # concatenate to the *visible* text; that text can never carry more newlines
    # than the full text `code.lines` was split from, so the index tops out at
    # `lines.length - 1` and the clamp never engages.
    "lib/src/code_field/span_builder.dart": {
        75: "_visibleLineIndex cannot reach code.lines.length",
    },
    # The fold toggle of a block that is already folded is always overwritten by
    # the second loop below, which adds a toggle for every folded block — so the
    # lambda built here is discarded before it can ever be tapped.
    "lib/src/gutter/gutter.dart": {
        165: "the folded-block loop below overwrites this toggle",
    },
    # The popup is created from a post-frame callback, so `findRenderObject()`
    # has a laid out `RenderBox` ancestor by construction.
    "lib/src/gutter/error.dart": {
        71: "findRenderObject is non-null after the post-frame callback",
    },
    # `_getNextOrFirstMatchIndex()` only returns null when the match list is
    # empty, and the guard two lines above has already ruled that out — so this
    # throw is unreachable.
    "lib/src/search/search_navigation_controller.dart": {
        60: "unreachable defensive throw, matches are already checked non-empty",
    },
}


def parse_lcov_lines(
    path: str,
) -> Dict[str, Dict[int, Tuple[int, int]]]:
    """Return {file: {line: (hit_count, -)}} for every DA: entry."""
    result: Dict[str, Dict[int, Tuple[int, int]]] = {}
    current: Optional[str] = None
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("SF:"):
                current = line[len("SF:") :]
                result.setdefault(current, {})
            elif line.startswith("DA:") and current is not None:
                parts = line[len("DA:") :].split(",")
                if len(parts) < 2:
                    continue
                try:
                    result[current][int(parts[0])] = (int(parts[1]), -1)
                except ValueError:
                    continue
    return result


def parse_lcov(path: str) -> Dict[str, Tuple[int, int]]:
    """Return {file: (covered_lines, instrumented_lines)}."""
    result: Dict[str, Tuple[int, int]] = {}
    current = None
    covered = 0
    total = 0

    def flush() -> None:
        nonlocal current, covered, total
        if current is not None:
            prev = result.get(current, (0, 0))
            result[current] = (prev[0] + covered, prev[1] + total)
        current = None
        covered = 0
        total = 0

    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("SF:"):
                flush()
                current = line[len("SF:") :]
            elif line.startswith("DA:"):
                parts = line[len("DA:") :].split(",")
                if len(parts) < 2:
                    continue
                _, count = parts[0], parts[1]
                if count == "-":
                    continue
                total += 1
                try:
                    if int(count) > 0:
                        covered += 1
                except ValueError:
                    continue
            elif line == "end_of_record":
                flush()
    flush()
    return result


def relative(path: str) -> str:
    marker = os.path.join("lib", "")
    idx = path.find(marker)
    return path[idx:] if idx >= 0 else path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lcov", default=DEFAULT_LCOV)
    parser.add_argument(
        "--min",
        type=float,
        default=None,
        help="minimum line-coverage percentage required to pass",
    )
    parser.add_argument(
        "--per-file",
        action="store_true",
        help="print the least covered files",
    )
    args = parser.parse_args()

    if not os.path.exists(args.lcov):
        sys.stderr.write(
            "No coverage file at %s — run `flutter test --coverage` first.\n"
            % args.lcov
        )
        return 2

    stats = parse_lcov(args.lcov)
    line_stats = parse_lcov_lines(args.lcov)
    if not stats:
        sys.stderr.write("No instrumented lines found in %s.\n" % args.lcov)
        return 2

    # Lines exempted individually are neither counted nor missed: they are
    # removed from both the numerator and the denominator of the file they sit
    # in, exactly as EXEMPT_FILES removes whole files.
    for path, lines in EXEMPT_LINES.items():
        for line in lines:
            entry = line_stats.get(path, {}).get(line)
            if entry is None or entry[0] == -1:
                sys.stderr.write(
                    "stale line exemption: %s:%d matches nothing in %s\n"
                    % (path, line, os.path.basename(args.lcov))
                )
                continue
            hit = entry[0]
            file_stat = stats.get(path)
            if file_stat is None:
                continue
            cov, tot = file_stat
            if hit > 0:
                stats[path] = (cov - 1, tot - 1)
            else:
                stats[path] = (cov, tot - 1)

    matched = {relative(p) for p in stats}
    stale = sorted(EXEMPT_FILES - matched)
    if stale:
        print(
            "stale exemptions (matched nothing in %s): %s"
            % (os.path.basename(args.lcov), ", ".join(stale))
        )

    counted = {
        path: (cov, tot)
        for path, (cov, tot) in stats.items()
        if tot > 0 and relative(path) not in EXEMPT_FILES
    }
    exempt = {relative(p) for p in stats if relative(p) in EXEMPT_FILES and stats[p][1] > 0}

    covered = sum(cov for cov, _ in counted.values())
    total = sum(tot for _, tot in counted.values())
    pct = covered * 100.0 / total if total else 0.0

    print(
        "zuraffa_code_editor line coverage: %.2f%% (%d/%d lines over %d files)"
        % (pct, covered, total, len(counted))
    )
    if exempt:
        print(
            "excluded from the gate (see EXEMPT_FILES): %s"
            % ", ".join(sorted(exempt))
        )
    exempt_lines = sum(len(v) for v in EXEMPT_LINES.values())
    if exempt_lines:
        print("excluded individual lines (see EXEMPT_LINES): %d" % exempt_lines)

    zero = sorted(
        (path for path, (cov, tot) in counted.items() if cov == 0),
    )
    if zero:
        print("zero-coverage files:")
        for path in zero:
            print("  %-64s %d lines" % (relative(path), counted[path][1]))

    if args.per_file:
        worst: List[Tuple[float, int, str]] = sorted(
            (cov * 100.0 / tot, tot - cov, relative(path))
            for path, (cov, tot) in counted.items()
        )
        print("least covered files:")
        for share, missing, path in worst[:15]:
            print("  %-64s %6.2f%% (%d lines uncovered)" % (path, share, missing))

    if args.min is None:
        return 0

    if pct + 1e-9 < args.min:
        sys.stderr.write(
            "Coverage %.2f%% is below the required %.2f%%.\n" % (pct, args.min)
        )
        return 1
    print("Coverage gate: %.2f%% >= %.2f%% — OK" % (pct, args.min))
    return 0


if __name__ == "__main__":
    sys.exit(main())
