# Anti-bias checks

Eight checks, each earned from a real miss on `experience-platform/mystique#4907`. Both
reviewers read this file; the adjudicator uses it to tag which check earned each finding.

## The failure this exists to prevent

PR #4907 shipped with an unusually good description, a rewritten `AGENTS.md`, and inline
comments explaining every design decision. Two independent reviews of it missed different
things, and the reason was the same in both cases: **good documentation sets the reviewer's
agenda.** The author had already named the interesting risks, so both reviewers spent their
budget verifying the advertised risks and skipped the boring preconditions underneath them.

The fix is not "be more thorough." Thoroughness applied to the author's agenda produces a
deeper version of the same blind spot. The fix is to force a *different* search order —
which is what these checks do. Work them explicitly; do not read them and nod.

This is measurable, not theoretical. Re-running #4907 with these checks in the brief, the
model that had originally missed the systemic-guard, ccTLD-masking, and label-cap defects
found all three — at a *lower* reasoning effort than its original miss — and independently
declined the known false positive under check 7. The checks do the work, not the budget.

## Coverage requirement

Every check must be *exercised*, not merely considered. Findings are optional; the search is
not. When a check produces nothing, say so in `checks_run` with one line of evidence that it
was actually applied ("no caps or slices in the diff" is valid; silence is not).

---

## 1. Comments and docs are assertions to verify, not context to trust

A comment is the author's claim about the code. Read it as a testable proposition and test
it. The more confident and well-written the comment, the more it substitutes for your own
reading — that is exactly when it is worth checking.

**#4907, missed:** a repair-guard comment described the guard as distinguishing systemic
failure from per-claim failure. The code has no access to information that could support
that distinction (`localization.py:500`). The comment was so specific that both reviewers
read it as a spec and moved on.

**#4907, missed:** a comment claimed a "5x" payload expansion. The actual factor, from the
same file's own constants, was 2.5x (`claims_localization_producer.py:129`).

**How to apply:** for each comment or docstring touching changed logic, write down the claim,
then find the line that makes it true. If you cannot, that is a finding — either the comment
is stale or the code is wrong, and which one it is matters to the author.

## 2. Do the arithmetic on every cap, limit, slice, sort, and budget

Any expression that drops data is a correctness question with a numeric answer. Compute it.
Do not reason about it qualitatively.

**#4907, missed:** `sorted(label_vocab)[:200]` — alphabetical, so `UNFAVORABLE` sorts last
and gets evicted first once the vocab exceeds the cap. The cap looked generous, which is why
nobody did the sort in their head (`claims_localization_producer.py:189`).

**#4907, missed:** a translation-map size budget counted claim entries but not label entries,
so the effective budget was smaller than the constant advertised
(`claims_localization_producer.py:221`).

**How to apply:** grep the diff for `[:`, `head`, `limit`, `max_`, `MAX_`, `truncate`,
`sorted(`, `[:n]`, `islice`, `batch`, `chunk`. For each: what is the ordering, what falls off
the end, what is the worst realistic input, and does anything important sort last?

## 3. Open every helper; read the implementation, not the name

A helper's name is the author's summary of it. Call sites inherit whatever the implementation
actually does, including its edge cases. This applies hardest to helpers the PR does not
change — unchanged code reached by a new caller is new behaviour.

**#4907, missed:** `_URL_PATTERN` in `app/opportunities/_shared/i18n.py:110` is a regex with a
TLD allowlist. It does not match ccTLDs, so URL masking silently failed on `.de` domains and
leaked raw URLs to the translator — in the exact locale the feature exists to serve.

**How to apply:** list every function the diff calls that it does not define. Open each one.
Note the input classes it silently does not handle. A helper that is `_private` and lives in a
`_shared` package deserves more suspicion, not less — it was written for a different caller.

## 4. Check the boring precondition, not just the interesting property

Reviewers verify the property that is intellectually interesting and assume the dull one that
guards it. Ordering matters: verify the precondition first, because if it fails the
interesting property is irrelevant.

**#4907, missed:** one reviewer carefully verified that URL masking was *isolated per string*
(the interesting concurrency-ish property) and never checked that the pattern *matched a `.de`
domain at all* (the dull precondition). The isolation analysis was correct and worthless.

**How to apply:** for each behaviour you verify, name its precondition in one sentence — "this
matters only if X". Then verify X. If you catch yourself analysing a sophisticated property,
stop and ask what has to be true for that property to be reached.

## 5. Outward pass: callers, failure modes, consumers, and constants defined elsewhere

After reading the diff inward, invert the direction. Who calls this? What happens when it
raises? What reads what it writes? Where do its constants come from? Findings on this axis are
invisible from inside the changed file, which is why single-file-deep review misses them.

**#4907, found only on this axis:** a locale-delivery failure re-queues into the DLQ path with
no backoff — the relevant constant lives in `app/services/claims/bp_event_consumer.py:119`,
a file the diff does not touch.

**How to apply:** for each changed public function, run four searches — callers, raise/except
paths around the call, readers of its outputs, and the definitions of any constants it uses
that are imported rather than local. Budget real time for this; it is the axis that loses to
time pressure.

## 6. "No existing callers break" is not "someone reads this output"

Backwards compatibility and usefulness are different questions. A PR that writes a new
artifact nothing consumes is not broken, but it is also not finished, and that gap is worth
surfacing before merge rather than a quarter later.

**#4907:** the change writes `data.<locale>.json.gz`. Nothing in the repo reads it. That may
be correct — the consumer can live in another service — but it is a question the author must
answer, not an assumption the reviewer may make.

**How to apply:** for each new output, key, field, file, event, or metric, grep for a reader.
If the reader is in another repo or service, say so explicitly and ask whether it is deployed
yet. Ordering between the writer and the reader shipping is a real release risk.

## 7. Before calling something a risk, check whether it is established practice

The cost of a false positive is not zero: it burns author trust and buries the real findings.
Before flagging a pattern as dangerous, check whether the codebase already does it in a
comparable place. If it does, either the pattern is fine or you have found a much larger
finding — and you should say which.

**#4907, false positive:** one review flagged a brand-scoped producer for reading
`scope_meta.site`. `CategoryGenerationProducer` is also brand-scoped and already depends on
`scope_meta.site.base_url`. Established practice, not a new risk. The adversarial pass killed
this finding.

**How to apply:** grep for two or three sibling implementations of the same pattern before
writing the finding. Then state the result in the finding itself — "no other producer does
this" is evidence; its absence is a guess.

## 8. Verify your own cites

A wrong `file:line` destroys the credibility of a correct finding, and a confident claim about
*another reviewer's* work is held to the same standard. Re-open every location before it ships.

**#4907, self-inflicted:** the adjudicating reviewer asserted that the other review's line
numbers were transposed. They were not. The claim was wrong, and the only reason it did not
reach the author is that it got checked before posting.

**How to apply:** before the review is posted, re-read every cited line and confirm it says
what the finding says it says. This is cheap, mechanical, and catches a class of error that
is disproportionately damaging. The adjudicator records the result per finding as `cite_ok`.

---

## Quick grep starters

```bash
# check 2 — data-dropping expressions
rg -n '\[:\d+\]|\[:[a-z_]+\]|\bsorted\(|\bislice\b|MAX_|_LIMIT|truncate|\bhead\b' diff.patch

# check 3 — imports the diff relies on but does not define
rg -n '^\+from |^\+import ' diff.patch

# check 5/6 — callers and readers (run in the repo, not the patch)
rg -n 'new_function_name' --type py
rg -n 'data\.<locale>\.json|new_fact_key|NEW_METRIC' -g '!*.lock'
```
