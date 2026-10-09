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
from typing import Dict, List, Tuple

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LCOV = os.path.join(REPO_ROOT, "coverage", "lcov.info")

# Files that cannot be covered on the test platform this gate runs on.
# Each entry needs a reason — keep this list short and honest.
EXEMPT_FILES = {
    # Reaches the DartPad service over HTTP; there is no network in CI.
    "lib/src/analyzer/dartpad_analyzer.dart",
    # Web-only spellcheck workaround; the non-web stub is the other half of
    # the conditional import and is exercised instead.
    "lib/src/code_field/js_workarounds/js_workarounds_web.dart",
}


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
    if not stats:
        sys.stderr.write("No instrumented lines found in %s.\n" % args.lcov)
        return 2

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
