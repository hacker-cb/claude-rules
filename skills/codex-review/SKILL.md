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
BASE=origin/main      # whatever the base resolution above landed on
# A base Codex can't resolve is not an error to it — it quietly reviews against
# some other upstream branch instead. Fetch it, or abort; never let it pick.
have_base() { git rev-parse --verify -q "$BASE^{commit}" >/dev/null; }
have_base || { git fetch --quiet origin "${BASE#origin/}" 2>/dev/null; have_base; } \
  || { echo "base $BASE not found — resolve it before reviewing"; exit 1; }
OUT="$(mktemp "${TMPDIR:-/tmp}/codex-review.XXXXXX")"
codex exec review --base "$BASE" -o "$OUT" > "$OUT.log" 2>&1
if [ -s "$OUT" ]; then cat "$OUT"; else echo "codex review failed:"; tail -20 "$OUT.log"; fi
```

`-o` captures the verdict while the full transcript goes to the log, so stdout is
the report and nothing else. Pass `description: "Codex review"` on the `Bash`
call so the run is recognizable in the task list.

- **Background** — asked for by a pipeline, or a diff big enough to be slow: run
  that exact block with `Bash(run_in_background: true)`. The finished task's
  output is already the report.
- **Foreground** — same block, read inline.

Model and reasoning effort come from `~/.codex/config.toml`; override per run
with `-m <model>` or `-c model_reasoning_effort=high`. `--output-schema` is
accepted but ignored in review mode — the output is always prose.

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

`codex: command not found` means the CLI isn't installed (`brew install codex` or
`npm i -g @openai/codex`); an auth error means `codex login` expired. Report
either as-is instead of working around it.
