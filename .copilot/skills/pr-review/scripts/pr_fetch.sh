#!/usr/bin/env bash
# Build a PR evidence pack: one fetch, shared by every reviewer.
#
# Resolves the gh host + repo FROM THE GIT REMOTE rather than trusting $GH_HOST,
# which is the common failure on enterprise remotes (a github.com GH_HOST against a
# git.corp.adobe.com remote makes every gh call fail with a confusing remote error).
#
# Usage:
#   pr_fetch.sh <pr-number|pr-url>  [--out <dir>] [--repo <owner/repo>] [--remote <name>]
#                                   [--checkout]
#   pr_fetch.sh                     # no arg -> PR for the current branch
#
# Reviewers read whole files from the working tree, so the tree MUST be at the PR
# head or they will review the wrong code. This script always verifies that and
# records HEAD_MATCHES_PR in context.env; --checkout switches to the PR head, and
# refuses on a dirty tree rather than risking the user's uncommitted work.
#
# Prints the pack directory to stdout (last line). Everything else goes to stderr.
set -euo pipefail

PR_ARG="" OUT_DIR="" REPO_OVERRIDE="" REMOTE="origin" DO_CHECKOUT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)    OUT_DIR="$2"; shift 2 ;;
    --repo)   REPO_OVERRIDE="$2"; shift 2 ;;
    --remote) REMOTE="$2"; shift 2 ;;
    --checkout) DO_CHECKOUT=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *)        PR_ARG="$1"; shift ;;
  esac
done

log() { printf '%s\n' "$*" >&2; }
die() { printf 'pr_fetch: %s\n' "$*" >&2; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

# --- resolve host + repo -----------------------------------------------------
# A PR URL is authoritative; otherwise derive from the remote. Supports
# git@host:owner/repo.git, https://host/owner/repo.git, and ssh://git@host/owner/repo.
if [[ "$PR_ARG" =~ ^https?://([^/]+)/(.+)/pull/([0-9]+) ]]; then
  HOST="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]}"; PR_NUM="${BASH_REMATCH[3]}"
else
  PR_NUM="$PR_ARG"
  REMOTE_URL="$(git remote get-url "$REMOTE" 2>/dev/null)" || die "no remote '$REMOTE'"
  HOST="$(printf '%s' "$REMOTE_URL" | sed -E 's#^[a-z]+://([^@]*@)?([^/]+)/.*#\2#; s#^([^@]*@)?([^:/]+):.*#\2#')"
  REPO="$(printf '%s' "$REMOTE_URL" | sed -E 's#^[a-z]+://([^@]*@)?[^/]+/##; s#^([^@]*@)?[^:]+:##; s#\.git$##')"
fi
[[ -n "$REPO_OVERRIDE" ]] && REPO="$REPO_OVERRIDE"
[[ -n "$HOST" && -n "$REPO" ]] || die "could not resolve host/repo (remote='${REMOTE_URL:-n/a}')"

# Scope GH_HOST to this script so a conflicting ambient value cannot break gh.
export GH_HOST="$HOST"
gh() { command gh "$@"; }

# No PR given -> the one for the current branch.
if [[ -z "$PR_NUM" ]]; then
  PR_NUM="$(gh pr view --repo "$REPO" --json number --jq .number 2>/dev/null)" \
    || die "no PR number given and no PR found for the current branch"
fi
[[ "$PR_NUM" =~ ^[0-9]+$ ]] || die "invalid PR reference: '$PR_ARG'"

log "pr_fetch: host=$HOST repo=$REPO pr=$PR_NUM"

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-review-${PR_NUM}-XXXXXX")"
fi
mkdir -p "$OUT_DIR"

# --- metadata ----------------------------------------------------------------
gh pr view "$PR_NUM" --repo "$REPO" \
  --json number,title,body,author,state,isDraft,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles,url,createdAt,updatedAt,labels,reviews,comments \
  > "$OUT_DIR/meta.json" || die "gh pr view failed for $REPO#$PR_NUM"

BASE_REF="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["baseRefName"])' "$OUT_DIR/meta.json")"

# --- diff --------------------------------------------------------------------
# gh pr diff is the source of truth for what the PR changes (it handles forks and
# out-of-date branches). The local fetch below is for reading full file context.
gh pr diff "$PR_NUM" --repo "$REPO" > "$OUT_DIR/diff.patch" || die "gh pr diff failed"
gh pr diff "$PR_NUM" --repo "$REPO" --name-only > "$OUT_DIR/files.txt" || true

# --- local refs so reviewers can read whole files, not just hunks -------------
LOCAL_REF="pr-review/$PR_NUM"
if git fetch -q "$REMOTE" "pull/$PR_NUM/head:$LOCAL_REF" --force 2>/dev/null; then
  git fetch -q "$REMOTE" "$BASE_REF" 2>/dev/null || true
  MERGE_BASE="$(git merge-base FETCH_HEAD "$LOCAL_REF" 2>/dev/null || echo "")"
  [[ -n "$MERGE_BASE" ]] && git --no-pager log --oneline "$MERGE_BASE".."$LOCAL_REF" > "$OUT_DIR/commits.txt" 2>/dev/null || true
  [[ -n "$MERGE_BASE" ]] && git --no-pager diff --stat "$MERGE_BASE" "$LOCAL_REF" > "$OUT_DIR/diffstat.txt" 2>/dev/null || true
else
  log "pr_fetch: WARNING could not fetch pull/$PR_NUM/head (reviewers limited to diff.patch)"
  LOCAL_REF=""; MERGE_BASE=""
fi

# --- working tree must be at the PR head -------------------------------------
# Reviewers read whole files from the tree. A tree on some other commit yields a
# review of code that is not in the PR, with no visible symptom.
HEAD_OID="$(git rev-parse HEAD 2>/dev/null || echo "")"
PR_OID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("headRefOid") or "")' "$OUT_DIR/meta.json")"
HEAD_MATCHES_PR=false

if [[ "$DO_CHECKOUT" == "1" && -n "$LOCAL_REF" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    die "--checkout refused: working tree has uncommitted changes. Commit, stash, or drop --checkout."
  fi
  git checkout -q "$LOCAL_REF" || die "could not check out $LOCAL_REF"
  HEAD_OID="$(git rev-parse HEAD)"
  log "pr_fetch: checked out $LOCAL_REF"
fi

if [[ -n "$PR_OID" && "$HEAD_OID" == "$PR_OID" ]]; then
  HEAD_MATCHES_PR=exact
elif [[ -n "$LOCAL_REF" ]] && git merge-base --is-ancestor "$LOCAL_REF" HEAD 2>/dev/null; then
  # Tree CONTAINS the PR head but is not equal to it (e.g. a local merge). File reads
  # return post-merge content, so anything the base side changed in the same files is
  # not what the PR author wrote. Usable, but not the equality the reviewers assume.
  HEAD_MATCHES_PR=contains
  log "pr_fetch: NOTE tree contains the PR head but is not equal to it (HEAD=${HEAD_OID:0:12} PR=${PR_OID:0:12})."
  log "pr_fetch:   Whole-file reads include base-side changes. Attribute findings to the diff, not the file."
else
  HEAD_MATCHES_PR=false
  log "pr_fetch: WARNING working tree is NOT at the PR head."
  log "pr_fetch:   HEAD=${HEAD_OID:0:12} PR head=${PR_OID:0:12}"
  log "pr_fetch:   Reviewers read whole files from the tree and would review the wrong code."
  log "pr_fetch:   Re-run with --checkout, or check out ${LOCAL_REF:-the PR head} yourself."
fi

# --- context the reviewers and the adjudicator both need ---------------------
cat > "$OUT_DIR/context.env" <<EOF
GH_HOST=$HOST
REPO=$REPO
PR_NUM=$PR_NUM
BASE_REF=$BASE_REF
LOCAL_REF=$LOCAL_REF
MERGE_BASE=$MERGE_BASE
PR_HEAD_OID=$PR_OID
HEAD_MATCHES_PR=$HEAD_MATCHES_PR
PACK_DIR=$OUT_DIR
REPO_ROOT=$(git rev-parse --show-toplevel)
EOF

{
  printf '# PR evidence pack\n\n'
  printf -- '- repo: %s (host %s)\n- pr: #%s\n- base: %s\n' "$REPO" "$HOST" "$PR_NUM" "$BASE_REF"
  [[ -n "$LOCAL_REF"   ]] && printf -- '- local ref: %s\n' "$LOCAL_REF"
  [[ -n "$MERGE_BASE"  ]] && printf -- '- merge-base: %s\n' "$MERGE_BASE"
  printf -- '- working tree at PR head: %s\n' "$HEAD_MATCHES_PR"
  printf -- '\nFiles: meta.json, diff.patch, files.txt, commits.txt, diffstat.txt, context.env\n'
} > "$OUT_DIR/README.md"

log "pr_fetch: pack ready ($(wc -l < "$OUT_DIR/files.txt" | tr -d ' ') files changed)"
printf '%s\n' "$OUT_DIR"
