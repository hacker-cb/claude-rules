---
name: codex-review
description: >-
  Run a Codex native code review on the current git state, model-invocable. Use when a ship/PR pipeline or the user asks for a "codex review" / "/codex:review" and the gated `/codex:review` slash command cannot be invoked programmatically (it carries `disable-model-invocation`). Review-only — returns Codex's findings verbatim and never fixes anything. Invoke deliberately (when a pipeline or the user calls for it), not as an auto-trigger on every change.
---

# Codex review (model-invocable)

Runs Codex's built-in reviewer directly. The `disable-model-invocation: true` flag lives only on the plugin's `/codex:review` slash command (the Skill-tool path); the underlying work is a plain `node` call you run via Bash, which has no such gate. This is the exact engine `/codex:review` uses — review-only, native reviewer.

For custom focus / adversarial framing, use the plugin's own `/codex:adversarial-review` instead (this skill maps to the plain native reviewer, which rejects focus text).

## 1. Resolve the companion (version-agnostic)

Glob the latest installed plugin version so this survives a codex-plugin upgrade — never hardcode the version directory:

```bash
COMP="$(ls -1 ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | sort -V | tail -1)"
```

## 2. Pick the scope (you decide from context; the companion auto-resolves when you pass nothing)

`resolveReviewTarget` in the companion already does the sensible thing, so prefer passing nothing:

- **Dirty working tree** (uncommitted changes, pre-commit review) → run with no scope args. The companion reviews the working tree (staged + unstaged + untracked).
- **Clean tree** (reviewing a committed branch / open PR before ship) → the companion diffs against the repo's GitHub default branch (`git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main`/`master`/`trunk` — note: **not** `dev`). Trust this **only when the PR targets the repo's default branch**.
- **PR targets a non-default base** (e.g. a repo where PRs go to `dev` but the default is `master`) → resolve the real base and pass it explicitly:
  ```bash
  BASE="origin/$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null)"
  # then: node "$COMP" review --base "$BASE"
  ```
- **Force a specific base / merge-base** → `--base <ref>`.

Rule of thumb: default to no args (trust auto); add `--base` only when the auto-detected default branch is the wrong base for the change under review.

## 3. Run

Same command either way — only the harness wrapper changes:

```bash
node "$COMP" review            # auto scope
# or
node "$COMP" review --base "$BASE"
```

- **Foreground (default)** — run the Bash call normally and read the findings inline.
- **Background (on request)** — when the caller asks for it (e.g. a ship pipeline running this alongside `/code-review`) or the diff is large/slow, wrap the same call in `Bash(run_in_background: true)` and collect the output when it finishes.

Note: the companion's own `--background` flag does **not** actually detach — only the harness `Bash(run_in_background: true)` does.

## 4. Output

Return Codex's stdout **verbatim** — do not paraphrase, summarize, or add commentary around it. This skill is **review-only**: do not fix the issues it reports (act on them separately, as the calling pipeline decides).

If the companion errors that the Codex CLI is missing or unauthenticated, tell the user to run `/codex:setup` — do not try to work around it.
