# Adjudication

The orchestrator owns the posted review. Reviewer output is raw material, never content to
forward.

## Hard rule: no pass-through

Independently verify every finding at its cited line before it enters the review. Open the
file. Read the surrounding code. Confirm the claim is true *as stated*, not merely plausible.
Two models agreeing is not verification — it is correlated guessing until someone checks.

Record the outcome per finding as `cite_ok[reviewer]`, which feeds the cite-accuracy metric.
A finding whose claim is true but whose cite is wrong is **accepted with a corrected cite**
and `cite_ok: false` — the author gets the right line, the diagnostics keep the miss.

## Merging

1. **Same root cause → one finding**, `found_by` lists both reviewers. Merge on cause, not
   on location: two findings at the same `file:line` with different causes stay separate, and
   two findings in different files caused by the same defect become one.
2. **Keep the better write-up.** Take the clearest claim, the strongest evidence, and the
   most specific fix, regardless of which reviewer supplied each.
3. **Same symptom, incompatible explanations → verify which is right.** Do not merge them
   into a vague finding that is true of neither. If both are right, that is two findings.
4. **Orchestrator findings are allowed.** Verification frequently turns up something neither
   reviewer saw. Record it with `found_by: ["orchestrator"]` — it is a real signal about the
   process, and hiding it flatters the reviewers.

## Rejecting

Reject a finding when it is false, already established practice in the codebase (check 7),
purely stylistic, or unfalsifiable as written. Record `status: "rejected"` and a one-line
`reject_reason` — rejections drive the false-positive metric, which is the only defence
against a reviewer learning that volume pays.

Do not reject merely because a finding is hard to confirm. Convert it to `question` severity
with the specific thing the author must answer.

## Severity

Recalibrate from the reviewers' proposals using the definitions in the reviewer brief, which
carries the same corrections you apply here:

- **Reachability gates severity.** A defect on a path no realistic input reaches is at most
  `minor`, whatever its consequence would be.
- **Silence promotes.** A wrong answer that fails loudly is less severe than a wrong answer
  that returns success — silent incorrectness is the archetypal `blocking`.
- **Scope is not size.** Rate by what the defect does, not by how much code it touches.
- **Count is not severity.** Five `minor` findings do not make a `blocking`. Say so if the
  aggregate worries you.

Expect to revise *upward* more often than downward. Measured on #4907, both models
under-rated — Opus on five of eight findings, GPT on one — each proposing `minor` for defects
that silently corrupt customer-visible output. A run where you never raise a severity is more
likely an adjudicator deferring to its reviewers than two well-calibrated models.

Keep each reviewer's proposal in `proposed_severity` even when you override it; the
over/under column in diagnostics is how model calibration becomes visible.

## Verdict

| Verdict | Use when |
|---|---|
| `request_changes` | Any `blocking` finding survives adjudication. |
| `approve_with_conditions` | No `blocking`, but `major` findings the author should fix before merge. Posts as a comment review — GitHub has no such state, and an APPROVE with open conditions is a lie the merge button believes. |
| `approve` | Only `minor`, `question`, and `nit` findings. |
| `comment` | The review is informational, or a reviewer failed and coverage is too thin to carry a verdict. |

**Never approve over a `blocking` finding.** `pr_submit.sh --blocking N` enforces this
mechanically; do not route around it by reclassifying a finding to fit a desired verdict.

## The adversarial pass

Runs at effort `high` and above. Its job is to attack the findings, not the PR.

**What it sees:** the finding claims, the evidence quotes, and the repository.
**What it must never see:** the reviewers' reasoning, their summaries, their confidence
levels, or which model produced which finding. A persuasive write-up is precisely what the
adversary exists to be immune to.

**Build the sanitized file — never point the adversary at the adjudicated findings JSON.**
That file carries `found_by`, `proposed_severity`, and `cite_ok`, all of which are per-model
and would hand the adversary the identities this design depends on hiding. Strip them:

```bash
python3 - <<'PY'
import json
KEEP = {"id", "title", "severity", "file", "line", "claim", "evidence"}
src = json.load(open("findings.json"))
out = [{k: v for k, v in f.items() if k in KEEP} for f in src["findings"]]
json.dump({"findings": out}, open("/tmp/adversary_input.json", "w"), indent=2)
print(f"{len(out)} findings sanitized; fields kept: {sorted(KEEP)}")
PY
```

Pass `/tmp/adversary_input.json` as `[FINDINGS_JSON_PATH]`. Allow-list, not deny-list: a new
per-model field added to the schema later must not silently start leaking. Confirm the file
contains no `found_by` before launching — `grep -c found_by /tmp/adversary_input.json`
should print `0`.

At `max`, run two adversaries — one per reviewer's findings, each using the *other*
reviewer's model — so no model grades its own homework. Record both in
`run.models.adversary` (a list is allowed) so the diagnostics can tell them apart.

### Adversary prompt

````
You are auditing a list of proposed pull-request findings. You are not reviewing the PR.

Your job is to find every finding that is WRONG, overstated, or unfalsifiable. A finding
that survives you is one the author will act on, so be hostile to each one. You are not
being asked for balance.

REPO ROOT: [REPO_ROOT]
FINDINGS: [FINDINGS_JSON_PATH]

For each finding, independently:
1. Open the cited file at the cited line. Does it say what the finding claims?
2. Is the claimed failure actually reachable? Name a concrete input that triggers it. If
   you cannot, say so — an unreachable defect is not a blocking one.
3. Does the codebase already do this elsewhere? Grep two or three sibling implementations.
   Established practice is not a new risk.
4. Is the severity justified by the impact — in EITHER direction? Inflated by how well it
   is written, or under-rated because the failure is quiet? Apply the same three severity
   corrections the reviewers were given:
   - A failure that produces no operator-visible signal is worse than one that throws.
     "Worst case it falls back to English / returns empty / degrades gracefully" is an
     argument for `blocking`, not against it, when nothing reports that it happened.
   - Rate what a reachable input does, not how exotic the input looks.
   - A small blast radius is not a low severity if the thing inside it is wrong.
5. Is there a simpler explanation the finding overlooked — an existing guard, a caller that
   cannot pass that input, a test that already covers it?

Do not add new findings about the PR. Do not soften your verdicts to seem fair, and do not
downgrade reflexively to look rigorous — a downgrade is a claim you must support with the
same evidence as a rejection. Work read-only.

Return ONLY this JSON:

{
  "verdicts": [
    {
      "id": "F1",
      "verdict": "upheld|rejected|downgraded|upgraded",
      "suggested_severity": "blocking|major|minor|question|nit",
      "reason": "one or two sentences, citing what you read",
      "confidence": "high|medium|low"
    }
  ]
}
````

### Handling adversary verdicts

- **`upheld`** → keep as adjudicated.
- **`rejected`** → re-verify yourself before acting. If the adversary is right, set
  `status: "rejected"` with its reason. If it is wrong, keep the finding and set
  `status: "disputed"` with both positions; disputed findings ship in the review with the
  disagreement stated, because a live dispute is information the author wants.
- **`downgraded`** → a downgrade is a claim, not a correction. Re-read the cited line
  yourself and apply it only if your own read supports it. Reject the downgrade outright if
  its sole argument is that the failure degrades gracefully — see the severity rules above.
- **`upgraded`** → apply it if your re-read supports it. Reviewers under-rate more often
  than they over-rate, so treat an upgrade as the likelier correction of the two.

**Watch for the ratchet.** The adversary is rewarded for finding fault, and the only fault
it can find in a finding is that it is too strong. Measured on #4907 at `high`: 6
downgraded, 1 upheld, 1 rejected — against reviewers already measured as under-rating
severity. If nearly every verdict is a downgrade, that is a property of the adversary's
incentive, not of the findings. Spot-check two downgrades against the code before applying
any of them.

The adversary is not the final word. It is a second opinion with a strong prior toward
rejection, and that prior is itself a bias — which is why its rejections and its downgrades
both get re-verified rather than applied.

**Its value is concentrated in the arguments you cannot make from the diff alone.** The
three that landed on #4907: the cited file was *untouched by this PR* and its own docstring
declares it best-effort (check 7, from the repo not the diff); the `AGENTS.md` already
records the limitation as an accepted follow-up, so the finding was not an oversight; and a
memory estimate double-counted because map keys are references, not copies. Verdicts of
that shape are worth applying. Verdicts of the shape "impact is bounded / handled
gracefully / the input looks unlikely" are the ratchet talking.

### `xhigh` and above: attack the cleared list

Feed the reviewers' `cleared` claims to the adversary as well, asking which were dismissed on
insufficient evidence. This is where check 4 pays: on #4907 the URL-masking risk was *cleared*
by one reviewer on a correct but irrelevant analysis. An overturned `cleared` claim becomes a
new finding with `found_by: ["orchestrator"]`.
