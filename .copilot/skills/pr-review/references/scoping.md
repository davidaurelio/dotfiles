# Scoping

The default workflow assumes one reviewable PR and a first look at it. Three situations
break that assumption. Handle them explicitly rather than running the full machine and
hoping.

## Right-sizing the run

The two-model pipeline costs roughly ten to twenty minutes of wall clock. Spending that on a
three-line dependency bump is not rigour, it is theatre — and it trains the user to skim the
output, which is worse than not running it.

| Change | Approach |
|---|---|
| Version bumps, generated files, pure renames, formatting | Review directly. Confirm the change is what it claims and that nothing non-generated rode along. No subagents. |
| Single-file, under ~100 lines, no new public surface | `effort: low`, one reviewer, checks 1–4. This is the *only* case that drops to a single reviewer; every other row runs both. |
| Normal feature or fix | The default workflow at `effort: high`. |
| Touches auth, money, data deletion, migrations, or a public contract | `effort: xhigh` minimum; consider `max`. Route explicit security requests to `security-review` first. |

State the choice and the reason in one line before starting. Silently downgrading a review
the user expected to be thorough is the one failure they cannot see.

## Oversized PRs

Past roughly 3,000 changed lines or 50 files, a single reviewer's attention degrades without
any visible symptom: it reads the first files closely, skims the rest, and returns a
confident review of the beginning of the diff. The file-coverage section in diagnostics is
the tell — a reviewer citing six of sixty changed files did not review the PR.

**Do not split the brief between reviewers.** Both must still see the whole change, or the
agreement signal becomes meaningless and neither can do the outward pass. Instead:

1. **Triage first.** Classify each changed file as `core` (behaviour the PR exists to
   change), `mechanical` (renames, moves, generated output, test fixtures), or
   `incidental`. Verify the mechanical claim yourself with `git diff --stat` and a spot
   check — "just a rename" is a claim, and check 1 applies.
2. **Point the reviewers at `core`**, and say so in the brief: name the mechanical files and
   state that they have been verified as mechanical, so the reviewers do not spend attention
   re-deriving that.
3. **Run the outward pass on the full change**, not just `core`. Callers and consumers are
   exactly where a "mechanical" rename stops being mechanical.
4. **Say what was scoped out** at the top of the posted review. A review that silently
   covered 40% of a PR is worse than no review, because it confers false confidence.

If `core` alone is still oversized, the honest move is to tell the author the PR is too
large to review responsibly and ask for a split. That is a legitimate review outcome.

## Re-review rounds

After the author pushes fixes, the question is narrower: were the findings addressed, and did
the fixes break anything?

```bash
python3 scripts/review_report.py --prior 'owner/repo#123'
```

Prints the previously reviewed head SHA, verdict, and severity counts. Then:

1. **Diff the delta**, not the whole PR: `git diff <prior_head>..HEAD`. A full re-review
   re-litigates settled findings and buries the new ones.
2. **Carry every unresolved finding forward by its original number.** Authors track by
   number across rounds; renumbering destroys the thread. Mark each `fixed`, `partially
   fixed`, `not addressed`, or `disputed by author`.
3. **Verify fixes at the line, not from the reply.** "Fixed in abc123" is a claim. Open the
   file. A fix that moves the defect rather than removing it is common and easy to miss when
   reading a diff of a diff.
4. **Run the checks on the fix itself.** Fixes are written under time pressure and get less
   scrutiny than the original code — a new cap, a new early return, or a broadened regex in a
   fix deserves checks 2 and 3 as much as anything in round one.
5. **Re-run the adversary only on new or changed findings.** Findings already upheld do not
   need re-attacking.
6. **Append the round to the ledger** so `--prior` reports round 2 next time. The diagnostics
   agreement and unique-find columns are per-round and remain meaningful.

A re-review that finds everything addressed should say exactly that and flip the verdict.
Withholding approval to seem rigorous is its own failure mode.
