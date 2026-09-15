# Output format

Three artifacts, different audiences:

- **Inline comments** — for the author, anchored on the code they must change. This is where
  findings live by default.
- **The summary body** — for the author. Verdict, the overall read, and only the findings
  that could not be anchored to a line in the diff.
- **The diagnostics report** — for the reviewer. Stays local; see `diagnostics.md`. It must
  be pasted into the chat, not merely generated (see SKILL.md step 6).

Never mix them. Model names, agreement rates, and adversary verdicts are process telemetry
and do not belong in a PR comment. The review is posted under a human's name and reads as
that human's judgement; the fact that two models drafted it is not information the author
needs in order to fix the code. Include a methodology note only if the user asks for one.

## Inline versus summary

A wall of findings in one comment makes the author map every one back onto the code
themselves. Anchor each finding where the fix goes.

| Goes inline | Stays in the summary |
|---|---|
| Any finding with a file and a line inside the diff | Findings about a file the PR does not touch (missing registration, a caller elsewhere) |
| A concrete defect on a changed line | Architectural or cross-cutting concerns with no single home |
| A `suggestion` block the author can commit | The verdict, the overall read, and what you verified |
| Disputed findings — state both positions in the comment | Anything `pr_inline.py` reports as demoted |

`pr_inline.py` decides anchorability mechanically and prints what it demoted. **Copy the
demoted findings into the summary body**, otherwise they are dropped from the review
entirely — the one silent failure in this path.

Keep each inline comment short: the defect, the impact, the fix. Severity is already in the
prefix, so do not restate it. Use a ` ```suggestion ` block whenever the fix is a literal
line edit — the author can commit it without leaving the diff. Set `suggestion` on the
finding and `pr_inline.py` emits the block.

The summary body should then read as a short cover note, not a duplicate of the inline
comments. Reference them by count ("3 blocking, all inline"), not by repeating them.

## Review body template

```markdown
**<Verdict line>** — <one sentence on why>.

<Two or three sentences: what the change does, and the overall read. Give the author
credit where it is earned, specifically and briefly. No padding.>

---

## Blocking

### 1. <Specific one-line title>

`path/to/file.py:123`

<What is wrong. State the defect, not the code's appearance.>

```python
<the smallest quote that proves it>
```

**Impact:** <what breaks, for whom, when.>

**Fix:** <the smallest change that resolves it.>

---

## Non-blocking

### 4. <title>  *(major)*

`path/to/file.py:189`

<claim, evidence, fix — same shape, shorter.>

---

## Questions

- **<question>** — `path/to/file.py:88`. <Why it cannot be resolved from this repo, and
  what answer would close it.>

---

## Nits

- `path/to/file.py:129` — <one line each.>

---

## Checked and cleared

<Risks examined and found fine. This is not padding: it tells the author what has been
verified so re-review can skip it, and it is the section that makes a short finding list
credible rather than lazy.>

- <claim> — <how it was verified.>
```

## Rules

1. **Number findings.** Authors reply by number; unnumbered findings get answered in prose
   and half of them get lost.
2. **Every finding carries a `file:line`.** Verified by the adjudicator, not copied from a
   reviewer.
3. **Quote sparingly.** The smallest fragment that proves the claim. A pasted function is a
   reading assignment, not evidence.
4. **State impact concretely.** "Could cause issues" is not a finding. "German-locale
   payloads reach the translator with raw URLs, which get translated into broken links" is.
5. **Propose the smallest fix.** Not a redesign. If the fix genuinely requires a redesign,
   say that explicitly and keep the finding about the defect.
6. **Order by severity, then by file.** Blocking first; the author reads top-down and
   budgets accordingly.
7. **Disputed findings ship with the dispute visible.** "Flagged, but it may be covered by
   X — please confirm" is honest and useful. Suppressing the uncertainty is not.
8. **Mark reduced coverage at the top.** If a reviewer failed or tests could not run, say so
   before the findings, not in a footnote.

## Worked example — #4907

The review that produced this skill, in structure:

- **Verdict:** `request_changes` — three blocking findings.
- **Blocking:** repair guard conflating systemic with per-claim failure
  (`localization.py:500`); locale-delivery failure re-queuing into the DLQ without backoff
  (`bp_event_consumer.py:119`); URL-masking regex missing ccTLDs and leaking `.de` URLs to
  the translator (`_shared/i18n.py:110`).
- **Non-blocking:** label-vocab cap able to evict `UNFAVORABLE`; map budget ignoring label
  entries; missing skip marker; empty-map success return; stale `5x` comment.
- **Questions:** does api-service already serve `?locale=`, or is this the first writer?
- **Checked and cleared:** no existing callers break; the 936-test claims suite passes on
  the branch; the one ruff `FURB110` hit also exists on `main`, so the PR did not introduce
  it.

Note the shape of the last bullet. "Pre-existing on `main`" is a verified negative, and
verifying it is what kept a false finding out of the review.
