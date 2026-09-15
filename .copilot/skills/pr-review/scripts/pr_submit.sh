#!/usr/bin/env bash
# Post an adjudicated review to a PR. Host is derived from the git remote, never
# from the ambient GH_HOST (which is commonly github.com and silently wrong on GHE).
#
# Usage:
#   pr_submit.sh <pr-number> <verdict> <body-file> [--blocking N] [--remote NAME] [--inline comments.json] [--validate] [--dry-run]
#
#   verdict: request_changes | approve_with_conditions | approve | comment
#
# approve_with_conditions posts as a plain comment review: GitHub has no such state,
# and an APPROVE with open conditions is a lie the merge button will believe.
set -euo pipefail

die() { echo "pr_submit: $*" >&2; exit 1; }

[[ $# -ge 3 ]] || die "usage: pr_submit.sh <pr-number> <verdict> <body-file> [--blocking N] [--remote NAME] [--inline comments.json] [--validate] [--dry-run]"
PR_NUM="$1"; VERDICT="$2"; BODY_FILE="$3"; shift 3

BLOCKING=0
DRY_RUN=0
VALIDATE=0
REMOTE="origin"
INLINE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --blocking) BLOCKING="${2:?--blocking needs a count}"; shift 2 ;;
    --remote)   REMOTE="${2:?--remote needs a name}"; shift 2 ;;
    --inline)   INLINE="${2:?--inline needs a comments.json}"; shift 2 ;;
    --validate) VALIDATE=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -s "$BODY_FILE" ]] || die "body file is missing or empty: $BODY_FILE"
[[ "$PR_NUM" =~ ^[0-9]+$ ]] || die "pr number must be numeric, got: $PR_NUM"
[[ "$BLOCKING" =~ ^[0-9]+$ ]] || die "--blocking must be numeric, got: $BLOCKING"

# Never approve over an open blocking finding. This is the one rule worth enforcing
# mechanically, because the failure is silent and lands in main.
if [[ "$BLOCKING" -gt 0 && "$VERDICT" == "approve" ]]; then
  die "refusing to APPROVE with $BLOCKING blocking finding(s); use request_changes or approve_with_conditions"
fi

REMOTE_URL="$(git remote get-url "$REMOTE" 2>/dev/null)" || die "not in a git repo with a '$REMOTE' remote"
# Must match pr_fetch.sh: the ([^@]*@)? group strips the user from ssh://git@host/owner/repo.
HOST="$(printf '%s' "$REMOTE_URL" | sed -E 's#^[a-z]+://([^@]*@)?([^/]+)/.*#\2#; s#^([^@]*@)?([^:/]+):.*#\2#')"
REPO="$(printf '%s' "$REMOTE_URL" | sed -E 's#^[a-z]+://([^@]*@)?[^/]+/##; s#^([^@]*@)?[^:]+:##; s#\.git$##')"
[[ -n "$HOST" && "$REPO" == */* ]] || die "could not derive host/repo from remote: $REMOTE_URL"
export GH_HOST="$HOST"

case "$VERDICT" in
  request_changes)         FLAG="--request-changes"; EVENT="REQUEST_CHANGES" ;;
  approve)                 FLAG="--approve";         EVENT="APPROVE" ;;
  approve_with_conditions) FLAG="--comment";         EVENT="COMMENT" ;;
  comment)                 FLAG="--comment";         EVENT="COMMENT" ;;
  *) die "verdict must be request_changes | approve_with_conditions | approve | comment" ;;
esac

N_INLINE=0
if [[ -n "$INLINE" ]]; then
  [[ -s "$INLINE" ]] || die "inline comments file is missing or empty: $INLINE"
  command -v jq >/dev/null || die "--inline needs jq"
  jq -e 'type == "array"' "$INLINE" >/dev/null 2>&1 || die "inline file must be a JSON array (see pr_inline.py)"
  N_INLINE="$(jq 'length' "$INLINE")"
  BAD="$(jq -r '[.[] | select((.path|type) != "string" or (.line|type) != "number")] | length' "$INLINE")"
  [[ "$BAD" == "0" ]] || die "$BAD inline comment(s) missing a string .path or numeric .line"
fi

# Prove GitHub accepts every inline position before anyone confirms a post. A review
# created without an `event` is PENDING: visible only to its author, and deleted here.
# GitHub validates line-in-diff at creation, so a 422 now is the 422 we would have hit.
if [[ "$VALIDATE" == "1" ]]; then
  [[ "$N_INLINE" -gt 0 ]] || { echo "pr_submit: --validate needs --inline; nothing to check"; exit 0; }
  VP="$(mktemp)"
  jq -n --arg body "pr_submit --validate (pending, auto-deleted)" --slurpfile c "$INLINE" \
    '{body: $body, comments: $c[0]}' > "$VP"
  if ! VOUT="$(gh api "repos/$REPO/pulls/$PR_NUM/reviews" --input "$VP" 2>&1)"; then
    rm -f "$VP"
    die "inline positions REJECTED by GitHub, nothing posted: $(head -c 400 <<<"$VOUT")"
  fi
  rm -f "$VP"
  VID="$(jq -r '.id' <<<"$VOUT")"
  if ! gh api -X DELETE "repos/$REPO/pulls/$PR_NUM/reviews/$VID" --silent 2>/dev/null; then
    die "validation review $VID could not be deleted — DELETE it manually before posting"
  fi
  echo "pr_submit: validated $N_INLINE inline position(s) against the API; pending review $VID deleted"
  exit 0
fi

echo "pr_submit: host=$HOST repo=$REPO pr=$PR_NUM verdict=$VERDICT inline=$N_INLINE"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "pr_submit: --dry-run, nothing posted. Body preview:"
  head -40 "$BODY_FILE"
  if [[ "$N_INLINE" -gt 0 ]]; then
    echo "pr_submit: inline comments that would be posted:"
    jq -r '.[] | "  \(.path):\(.line) [\(.side // "RIGHT")]"' "$INLINE"
  fi
  exit 0
fi

# Inline comments need the reviews REST endpoint; `gh pr review` cannot carry them.
# GitHub rejects the WHOLE review if any one comment is off-diff, so pr_inline.py must
# have validated every line against diff.patch before we get here.
if [[ "$N_INLINE" -gt 0 ]]; then
  PAYLOAD="$(mktemp)"; trap 'rm -f "$PAYLOAD"' EXIT
  jq -n --arg body "$(cat "$BODY_FILE")" --arg event "$EVENT" --slurpfile c "$INLINE" \
    '{body: $body, event: $event, comments: $c[0]}' > "$PAYLOAD"
  if OUT="$(gh api "repos/$REPO/pulls/$PR_NUM/reviews" --input "$PAYLOAD" 2>&1)"; then
    echo "pr_submit: posted review with $N_INLINE inline comment(s)"
  elif grep -qiE 'can not (approve|request changes)|your own pull request' <<<"$OUT"; then
    echo "pr_submit: $VERDICT rejected on own PR, falling back to a COMMENT review" >&2
    jq '.event = "COMMENT"' "$PAYLOAD" > "$PAYLOAD.c" && mv "$PAYLOAD.c" "$PAYLOAD"
    gh api "repos/$REPO/pulls/$PR_NUM/reviews" --input "$PAYLOAD" >/dev/null \
      || die "comment fallback also failed"
  else
    # A 422 here usually means a comment line is not in the diff. Do not silently drop
    # the review: the summary still has to land.
    echo "pr_submit: inline review failed, posting the summary without inline comments" >&2
    echo "pr_submit:   $OUT" >&2
    gh pr review "$PR_NUM" --repo "$REPO" --comment --body-file "$BODY_FILE" >/dev/null \
      || die "summary-only fallback also failed: $OUT"
    echo "pr_submit: WARNING inline comments were NOT posted; findings live only in the summary" >&2
  fi
elif ! OUT="$(gh pr review "$PR_NUM" --repo "$REPO" "$FLAG" --body-file "$BODY_FILE" 2>&1)"; then
  # gh refuses to approve or request changes on your own PR. Degrade to a comment
  # review rather than losing the whole write-up.
  if grep -qiE 'can not (approve|request changes)|your own pull request' <<<"$OUT"; then
    echo "pr_submit: $VERDICT rejected on own PR, falling back to a comment review" >&2
    gh pr review "$PR_NUM" --repo "$REPO" --comment --body-file "$BODY_FILE" >/dev/null \
      || die "comment fallback also failed"
  else
    die "gh pr review failed: $OUT"
  fi
fi

# Verify rather than trust: confirm the review actually landed and read back its state.
LOGIN="$(gh api user --jq .login 2>/dev/null || echo "")"
LATEST="$(gh pr view "$PR_NUM" --repo "$REPO" --json reviews \
  --jq "[.reviews[] | select(.author.login == \"${LOGIN}\")] | last | \"\(.state) \(.submittedAt)\"" 2>/dev/null || echo "")"
if [[ -z "$LATEST" || "$LATEST" == "null null" ]]; then
  die "posted, but could not read the review back — check the PR manually"
fi
echo "pr_submit: posted. latest review by $LOGIN: $LATEST"
if [[ "$N_INLINE" -gt 0 ]]; then
  LANDED="$(gh api "repos/$REPO/pulls/$PR_NUM/comments" --paginate \
    --jq "[.[] | select(.user.login == \"${LOGIN}\")] | length" 2>/dev/null || echo "?")"
  echo "pr_submit: inline comments by $LOGIN now on the PR: $LANDED (this run added $N_INLINE)"
  if [[ "$LANDED" == "0" ]]; then
    echo "pr_submit: WARNING expected $N_INLINE inline comment(s) but found none — check the PR" >&2
  fi
fi
echo "pr_submit: https://$HOST/$REPO/pull/$PR_NUM"
