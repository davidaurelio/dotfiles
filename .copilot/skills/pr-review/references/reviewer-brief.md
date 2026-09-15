# Reviewer brief

Both reviewers get the **same** brief. Diversity comes from the models, not from splitting
the work — splitting destroys the agreement signal and leaves each reviewer with half a
picture. The checklist raises each reviewer's floor; the model difference supplies the
variance.

## Launching

Two `task` calls with `agent_type: general-purpose`, issued **in the same response** so they
run in parallel. Set `model` and `reasoning_effort` per the effort ladder in SKILL.md.

- Reviewer **a**: `model: claude-opus-5`
- Reviewer **b**: `model: gpt-5.6-sol`

Substitute the bracketed values. Do not paraphrase the rest — the ordering constraints and
the output contract are load-bearing.

## Prompt template

````
You are reviewing a pull request. Work read-only: read, grep, and run tests, but make no
edits, no commits, and no writes to the repository or the PR.

REPO ROOT: [REPO_ROOT]
EVIDENCE PACK: [PACK_DIR]
  meta.json    - PR metadata, description, existing review comments
  diff.patch   - full diff against the merge base
  files.txt    - changed file paths
  diffstat.txt - per-file line counts
  commits.txt  - commit log
  context.env  - repo, PR number, base ref, merge base

The working tree is already checked out at the PR head. Read files directly from
[REPO_ROOT] — the patch is for orientation, the files are the truth.

METHOD — follow this order. It is deliberate.

1. Read the diff once to learn what the change does. Do not form conclusions yet.

2. Read [SKILL_DIR]/references/anti-bias-checks.md in full and work all eight checks.
   These exist because a review of this exact kind missed real bugs. Each check must be
   exercised and reported in `checks_run` with one line of evidence, even when it yields
   nothing.

3. Run BOTH passes and keep them separate:
   - INWARD: the changed lines and every helper they call, including helpers the PR does
     not modify. Open the implementations. Do the arithmetic on every cap and slice.
   - OUTWARD: callers of changed functions, failure and exception paths, consumers of new
     outputs, constants imported from elsewhere, tests that encode the old behaviour.
   A review strong on one axis and empty on the other is the known failure mode. If one
   pass produces nothing, say so explicitly and explain what you searched.

4. Treat the PR description, comments, docstrings, and any AGENTS.md/README changes as
   claims to verify, not as context to trust. A well-written description is a reason for
   more suspicion, not less: it sets your agenda, and the author's agenda is where both
   prior reviews of this kind went blind.

5. Before writing each finding, re-open the cited file at the cited line and confirm it
   says what your finding says it says. Wrong cites discredit correct findings.

6. Before flagging a pattern as risky, grep for two or three sibling implementations. If
   the codebase already does it elsewhere, either say so and drop the finding, or raise it
   as the larger systemic finding it actually is.

[REPO_CONVENTIONS]

SEVERITY — assign honestly; the adjudicator recalibrates but starts from your call.
  blocking - data loss, security, silent incorrectness, breaks a documented contract,
             or an operational failure mode that will page someone
  major    - wrong in a realistic case, or a real maintenance trap
  minor    - narrow correctness or clarity issue worth fixing
  question - you cannot resolve it from this repo and the author must answer
  nit      - cosmetic; costs nothing to fix and nothing to ignore

Apply these three corrections. Reviewers reliably under-rate without them:
  - SILENCE PROMOTES. A wrong answer that fails loudly is less severe than a wrong answer
    that returns success. Silent incorrectness is the archetypal `blocking`, even when the
    triggering input looks unusual.
  - REACHABILITY GATES. A defect on a path no realistic input reaches is at most `minor`,
    whatever its consequence would be. Name the triggering input or lower the severity.
  - SCOPE IS NOT SIZE. A one-line defect that corrupts customer-visible output outranks a
    large refactor that is merely awkward. Rate by what it does, not by how much code it
    touches or how small the fix is.

Do not pad. No praise, no style preferences the linter does not enforce, no restating the
description. A finding you are not willing to defend at its cited line does not belong in
the list.

OUTPUT — return ONLY this JSON object, no prose before or after:

{
  "reviewer": "[A_OR_B]",
  "summary": "two sentences: what the change does, and your overall read",
  "findings": [
    {
      "title": "one line, specific",
      "severity": "blocking|major|minor|question|nit",
      "file": "path/relative/to/repo/root.py",
      "line": 123,
      "axis": "inward|outward",
      "check_id": 1,
      "claim": "what is wrong, in one or two sentences",
      "evidence": "the exact lines or greps that prove it, quoted",
      "impact": "what breaks, for whom, and when",
      "fix": "the smallest change that resolves it",
      "confidence": "high|medium|low"
    }
  ],
  "cleared": [
    {"claim": "a risk you checked and found to be fine", "how_verified": "what you read or ran"}
  ],
  "checks_run": [
    {"check_id": 1, "evidence": "one line showing the check was actually applied"}
  ],
  "files_cited": ["every repo file you read closely"],
  "unanswered_questions": ["anything unresolvable from this repo alone"]
}

`check_id` is the anti-bias check that surfaced the finding, or null if none did.
`cleared` is not optional: risks you ruled out are evidence of coverage and the
adjudicator re-tests them.
````

## `[REPO_CONVENTIONS]` block

Fill this only with conventions verified from the repo — a stale convention is worse than
none. Sources worth checking: the nearest `AGENTS.md` / `CLAUDE.md`, `CONTRIBUTING.md`, and
lint config. Typical content: how to run the tests, hard invariants the repo enforces, and
a pointer to any subtree `AGENTS.md` covering the changed paths. If nothing verifiable is
available, write `No repo-specific conventions were verified; apply general engineering
judgement.` rather than inventing any.

## Failure handling

- **Reviewer returns prose instead of JSON:** parse what you can, record the malformed
  return in diagnostics, and do not silently drop the findings.
- **One reviewer fails outright:** continue with one reviewer, state this prominently at the
  top of the posted review, and record it in diagnostics. A single-model review is still
  worth posting; a review that hides it is not.
- **Both agree on something false:** this is exactly what the adversarial pass is for.
  Agreement is not verification.
