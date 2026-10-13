---
name: pr-review
description: Rigorous pull-request review using two independent models (Claude Opus 5 and GPT-5.6 Sol) over a shared evidence pack, an adversarial false-positive pass, independent verification of every finding, and diagnostics showing which model found what. Posts findings as inline comments anchored on the code, validated against the diff before posting. Supports effort and verbosity parameters. Use whenever the user asks to review a PR, review a pull request, look at a PR by number, check a diff or branch before merge, do a second-opinion or dual-model review, or invokes /pr-review. Works on github.com and GitHub Enterprise.
---

# PR review

Two models review the same evidence pack independently, an adversary attacks the resulting
findings, and every surviving finding is verified at its cited line before anything is
posted. Diagnostics report which model earned which finding.

## Why it is built this way

Two independent reviews of `mystique#4907` — a PR with an unusually good description — found
almost disjoint sets of real bugs. One searched inward (line by line, into helpers), one
searched outward (callers, failure modes, consumers). Each was confident and each was blind
where the other was strong. The cause was shared: **the author's excellent documentation set
both reviewers' agendas**, so both verified the advertised risks and skipped the boring
preconditions underneath.

Three consequences shape this skill:

1. **Two models, identical briefs.** Diversity comes from the models, not from splitting the
   work. Splitting destroys the agreement signal and leaves each reviewer half-informed.
2. **A checklist that forces a different search order.** "Be thorough" produces a deeper
   version of the same blind spot. `references/anti-bias-checks.md` redirects the method.
3. **Nothing is trusted, including the reviewers.** Agreement between models is correlated
   guessing until someone opens the file.

## Parameters

| Parameter | Values | Default | Notes |
|---|---|---|---|
| PR | number, URL, or omitted | PR for the current branch | Omitted and no PR found → review the branch diff against its base. |
| `effort` | `low` `medium` `high` `xhigh` `max` | `high` | See the ladder below. |
| `verbosity` | `quiet` `normal` `verbose` `debug` | `verbose` | Controls diagnostics only, never the posted review. |
| posting | — | never automatic | Always draft, show the user, and get explicit confirmation. |

### Effort ladder

| Effort | `reasoning_effort` | Adversary | Also |
|---|---|---|---|
| `low` | `medium` | none | Skip tests; diff and callers only. |
| `medium` | `high` | none | Run targeted tests for changed modules. |
| **`high`** | `xhigh` | 1 | Full anti-bias checklist, targeted tests. **Default.** |
| `xhigh` | `xhigh` | 1 + re-attack the `cleared` lists | Also diff behaviour against the base branch where cheap. |
| `max` | `max` | 2, cross-graded (each model audits the other's findings) | Everything above; use for release-critical or security-adjacent changes. |

**Every effort level runs both reviewers.** `effort` sets reasoning depth, not reviewer
count — dropping to one model removes the agreement signal, which is the point of the skill.
The single-reviewer case is a *size* decision, not an effort one, and `references/scoping.md`
is the only thing that authorises it (trivial single-file changes). If only one model is
available, say so in the output and treat the agreement metrics as absent, not as zero.

Both reviewer slots are `claude-opus-5` and `gpt-5.6-sol` by default. If one is unavailable,
substitute any strong model from a *different* family and record the actual IDs in
`run.models`; the diagnostics label themselves from that. Running the same model twice is a
last resort that destroys the independence the design rests on — label the run as
single-family if you do it.

## Workflow

### 0. Route and right-size

If the user asks specifically for a security review or for exploitable vulnerabilities,
invoke the `security-review` agent first and do not review directly. Return here only for
the general-correctness pass.

Then check whether the default workflow fits. A trivial change, an oversized PR, or a
re-review round after the author pushed fixes each need different handling — read
`references/scoping.md`. State the chosen approach and why in one line before starting.

### 1. Build the evidence pack

```bash
scripts/pr_fetch.sh [pr-number] [--checkout]   # prints the pack directory
```

Derives host and repo from the git remote — the ambient `GH_HOST` is commonly `github.com`
and silently wrong on Enterprise remotes. Writes `meta.json`, `diff.patch`, `files.txt`,
`diffstat.txt`, `commits.txt`, `context.env`, and fetches the PR head to `pr-review/<n>`.

**Confirm `HEAD_MATCHES_PR=exact` in `context.env` before launching reviewers.** Reviewers
read whole files from the working tree; a tree on another commit produces a confident review
of code that is not in the PR, with no visible symptom. Use `--checkout` to switch (it
refuses on a dirty tree) or check out the ref yourself.

### 2. Ground the review before launching reviewers

Spend real time here; it is what keeps the reviewers from inventing conventions.

- Read the PR description and existing comments from `meta.json`.
- Read the nearest `AGENTS.md` / `CLAUDE.md` / `CONTRIBUTING.md` covering the changed paths.
- Establish a baseline: run the test suite for the changed modules, and the linter. **Then
  check whether any failure also exists on the base branch** — a pre-existing failure
  reported as a finding is the most embarrassing false positive available.
- Assemble the `[REPO_CONVENTIONS]` block for the reviewer brief from what you verified.
  Invent nothing.

### 3. Launch both reviewers in parallel

Read `references/reviewer-brief.md` and issue **both `task` calls in the same response** so
they run concurrently. `agent_type: general-purpose`, identical prompts, different `model`
and matching `reasoning_effort` from the ladder. Instruct read-only work in the prompt.

### 4. Adjudicate

Read `references/adjudication.md`. In short: independently verify every finding at its cited
line, merge on root cause rather than location, reject false positives with a recorded
reason, recalibrate severity, and record your own findings as `found_by: ["orchestrator"]`
when verification turns up something neither reviewer saw.

### 5. Adversarial pass — effort `high` and above

Launch the adversary with the finding *claims* and the repository, never the reviewers'
reasoning or model identities, so a persuasive write-up cannot buy a finding its survival.
Re-verify every rejection **and every downgrade** yourself before applying it; unresolved
disagreements ship as `disputed` with both positions stated.

The adversary can only find one fault in a finding — that it is too strong — so its verdicts
skew toward softening. Measured on #4907: 6 downgraded, 1 upheld, 1 rejected. The report
prints a ratchet warning when that skew appears; heed it.

### 6. Diagnostics

Write the adjudicated findings JSON (schema in `references/diagnostics.md`), then:

```bash
python3 scripts/review_report.py findings.json --verbosity verbose
```

**Paste the report into the chat as your own message — do not just run the command.**
Tool output is not reliably shown to the user, so a report that only exists in a tool
result has not been delivered. Reproduce it verbatim in your reply, above the review body.
At `verbosity: quiet` still show the scoreboard and the unique-finds section; those are the
whole reason a second model ran. If you skip this, the user sees a review with no evidence
that any of the machinery behind it did anything.

Prints the report and appends one record to `~/.local/state/copilot-skills/pr-review/ledger.jsonl`. Use
`--no-ledger` for re-runs on the same PR, `--summary` for cross-run trends, and
`--prior owner/repo#N` to recover the previously reviewed SHA when re-reviewing. Set
`pr.head_oid` in the findings JSON so that lookup works next round.

### 7. Draft, confirm, post

Findings go **inline on the code by default**; the summary body carries only the verdict,
the narrative, and findings that cannot be anchored. See `references/output-format.md` for
the split. Generate and validate the inline comments first:

```bash
python3 scripts/pr_inline.py findings.json --diff "$PACK/diff.patch" --out comments.json
```

Every comment is checked against the diff, because GitHub rejects the **entire** review with
a 422 if one line is off-diff. Findings it cannot anchor — a file the PR does not touch, a
line outside every hunk — are reported as *demoted*; put those in the summary body yourself,
or they are silently lost.

**Show the user the full summary body AND the inline comment list, then get explicit
confirmation before posting** — always, including in autopilot. Prove the positions first:

```bash
scripts/pr_submit.sh <pr> <verdict> body.md --inline comments.json --validate
```

`--validate` creates a PENDING review (author-visible only), confirms GitHub accepts every
line, and deletes it. Do this before asking for confirmation, so a 422 surfaces while it is
still cheap to fix.

```bash
scripts/pr_submit.sh <pr> <verdict> body.md --blocking <n> --inline comments.json [--dry-run]
```

Verdicts: `request_changes`, `approve_with_conditions` (posts as a comment review — GitHub
has no such state), `approve`, `comment`. The script refuses to approve when `--blocking` is
non-zero, falls back to a comment review on your own PR, and reads the review back to
confirm it landed. It prefers the active `gh` keyring account over ambient `GH_TOKEN` /
`GITHUB_TOKEN` overrides; pass `--user <login>` to require a specific keyring identity. If
the inline post fails it still posts the summary and says so loudly, rather than losing the
review.

## Hard rules

- **Never approve over a blocking finding**, and never reclassify a finding to reach a
  desired verdict.
- **Never post without explicit user confirmation.**
- **Never pass a finding through unverified.** Open the file. Read the line.
- **Reviewers are read-only.** No edits, no commits, no PR writes from subagents.
- **Check the base branch before blaming the PR** for a test or lint failure.
- **Confirm the working tree is at the PR head** (`HEAD_MATCHES_PR=exact`) before launching
  reviewers. Reviewing the wrong commit fails silently and looks exactly like success.
  `contains` means the tree holds the PR head plus other commits (a local merge): whole-file
  reads include base-side changes, so attribute findings to the diff, not the file. `false`
  means stop and re-run with `--checkout`.
- **Keep diagnostics out of the PR.** Model names and agreement rates are process telemetry;
  the review is posted under a human's name.
- **Paste the diagnostics report into the chat.** Running `review_report.py` is not the same
  as showing it; tool output may never reach the user. If it is not in your reply, it was
  not delivered.
- **Anchor findings inline, and carry the demoted ones into the summary.** A finding that
  `pr_inline.py` could not anchor and that you did not copy into the body is silently
  dropped from the review.
- **State reduced coverage at the top of the review** when a reviewer failed or tests could
  not run. Never hide it in a footnote.

## References

| File | Read when |
|---|---|
| `references/anti-bias-checks.md` | Always — both reviewers and the adjudicator. The eight checks with the worked example behind each. |
| `references/scoping.md` | Step 0, when the PR is trivial, oversized, or a re-review round. Right-sizing, triage, and round-over-round handling. |
| `references/reviewer-brief.md` | Before step 3. Verbatim subagent prompt and the reviewer JSON contract. |
| `references/adjudication.md` | Before steps 4–5. Verification, merging, severity, verdicts, and the adversary prompt. |
| `references/output-format.md` | Before step 7. Inline-versus-summary split, review body template, and the #4907 worked example. |
| `references/diagnostics.md` | Before step 6. Findings JSON schema, metric definitions, ledger usage. |
