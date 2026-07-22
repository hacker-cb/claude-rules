# Shipping workflow

When any work is ready — feature, bug fix, chore, refactor, docs, anything — start
shipping it automatically. Do not ask for confirmation; the coverage gate below is
the one exception. Treat work as ready once the change is complete and verified
(tests pass / behavior confirmed) and the tree is committable.

1. **Local review** — see below.
2. **Report the coverage** — what each engine actually covered.
3. **Open the PR** — hand off to the `github-pr-workflow` skill, unless step 2
   came back short.

## Local review

Three different engines; each finds what the others miss. Run all three every
time, never silently skip one. Start the two detachable ones first, so they
overlap with the third:

1. `codex-review` skill — tell it this is a ship pipeline, so it runs the Codex
   call in the background instead of blocking.
2. `Workflow({ name: "code-review", args: "high" })` — returns immediately, the
   fleet runs detached.
3. `security-review` skill — runs in your own context, so it starts last. Do not
   hand it to a subagent to get it off your context: subagents have neither the
   `Agent` nor the `Task` tool, so the skill's own filtering pass — parallel
   sub-tasks that drop every candidate below confidence 8 — silently does not
   run, and what comes back is unfiltered.

### What each engine actually reads

They disagree, and the disagreements are where coverage quietly disappears:

| Engine | Diff | Uncommitted | Untracked |
|---|---|---|---|
| `codex-review` | `merge-base(<base>, HEAD)` → working tree | yes | no |
| `code-review` | `@{upstream}...HEAD` plus `git diff HEAD` | yes | no |
| `security-review` | `origin/HEAD...` — commits only, base not selectable | no | no |

Two consequences worth acting on before launching anything:

- **Commit the change first, new files included.** `security-review` reads a
  commit range, so uncommitted work is invisible to it, and `git add -N` does not
  help — intent-to-add reaches `git diff` but never a commit. Run
  `git ls-files --others --exclude-standard` and get everything belonging to the
  change into the commit. Where a repo's own policy forbids committing yet, say
  so: that engine then covers nothing and the gate applies.
- **`security-review` is pinned to the default branch.** When the PR targets
  anything else, it reviews the wrong range no matter what the other two use.
  Report that as a gap, not as a pass.

Then wait for all three and consolidate. Dedup across reports by `(file, line)`
*and* by mechanism — the engines often anchor one root cause at different lines —
and keep the write-up with the concrete failure scenario. Apply the fixes; skip a
finding only if the fix would change intended behavior, reach well outside the
diff, or the finding is plainly wrong, and note the skip in one line. Do not open
the PR with findings left unresolved.

### Invoking the Claude review

`/code-review` carries `disable-model-invocation`: it cannot be invoked via the
Skill tool, and `ultracode` does not lift that. Use the built-in workflow of the
same name — the engine that skill drives at high effort.

- `args` is `"<level> [target]"`. Level is `high`, `xhigh`, or `max`; default to
  `high`, escalate for large or risky diffs. Target is optional — PR number,
  branch, ref range, path, or free-form instructions.
- An unknown level is **not** rejected: the workflow silently falls back to
  `high` and passes the word on as the target. `args: "low"` therefore buys a
  full-price review aimed at a nonsense target. `low` and `medium` exist only on
  the skill path, so they are the user's to run, not yours.
- Needs the `enableWorkflows` setting, **not** `ultracode`. This rule is the
  explicit instruction authorizing the `Workflow` call, so no keyword is required
  from the user.
- If `Workflow` is unavailable, ask the user to run `/code-review` themselves.
  Either way it is a missing engine and the coverage gate applies.

## Report the coverage

Every ship carries an explicit per-engine line, never an implicit "reviewed".
Each line states **what was covered** — base ref and file count — before any
verdict, because a verdict without a scope cannot be checked:

```
Review coverage
  codex-review     origin/master, 3 files — 2 findings, both fixed
  code-review high origin/master, 3 files — no findings
  security-review  origin/master, 0 files — NOTHING TO REVIEW (work uncommitted)
```

An engine is missing when it could not start (`codex` absent or `codex login`
expired, `Workflow` unavailable, the skill erroring out), when it started and
returned nothing usable (a dead background task, an empty report), and when it
reports findings without saying what it covered. Quote the actual error; a
guessed cause is worse than none.

**Zero files covered is not a pass.** Decide it by the file count, never by
matching an engine's wording — each phrases an empty review differently, and
`codex exec review --base` phrases it differently from `--uncommitted`. Zero
files means that engine covered nothing at all, usually because the engines
disagree about what the change even is. It is a gap.

If all three covered the change, hand off to `github-pr-workflow` right away, no
confirmation needed. **If any did not, stop before the PR**: report the gap, offer
the fix for it (`codex login`, committing the work, running `/code-review` by
hand), and ship only once the user says to. This is the single confirmation gate
in this workflow — a ship with a reviewer silently missing is exactly what it
exists to prevent.
