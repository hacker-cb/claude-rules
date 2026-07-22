---
name: codex-review
description: >-
  Run a code review with Codex — OpenAI's coding agent — over the current
  branch, using its own non-interactive reviewer (`codex exec review`). Use when
  the user or a pipeline asks for a "codex review", or wants a second opinion on
  a change from an engine other than Claude. Review-only: returns Codex's
  findings verbatim and never fixes anything. Invoke deliberately, when asked —
  not as an auto-trigger on every change.
---

# Codex review

`codex exec review` is Codex's built-in reviewer, running non-interactively in a
read-only sandbox. It needs `codex` on `PATH` and a live `codex login`; nothing
else.

This skill is **review-only**. Never fix what it reports — return the findings
and let the caller decide.

## 1. Pick the base

Review against a base ref. `--base` diffs `merge-base(base, HEAD)` against the
**working tree**, so a single pass covers the branch's commits *and* uncommitted
edits to tracked files. First hit wins:

1. A base the caller named explicitly.
2. The base of the open PR for this branch:
   ```bash
   gh pr view --json baseRefName -q .baseRefName    # prefix the result with origin/
   ```
3. Where this repo's PRs actually land. A review usually runs *before* the PR
   exists, so step 2 comes back empty and the default branch is the wrong guess
   in any repo whose PRs target `dev`, `develop`, `release/*`… Look, don't
   assume:
   ```bash
   gh pr list --state merged --limit 10 --json baseRefName -q '.[].baseRefName' | sort | uniq -c
   ```
   If one non-default base dominates, use it and name it in the report.
4. The repo default branch — `git symbolic-ref --short refs/remotes/origin/HEAD`,
   else whichever of `origin/main`, `origin/master`, `main`, `master` exists.
5. `git rev-parse --abbrev-ref @{upstream}` — last resort. When the branch tracks
   its own remote counterpart, this narrows the review to unpushed commits only.

Being on the default branch is fine: the merge-base collapses to `HEAD`, and the
review becomes the working-tree diff.

If nothing resolves — no remote, no upstream — say so and swap `--base "$BASE"`
for `--uncommitted`, which reviews staged + unstaged + untracked instead.

## 2. Check for untracked files first

`--base` reviews `git diff`, and `git diff` never shows untracked files, so
brand-new files are silently invisible to the review:

```bash
git ls-files --others --exclude-standard
```

If that lists anything belonging to the change, say so up front and offer
`git add -N <file>`, which makes them visible without staging their contents.
Don't run it yourself — touching the index is the user's call.

## 3. Run it

Write the report **outside the repository under review**: a file left inside
becomes an untracked file that Codex then reads as part of the change.

```bash
command -v codex >/dev/null \
  || { echo "codex CLI not installed — brew install codex (or npm i -g @openai/codex)"; exit 1; }
# ~20 ms, purely local. Only a definite "not logged in" (rc 1) stops the run: if
# the check times out or misfires, go ahead — the 401 branch below still catches
# it. `timeout` is optional because stock macOS has no coreutils.
command -v timeout >/dev/null && TO="timeout 5" || TO=""
$TO codex login status >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then echo "codex is not authenticated — run: codex login"; exit 1; fi
git rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "not a git repository — nothing to review here"; exit 1; }

# BASE and EFFORT may be handed in by the caller. Anything still unset falls back
# to the mechanical half of the resolution above — step 3, reading where this
# repo's PRs actually land, is a judgment call and stays yours to make first.
if [ -z "${BASE:-}" ]; then
  b="$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null)"
  [ -n "$b" ] && BASE="origin/$b"
fi
BASE="${BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)}"
# origin/HEAD only exists in a clone; a repo built with `git init` + `git remote
# add` has none, so fall back to the usual names before giving up.
if [ -z "${BASE:-}" ]; then
  for c in origin/main origin/master main master; do
    git rev-parse --verify -q "$c^{commit}" >/dev/null 2>&1 && { BASE="$c"; break; }
  done
fi
BASE="${BASE:-$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)}"
[ -n "$BASE" ] || { echo "no base resolved — name one, or review --uncommitted"; exit 1; }
EFFORT="${EFFORT:-high}"   # always explicit — never inherit the machine's config
# A base Codex can't resolve is not an error to it — it quietly reviews against
# some other upstream branch instead. Fetch it, or abort; never let it pick.
have_base() { git rev-parse --verify -q "$BASE^{commit}" >/dev/null; }
have_base || { git fetch --quiet origin "${BASE#origin/}" 2>/dev/null; have_base; } \
  || { echo "base $BASE not found — resolve it before reviewing"; exit 1; }
OUT="$(mktemp "${TMPDIR:-/tmp}/codex-review.XXXXXX")"
codex exec review --base "$BASE" -c model_reasoning_effort="$EFFORT" -o "$OUT" > "$OUT.log" 2>&1
if [ -s "$OUT" ]; then
  cat "$OUT"
elif grep -qiE '401|unauthorized|missing bearer|not logged in' "$OUT.log"; then
  # An unauthenticated run does not fail fast: it retries five times, then dumps
  # the 401. Say the one thing that fixes it instead of pasting the transcript.
  echo "codex is not authenticated — run: codex login"
else
  echo "codex review failed:"; tail -20 "$OUT.log"
fi
```

`-o` captures the verdict while the full transcript goes to the log, so stdout is
the report and nothing else. Pass `description: "Codex review"` on the `Bash`
call so the run is recognizable in the task list.

- **Background** — asked for by a pipeline, or a diff big enough to be slow: run
  that exact block with `Bash(run_in_background: true)`. The finished task's
  output is already the report.
- **Foreground** — same block, read inline.

A caller — a person or another skill — may hand you the base and the effort
level; both are meant to be passed in, and an explicit base wins over the
resolution above. Set the effort on every run rather than letting
`~/.codex/config.toml` decide, since that file differs from machine to machine.
The ladder is `minimal`, `low`, `medium`, `high`, `xhigh`; an unknown value is
rejected outright, so a typo cannot silently downgrade a review. `-m <model>`
overrides the model the same way. `--output-schema` is accepted but ignored in
review mode — the output is always prose.

## 4. Hand back the findings

Return Codex's report **verbatim** — no paraphrase, no summary, no commentary
around it. Its shape is a one-paragraph verdict followed by findings:

```
- [P1] Short title — /abs/path/file.js:12-14
  Why it breaks, in concrete terms.
```

Two things to check in what comes back:

- If the first line names a base other than `$BASE`, the review missed its
  target — re-run against the right ref rather than reporting it.
- An empty review is a normal result, not a failure: Codex exits `0` saying
  something like "There are no staged, unstaged, or untracked code changes to
  review."

When the run block stops early, its output is a single line — a missing CLI, an
expired login, an unresolvable base. Pass that line through as the result. Same
for anything else Codex refuses on: report it as-is rather than working around it.
