#!/usr/bin/env python3
"""Turn adjudicated findings into GitHub inline review comments.

GitHub rejects the ENTIRE review with a 422 if any single comment points at a line
outside the diff, so every comment is validated against the diff first and anything
unanchorable is demoted to the summary body rather than risking the whole post.

    pr_inline.py findings.json --diff pack/diff.patch --out comments.json

Writes the comments array for `pr_submit.sh --inline`, and prints which findings were
demoted and why. Exit 0 even when everything is demoted: a review with no inline
comments is still a valid review.

Confirm the positions against the live API before asking the user to approve a post:

    pr_submit.sh <pr> <verdict> body.md --inline comments.json --validate

That creates a PENDING review (author-visible only), checks GitHub accepts every line,
and deletes it. Note a pending review reads back with line/side null — that is a pending
artifact, not a bad position; the 422 at creation is the real signal.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")

SEV_PREFIX = {
    "blocking": "**Blocking.**",
    "major": "**Major.**",
    "minor": "**Minor.**",
    "question": "**Question.**",
    "nit": "_Nit._",
}


def parse_diff(text: str) -> dict[str, dict[str, set[int]]]:
    """Map path -> {"RIGHT": {lines}, "LEFT": {lines}} for every line inside a hunk.

    A line is commentable only if it appears in a hunk: added and context lines on the
    RIGHT, removed and context lines on the LEFT.
    """
    files: dict[str, dict[str, set[int]]] = {}
    path: str | None = None
    old_ln = new_ln = 0
    in_hunk = False

    for raw in text.splitlines():
        if raw.startswith("diff --git"):
            path, in_hunk = None, False
            continue
        if raw.startswith("+++ "):
            target = raw[4:].strip()
            if target == "/dev/null":
                path = None  # deleted file: nothing on the RIGHT to comment on
            else:
                path = target[2:] if target.startswith("b/") else target
                files.setdefault(path, {"RIGHT": set(), "LEFT": set()})
            in_hunk = False
            continue
        if raw.startswith("--- "):
            continue

        m = HUNK.match(raw)
        if m:
            old_ln, new_ln = int(m.group(1)), int(m.group(3))
            in_hunk = True
            continue

        if not in_hunk or path is None:
            continue

        if raw.startswith("+"):
            files[path]["RIGHT"].add(new_ln)
            new_ln += 1
        elif raw.startswith("-"):
            files[path]["LEFT"].add(old_ln)
            old_ln += 1
        elif raw.startswith(" ") or raw == "":
            files[path]["RIGHT"].add(new_ln)
            files[path]["LEFT"].add(old_ln)
            old_ln += 1
            new_ln += 1
        elif raw.startswith("\\"):
            continue  # "\ No newline at end of file"
        else:
            in_hunk = False
    return files


def nearest(lines: set[int], target: int, window: int) -> int | None:
    """Closest commentable line within `window`, preferring the line at or after target."""
    if not lines:
        return None
    candidates = [ln for ln in lines if abs(ln - target) <= window]
    if not candidates:
        return None
    return min(candidates, key=lambda ln: (abs(ln - target), ln < target))


def build_body(f: dict, moved_from: int | None) -> str:
    sev = f.get("severity", "minor")
    parts = [f"{SEV_PREFIX.get(sev, '**' + sev.title() + '.**')} {f.get('title', '').strip()}"]
    detail = (f.get("claim") or f.get("detail") or "").strip()
    if detail:
        parts.append(detail)
    if f.get("suggestion"):
        parts.append(f"```suggestion\n{f['suggestion']}\n```")
    if f.get("status") == "disputed":
        parts.append("_Reviewers disagreed on this one; both positions are in the summary._")
    if moved_from is not None:
        parts.append(f"_(Finding cites line {moved_from}; anchored here — the nearest line in the diff.)_")
    parts.append(f"<sub>`{f['id']}`</sub>")
    return "\n\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("findings")
    ap.add_argument("--diff", required=True, help="diff.patch from the evidence pack")
    ap.add_argument("--out", default="comments.json")
    ap.add_argument("--window", type=int, default=5, help="lines to search for an anchor (0 disables)")
    ap.add_argument("--include", default="blocking,major,minor,question,nit",
                    help="severities eligible for an inline comment")
    args = ap.parse_args()

    data = json.loads(Path(args.findings).read_text(encoding="utf-8"))
    diff_text = Path(args.diff).read_text(encoding="utf-8", errors="replace")
    files = parse_diff(diff_text)
    if not files:
        print("pr_inline: diff contained no hunks — nothing can be anchored", file=sys.stderr)

    eligible = {s.strip() for s in args.include.split(",") if s.strip()}
    comments: list[dict] = []
    demoted: list[tuple[str, str]] = []

    for f in data.get("findings", []):
        fid = f.get("id", "?")
        if f.get("status") == "rejected":
            continue  # rejected findings are not posted at all
        if f.get("severity") not in eligible:
            demoted.append((fid, f"severity {f.get('severity')} excluded by --include"))
            continue
        path, line = f.get("file"), f.get("line")
        if not path or not isinstance(line, int):
            demoted.append((fid, "no file/line recorded"))
            continue
        if path not in files:
            demoted.append((fid, f"{path} is not in this PR's diff"))
            continue

        side = (f.get("side") or "RIGHT").upper()
        valid = files[path].get(side, set())
        anchor, moved_from = line, None
        if line not in valid:
            alt = nearest(valid, line, args.window) if args.window > 0 else None
            if alt is None:
                demoted.append((fid, f"{path}:{line} is outside the diff hunks"))
                continue
            anchor, moved_from = alt, line

        c = {"path": path, "line": anchor, "side": side, "body": build_body(f, moved_from)}
        start = f.get("start_line")
        if isinstance(start, int) and start < anchor and start in valid:
            c["start_line"] = start
            c["start_side"] = side
        comments.append(c)

    Path(args.out).write_text(json.dumps(comments, indent=2), encoding="utf-8")

    posted_ids = {re.search(r"`(F\d+)`", c["body"]).group(1) for c in comments if re.search(r"`(F\d+)`", c["body"])}
    print(f"pr_inline: {len(comments)} inline comment(s) -> {args.out}", file=sys.stderr)
    for c in comments:
        print(f"  {c['path']}:{c['line']} [{c['side']}]", file=sys.stderr)
    if demoted:
        print(f"pr_inline: {len(demoted)} finding(s) demoted to the summary body:", file=sys.stderr)
        for fid, why in demoted:
            print(f"  {fid}: {why}", file=sys.stderr)
        print("pr_inline: keep these in the summary — they are NOT posted inline.", file=sys.stderr)
    if posted_ids:
        print(f"pr_inline: inline IDs: {', '.join(sorted(posted_ids))}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
