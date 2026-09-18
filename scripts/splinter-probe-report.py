#!/usr/bin/env python3
"""Summarise a splinter CSV into the step log and the job summary.

Scratch tooling for the schema-lint probe. Prints a count per lint and then
every finding's level, lint name and detail line.
"""

import collections
import csv
import os
import sys


def main() -> int:
    path = sys.argv[1]
    with open(path, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    by_name = collections.Counter(r["name"] for r in rows)
    by_level = collections.Counter(r["level"] for r in rows)

    lines = []
    lines.append("## splinter: %d findings" % len(rows))
    lines.append("")
    lines.append("level counts: " + ", ".join("%s=%d" % kv for kv in sorted(by_level.items())))
    lines.append("")
    lines.append("| lint | count |")
    lines.append("|---|---|")
    for name, count in sorted(by_name.items()):
        lines.append("| %s | %d |" % (name, count))
    lines.append("")
    lines.append("### every finding")
    lines.append("")
    for row in sorted(rows, key=lambda r: (r["level"], r["name"], r["detail"])):
        lines.append("- `%s` **%s** %s" % (row["level"], row["name"], row["detail"]))

    report = "\n".join(lines)
    print(report)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(report + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
