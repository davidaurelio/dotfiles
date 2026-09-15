#!/usr/bin/env python3
"""Diagnostics for a dual-model PR review, plus a cross-run ledger.

Turns the adjudicated findings file into the verbose diagnostics report and appends
one record per run to $XDG_STATE_HOME/copilot-skills/pr-review/ledger.jsonl, so "is the second model
earning its keep?" becomes a question with an answer instead of a vibe.

Usage:
    review_report.py findings.json [--verbosity normal|verbose|debug] [--no-ledger]
    review_report.py --summary [--last N]      # cross-run stats from the ledger

Schema for findings.json is documented in references/diagnostics.md. Validation is
strict: a malformed field fails loudly here rather than producing a wrong statistic.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

def _default_ledger() -> Path:
    """XDG state dir, under a copilot-skills/ namespace so it is obvious what wrote it.

    Not ~/.copilot/ (the CLI owns that namespace) and not the skill directory
    (package_skill.py zips everything there, which would publish review history to
    anyone the skill is shared with).
    """
    base = os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local" / "state")
    return Path(base) / "copilot-skills" / "pr-review" / "ledger.jsonl"


LEDGER = Path(os.environ.get("PR_REVIEW_LEDGER") or _default_ledger())
# Older default locations, newest first. Tried in order on first run.
_LEGACY_LEDGERS = (
    Path.home() / ".local" / "state" / "pr-review" / "ledger.jsonl",
    Path.home() / ".copilot" / "pr-review" / "ledger.jsonl",
)


def _migrate_legacy_ledger() -> None:
    """One-time move from an older default location. Never overwrites an existing ledger."""
    if LEDGER.exists():
        return
    for legacy in _LEGACY_LEDGERS:
        if legacy == LEDGER or not legacy.exists():
            continue
        try:
            LEDGER.parent.mkdir(parents=True, exist_ok=True)
            legacy.replace(LEDGER)
            print(f"review_report: moved ledger {legacy} -> {LEDGER}", file=sys.stderr)
        except OSError as exc:
            print(f"review_report: could not migrate ledger from {legacy} ({exc})", file=sys.stderr)
        return

SEVERITIES = ["blocking", "major", "minor", "question", "nit"]
SEV_RANK = {s: i for i, s in enumerate(SEVERITIES)}
STATUSES = ["accepted", "rejected", "disputed"]
VERDICTS = ["request_changes", "approve_with_conditions", "approve", "comment"]
FOUND_BY = {"a", "b", "orchestrator"}
AXES = {"inward", "outward"}
ADVERSARY_VERDICTS = {"upheld", "rejected", "downgraded", "upgraded"}
CHECKS = set(range(1, 9))
EFFORTS = {"low", "medium", "high", "xhigh", "max"}

CHECK_NAMES = {
    1: "Comments/docs are assertions to verify",
    2: "Do the arithmetic on caps and limits",
    3: "Read the helper, not its name",
    4: "Check the boring precondition",
    5: "Outward pass: callers, failures, consumers",
    6: "'No callers break' != 'someone reads it'",
    7: "Check established practice before crying risk",
    8: "Verify your own cites",
}


# --------------------------------------------------------------------------- load


def _fail(msg: str) -> None:
    print(f"review_report: {msg}", file=sys.stderr)
    raise SystemExit(2)


def load(path: str) -> dict:
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        _fail(f"no such findings file: {path}")
    except json.JSONDecodeError as exc:
        _fail(f"findings file is not valid JSON: {exc}")
    for key in ("pr", "run", "verdict", "findings"):
        if key not in data:
            _fail(f"findings file missing required key: {key!r}")
    if data["verdict"] not in VERDICTS:
        _fail(f"verdict must be one of {VERDICTS}, got {data['verdict']!r}")
    for i, f in enumerate(data["findings"]):
        for key in ("id", "title", "severity", "found_by", "status"):
            if key not in f:
                _fail(f"finding[{i}] missing required key: {key!r}")
        if f["severity"] not in SEVERITIES:
            _fail(f"finding {f['id']}: severity must be one of {SEVERITIES}, got {f['severity']!r}")
        if f["status"] not in STATUSES:
            _fail(f"finding {f['id']}: status must be one of {STATUSES}, got {f['status']!r}")
        if not isinstance(f["found_by"], list) or not f["found_by"]:
            _fail(f"finding {f['id']}: found_by must be a non-empty list")
        bad = [w for w in f["found_by"] if w not in FOUND_BY]
        if bad:
            _fail(f"finding {f['id']}: found_by has unknown reviewer(s) {bad}; must be from {sorted(FOUND_BY)}")
        # Optional fields are validated when present: a typo here does not crash the
        # report, it silently produces a wrong statistic, which is worse.
        if f.get("axis") is not None and f["axis"] not in AXES:
            _fail(f"finding {f['id']}: axis must be one of {sorted(AXES)}, got {f['axis']!r}")
        if f.get("adversary") is not None and f["adversary"] not in ADVERSARY_VERDICTS:
            _fail(f"finding {f['id']}: adversary must be one of {sorted(ADVERSARY_VERDICTS)}, got {f['adversary']!r}")
        if f.get("check_id") is not None and f["check_id"] not in CHECKS:
            _fail(f"finding {f['id']}: check_id must be 1-8 or null, got {f['check_id']!r}")
        for field in ("proposed_severity", "cite_ok"):
            val = f.get(field)
            if val is None:
                continue
            if not isinstance(val, dict):
                _fail(f"finding {f['id']}: {field} must be an object keyed by reviewer")
            bad = [w for w in val if w not in FOUND_BY]
            if bad:
                _fail(f"finding {f['id']}: {field} has unknown reviewer(s) {bad}")
            if field == "proposed_severity":
                bad_sev = [v for v in val.values() if v not in SEVERITIES]
                if bad_sev:
                    _fail(f"finding {f['id']}: proposed_severity has invalid severity {bad_sev}")
    cited = (data.get("coverage") or {}).get("files_cited")
    if cited is not None:
        if not isinstance(cited, dict):
            _fail("coverage.files_cited must be an object keyed by reviewer")
        # Read via a fixed ("a","b") tuple downstream, so an unknown key is not an error
        # there — it silently drops that reviewer's files and reports 0% coverage.
        bad = [w for w in cited if w not in FOUND_BY]
        if bad:
            _fail(f"coverage.files_cited has unknown reviewer(s) {bad}; must be from {sorted(FOUND_BY)}")
    effort = data["run"].get("effort")
    if effort is not None and effort not in EFFORTS:
        _fail(f"run.effort must be one of {sorted(EFFORTS)}, got {effort!r}")
    return data


def _labels(data: dict) -> dict[str, str]:
    """Map the reviewer slots to their model names for display."""
    models = data["run"].get("models", {})
    out = {"a": models.get("a", "reviewer-a"), "b": models.get("b", "reviewer-b"), "orchestrator": "orchestrator"}
    if models.get("adversary"):
        adv = models["adversary"]
        # `max` runs two cross-graded adversaries, so a list is a valid value here.
        out["adversary"] = " + ".join(adv) if isinstance(adv, list) else adv
    return out


# ---------------------------------------------------------------------- analysis


def scoreboard(data: dict) -> dict[str, dict]:
    """Per-reviewer: proposed, accepted, rejected, unique, false-positive rate, cite accuracy."""
    stats: dict[str, dict] = defaultdict(
        lambda: {"proposed": 0, "accepted": 0, "rejected": 0, "disputed": 0, "unique": 0, "cite_ok": 0, "cite_checked": 0, "sev_over": 0, "sev_under": 0}
    )
    for f in data["findings"]:
        for who in f["found_by"]:
            s = stats[who]
            s["proposed"] += 1
            s[f["status"]] += 1
            if f["status"] == "accepted" and len([w for w in f["found_by"] if w in ("a", "b")]) == 1:
                # "Unique" means no OTHER reviewer found it. Orchestrator co-authorship
                # must not cancel a reviewer's credit — it is not a competing reviewer.
                s["unique"] += 1
            cite = (f.get("cite_ok") or {}).get(who)
            if cite is not None:
                s["cite_checked"] += 1
                s["cite_ok"] += 1 if cite else 0
            proposed_sev = (f.get("proposed_severity") or {}).get(who)
            if proposed_sev in SEV_RANK and f["status"] == "accepted":
                # Lower rank index == more severe.
                delta = SEV_RANK[f["severity"]] - SEV_RANK[proposed_sev]
                if delta > 0:
                    s["sev_over"] += 1  # reviewer rated it more severe than final
                elif delta < 0:
                    s["sev_under"] += 1
    return dict(stats)


def agreement(data: dict) -> tuple[int, int, float]:
    """Both-found vs union, over ACCEPTED findings only (rejected ones aren't signal)."""
    accepted = [f for f in data["findings"] if f["status"] == "accepted"]
    reviewer_found = [f for f in accepted if {"a", "b"} & set(f["found_by"])]
    both = sum(1 for f in reviewer_found if {"a", "b"} <= set(f["found_by"]))
    union = len(reviewer_found)
    return both, union, (both / union if union else 0.0)


def _pct(num: int, den: int) -> str:
    return f"{100 * num / den:.0f}%" if den else "n/a"


def _table(rows: list[list[str]], headers: list[str]) -> str:
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


# ------------------------------------------------------------------------ report


def report(data: dict, verbosity: str) -> str:
    lab = _labels(data)
    pr, run = data["pr"], data["run"]
    findings = data["findings"]
    accepted = [f for f in findings if f["status"] == "accepted"]
    out: list[str] = []

    out.append(f"# Review diagnostics — {pr.get('repo', '?')}#{pr.get('number', '?')}")
    out.append("")
    out.append(
        f"**Verdict:** `{data['verdict']}` · **effort:** `{run.get('effort', '?')}` · "
        f"**reviewers:** {lab['a']} + {lab['b']}" + (f" · **adversary:** {lab['adversary']}" if "adversary" in lab else "")
    )
    out.append("")

    sev_counts = Counter(f["severity"] for f in accepted)
    out.append("**Accepted findings:** " + (", ".join(f"{sev_counts[s]} {s}" for s in SEVERITIES if sev_counts[s]) or "none"))
    rejected = [f for f in findings if f["status"] == "rejected"]
    disputed = [f for f in findings if f["status"] == "disputed"]
    if rejected:
        out.append(f"**Rejected during adjudication:** {len(rejected)}")
    if disputed:
        out.append(f"**Disputed (adversary vs adjudicator):** {len(disputed)}")
    out.append("")

    # --- the headline: who found what alone --------------------------------
    out.append("## Unique finds")
    out.append("")
    for who in ("a", "b", "orchestrator"):
        proposed = [f for f in findings if who in f["found_by"]]
        solo = [f for f in accepted if f["found_by"] == [who]]
        if not solo:
            if who in ("a", "b") and proposed:
                out.append(f"**Only {lab.get(who, who)}:** nothing — every accepted finding it raised was also raised by the other reviewer.")
                out.append("")
            continue
        out.append(f"**Only {lab.get(who, who)}:**")
        for f in solo:
            loc = f" (`{f['file']}:{f['line']}`)" if f.get("file") else ""
            out.append(f"- [{f['severity']}] {f['title']}{loc}")
        out.append("")
    both, union, rate = agreement(data)
    out.append(f"**Agreement:** {both}/{union} accepted reviewer findings were found by both ({_pct(both, union)}).")
    out.append("")
    if union and rate < 0.35:
        out.append("> Low overlap — the second model is doing independent work, not echoing the first.")
        out.append("")
    elif union and rate > 0.8:
        out.append("> High overlap — the second model is mostly confirming. Consider a cheaper second reviewer, or raise effort to push them deeper.")
        out.append("")

    # --- scoreboard ---------------------------------------------------------
    stats = scoreboard(data)
    out.append("## Reviewer scoreboard")
    out.append("")
    rows = []
    for who in ("a", "b", "orchestrator"):
        s = stats.get(who)
        if not s:
            continue
        rows.append(
            [
                lab.get(who, who),
                str(s["proposed"]),
                str(s["accepted"]),
                str(s["unique"]),
                f"{s['rejected']} ({_pct(s['rejected'], s['proposed'])})",
                _pct(s["cite_ok"], s["cite_checked"]),
                f"+{s['sev_over']}/-{s['sev_under']}",
            ]
        )
    out.append(_table(rows, ["reviewer", "proposed", "accepted", "unique", "false positives", "cite accuracy", "severity over/under"]))
    out.append("")
    out.append("_Severity over/under: how often the reviewer rated a finding more (+) or less (-) severe than the adjudicated result._")
    out.append("")

    if verbosity == "normal":
        return "\n".join(out)

    # --- findings matrix ----------------------------------------------------
    out.append("## Findings matrix")
    out.append("")
    rows = []
    for f in findings:
        rows.append(
            [
                f["id"],
                f["severity"],
                f"`{f['file']}:{f['line']}`" if f.get("file") else "—",
                "+".join(lab.get(w, w) for w in f["found_by"]),
                f["status"],
                str(f.get("check_id") or "—"),
                f.get("adversary") or "—",
            ]
        )
    out.append(_table(rows, ["id", "severity", "location", "found by", "status", "check", "adversary"]))
    out.append("")

    # --- which anti-bias check earned its keep ------------------------------
    hist = Counter(f.get("check_id") for f in accepted if f.get("check_id"))
    if hist:
        out.append("## Which check earned each finding")
        out.append("")
        rows = [[str(cid), CHECK_NAMES.get(cid, "?"), str(n)] for cid, n in sorted(hist.items(), key=lambda kv: -kv[1])]
        out.append(_table(rows, ["#", "check", "findings"]))
        out.append("")
        unused = [c for c in CHECK_NAMES if c not in hist]
        if unused:
            out.append(f"_Checks that produced nothing this run: {', '.join(str(c) for c in unused)}. Normal on a small PR; a persistent zero across many runs means the check is dead weight or is being skipped._")
            out.append("")

    # --- search axis --------------------------------------------------------
    axis = defaultdict(Counter)
    for f in accepted:
        if f.get("axis"):
            for who in f["found_by"]:
                axis[who][f["axis"]] += 1
    if axis:
        out.append("## Search axis")
        out.append("")
        rows = [[lab.get(w, w), str(c.get("inward", 0)), str(c.get("outward", 0))] for w, c in axis.items()]
        out.append(_table(rows, ["reviewer", "inward (code/helpers)", "outward (callers/consumers)"]))
        out.append("")
        out.append("_A reviewer scoring zero on an axis is the #4907 failure mode: confident depth in one direction, blind in the other._")
        out.append("")

    # --- adversary ----------------------------------------------------------
    adv = Counter(f.get("adversary") for f in findings if f.get("adversary"))
    if adv:
        out.append("## Adversarial pass")
        out.append("")
        out.append(", ".join(f"**{k}:** {v}" for k, v in adv.items()))
        out.append("")
        killed = [f for f in findings if f.get("adversary") == "rejected"]
        for f in killed:
            out.append(f"- Killed `{f['id']}` — {f.get('reject_reason') or 'no reason recorded'}")
        if killed:
            out.append("")
        softened = adv.get("downgraded", 0) + adv.get("rejected", 0)
        total_adv = sum(adv.values())
        if total_adv >= 4 and softened / total_adv >= 0.75:
            out.append(
                f"> **Ratchet warning:** {softened}/{total_adv} verdicts pushed severity down. "
                "The adversary is rewarded for finding fault and the only fault a finding can have "
                "is being too strong, so a near-unanimous softening is a property of its incentive. "
                "Spot-check two downgrades against the code before applying them."
            )
            out.append("")

    # --- cleared ------------------------------------------------------------
    cleared = data.get("cleared") or []
    if cleared:
        overturned = [c for c in cleared if c.get("upheld") is False]
        out.append(f"## Cleared claims: {len(cleared)}" + (f" ({len(overturned)} overturned on re-check)" if overturned else ""))
        out.append("")
        for c in overturned:
            out.append(f"- Overturned: {c.get('claim')}")
        if overturned:
            out.append("")

    # --- coverage blind spots ----------------------------------------------
    cited = data.get("coverage", {}).get("files_cited") or {}
    if cited:
        changed = set(pr.get("files") or [])
        out.append("## File coverage")
        out.append("")
        rows = []
        for who in ("a", "b"):
            files = set(cited.get(who) or [])
            rows.append([lab.get(who, who), str(len(files)), _pct(len(files), len(changed)) if changed else "n/a"])
        out.append(_table(rows, ["reviewer", "files cited", "of changed files"]))
        out.append("")
        if changed:
            union_cited = set(cited.get("a") or []) | set(cited.get("b") or [])
            blind = sorted(changed - union_cited)
            if blind:
                out.append(f"**Cited by neither reviewer ({len(blind)}):**")
                out.extend(f"- `{p}`" for p in blind[:20])
                if len(blind) > 20:
                    out.append(f"- …and {len(blind) - 20} more")
                out.append("")
                out.append("_Not automatically a gap — docs and test files often need no comment. Worth a glance when a source file appears here._")
                out.append("")

    wall = run.get("wall_clock_s") or {}
    if wall:
        out.append("## Cost")
        out.append("")
        out.append(", ".join(f"{k} ({lab.get(k, k)}): {v}s" for k, v in wall.items()) + f" · total {sum(wall.values())}s")
        out.append("")

    if verbosity == "debug":
        out.append("## Raw findings")
        out.append("")
        out.append("```json")
        out.append(json.dumps(findings, indent=2))
        out.append("```")

    return "\n".join(out)


# ------------------------------------------------------------------------ ledger


def ledger_record(data: dict) -> dict:
    stats = scoreboard(data)
    both, union, rate = agreement(data)
    accepted = [f for f in data["findings"] if f["status"] == "accepted"]
    return {
        "ts": data["run"].get("started_at") or datetime.now(timezone.utc).isoformat(),
        "repo": data["pr"].get("repo"),
        "pr": data["pr"].get("number"),
        "head_oid": data["pr"].get("head_oid"),
        "effort": data["run"].get("effort"),
        "models": data["run"].get("models", {}),
        "verdict": data["verdict"],
        "severity_counts": dict(Counter(f["severity"] for f in accepted)),
        "per_model": {k: dict(v) for k, v in stats.items()},
        "agreement": {"both": both, "union": union, "rate": round(rate, 3)},
        "checks": {str(k): v for k, v in Counter(f.get("check_id") for f in accepted if f.get("check_id")).items()},
        "wall_clock_s": data["run"].get("wall_clock_s", {}),
    }


def append_ledger(data: dict) -> Path:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(ledger_record(data), ensure_ascii=False) + "\n")
    return LEDGER


def summary(last: int | None) -> str:
    if not LEDGER.exists():
        return f"No ledger yet at {LEDGER} — run a review first."
    runs = [json.loads(line) for line in LEDGER.read_text(encoding="utf-8").splitlines() if line.strip()]
    if last:
        runs = runs[-last:]
    if not runs:
        return "Ledger is empty."

    out = [f"# Review ledger — {len(runs)} run(s)", "", f"_Source: {LEDGER}_", ""]
    out.append("**Verdicts:** " + ", ".join(f"{k}: {v}" for k, v in Counter(r["verdict"] for r in runs).items()))
    out.append("")

    # Per-model aggregates keyed by the actual model name, so swapping models mid-history
    # still attributes correctly.
    agg: dict[str, Counter] = defaultdict(Counter)
    for r in runs:
        for slot, s in (r.get("per_model") or {}).items():
            name = (r.get("models") or {}).get(slot, slot)
            for k in ("proposed", "accepted", "unique", "rejected"):
                agg[name][k] += s.get(k, 0)
            agg[name]["runs"] += 1
    rows = []
    for name, c in sorted(agg.items(), key=lambda kv: -kv[1]["accepted"]):
        rows.append([name, str(c["runs"]), str(c["proposed"]), str(c["accepted"]), str(c["unique"]), f"{c['rejected']} ({_pct(c['rejected'], c['proposed'])})"])
    out.append(_table(rows, ["model", "runs", "proposed", "accepted", "unique", "false positives"]))
    out.append("")
    out.append("_`unique` is the column that justifies a second reviewer: accepted findings no other reviewer produced._")
    out.append("")

    rates = [r["agreement"]["rate"] for r in runs if r.get("agreement", {}).get("union")]
    if rates:
        out.append(f"**Mean agreement:** {sum(rates) / len(rates):.0%} across {len(rates)} run(s) with reviewer findings.")
        out.append("")

    hist = Counter()
    for r in runs:
        for cid, n in (r.get("checks") or {}).items():
            hist[int(cid)] += n
    if hist:
        out.append("## Check productivity (all runs)")
        out.append("")
        rows = [[str(cid), CHECK_NAMES.get(cid, "?"), str(n)] for cid, n in sorted(hist.items(), key=lambda kv: -kv[1])]
        out.append(_table(rows, ["#", "check", "findings"]))
        out.append("")
        dead = [c for c in CHECK_NAMES if c not in hist]
        if dead and len(runs) >= 5:
            out.append(f"_Zero findings across {len(runs)} runs from check(s) {', '.join(str(c) for c in dead)} — review whether they are being applied, or drop them._")
    return "\n".join(out)


def prior_run(ref: str) -> str:
    """Print the last ledger record for owner/repo#N, so a re-review can scope to the delta."""
    if "#" not in ref:
        _fail("--prior expects owner/repo#N")
    repo, _, num = ref.rpartition("#")
    if not num.isdigit():
        _fail("--prior expects owner/repo#N")
    if not LEDGER.exists():
        return f"No ledger at {LEDGER} — no prior review recorded."
    matches = [
        r
        for line in LEDGER.read_text(encoding="utf-8").splitlines()
        if line.strip()
        for r in [json.loads(line)]
        if r.get("repo") == repo and str(r.get("pr")) == num
    ]
    if not matches:
        return f"No prior review recorded for {ref}."
    last = matches[-1]
    out = [f"Prior review of {ref} — round {len(matches)}", ""]
    out.append(f"- reviewed at: {last['ts']}")
    out.append(f"- head reviewed: {last.get('head_oid') or 'NOT RECORDED (pre-dates head_oid; diff against the merge base instead)'}")
    out.append(f"- verdict: {last['verdict']}")
    out.append(f"- findings: {last.get('severity_counts') or {}}")
    if last.get("head_oid"):
        out.append("")
        out.append(f"Scope the re-review to the delta:\n    git diff {last['head_oid']}..HEAD")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("findings", nargs="?", help="adjudicated findings JSON")
    ap.add_argument("--verbosity", choices=["normal", "verbose", "debug"], default="verbose")
    ap.add_argument("--no-ledger", action="store_true", help="do not append this run to the ledger")
    ap.add_argument("--summary", action="store_true", help="print cross-run ledger stats instead")
    ap.add_argument("--last", type=int, default=None, help="with --summary, only the last N runs")
    ap.add_argument("--prior", metavar="OWNER/REPO#N", help="show the last recorded review of a PR, for re-review scoping")
    args = ap.parse_args()

    _migrate_legacy_ledger()

    if args.prior:
        print(prior_run(args.prior))
        return 0
    if args.summary:
        print(summary(args.last))
        return 0
    if not args.findings:
        ap.error("findings JSON path required (or use --summary)")

    data = load(args.findings)
    print(report(data, args.verbosity))
    if not args.no_ledger:
        path = append_ledger(data)
        print(f"\n_Appended to ledger: {path}_")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
