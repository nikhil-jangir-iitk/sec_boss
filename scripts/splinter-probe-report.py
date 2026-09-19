#!/usr/bin/env python3
"""Summarise a splinter CSV, and optionally fail when a lint is not empty.

Scratch tooling for the schema-lint probe.

    splinter-probe-report.py findings.csv [--require-zero <lint> ...]
"""

import collections
import csv
import io
import os
import sys


def main() -> int:
    path = sys.argv[1]
    require_zero = [
        sys.argv[i + 1]
        for i, a in enumerate(sys.argv)
        if a == "--require-zero" and i + 1 < len(sys.argv)
    ]

    with open(path, newline="", encoding="utf-8") as handle:
        raw = handle.read()
    # psql prints a command tag for each SET and DO in splinter.sql before the
    # result set, so the header is not the first line.
    rows = list(csv.DictReader(io.StringIO(raw[raw.index("name,title,level,"):])))

    by_name = collections.Counter(r["name"] for r in rows)
    by_level = collections.Counter(r["level"] for r in rows)

    lines = ["## splinter: %d findings" % len(rows), ""]
    lines.append("level counts: " + ", ".join("%s=%d" % kv for kv in sorted(by_level.items())))
    lines += ["", "| lint | count |", "|---|---|"]
    for name, count in sorted(by_name.items()):
        lines.append("| %s | %d |" % (name, count))

    report = "\n".join(lines)
    print(report)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(report + "\n")

    failed = False
    for lint in require_zero:
        count = by_name.get(lint, 0)
        print("\nrequire-zero %s: %d" % (lint, count))
        if count:
            for row in rows:
                if row["name"] == lint:
                    print("   still flagged: " + row["detail"])
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
