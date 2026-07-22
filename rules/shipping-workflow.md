# Shipping workflow

When any work is ready — feature, bug fix, chore, refactor, docs, anything — start
shipping it automatically. Do not ask for confirmation; the coverage gate below is
the one exception. Treat work as ready once the change is complete and verified
(tests pass / behavior confirmed) and the tree is committable.

1. **Local review** — see below.
2. **Report the coverage** — which engines ran, which didn't.
3. **Open the PR** — hand off to the `github-pr-workflow` skill, unless step 2
   came back short.

## Local review

Three different engines; each finds what the others miss. Run all three every
time, never silently skip one. Start the two background ones first so they overlap
with the inline pass:

1. `codex-review` skill — tell it this is a ship pipeline, so it runs the Codex
   call in the background instead of blocking.
2. `Workflow({ name: "code-review", args: "high" })` — returns immediately, the
   fleet runs detached.
3. `security-review` skill — runs inline in your own context, so it starts last.

All three read the branch through `git diff`, so **none of them sees untracked
files**. If `git ls-files --others --exclude-standard` lists anything that
belongs to this change, say so before reviewing and offer `git add -N` — a review
that silently skips the new files is worse than no review.

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

- `args` is `"<level> [target]"`. Level is `high`, `xhigh`, or `max` (`low` and
  `medium` exist only on the skill path); default to `high`, escalate for large or
  risky diffs. Target is optional — PR number, branch, ref range, path, or
  free-form instructions.
- Needs the `enableWorkflows` setting, **not** `ultracode`. This rule is the
  explicit instruction authorizing the `Workflow` call, so no keyword is required
  from the user.
- If `Workflow` is unavailable, ask the user to run `/code-review` themselves.
  Either way it is a missing engine and the coverage gate applies.

## Report the coverage

Every ship carries an explicit per-engine status, never an implicit "reviewed":

```
Review coverage
  codex-review     ok — 2 findings, both fixed
  code-review high ok — no findings
  security-review  UNAVAILABLE — <the error, quoted>
```

An engine counts as missing both when it could not start (`codex` absent or
`codex login` expired, `Workflow` unavailable, the skill erroring out) and when it
started but returned nothing usable — a background task that died, an empty
report. Quote the actual error; a guessed cause is worse than none.

If all three ran, hand off to `github-pr-workflow` right away, no confirmation
needed. **If any did not, stop before the PR**: report the gap, offer the fix for
it (`codex login`, running `/code-review` by hand), and ship only once the user
says to. This is the single confirmation gate in this workflow — a ship with a
reviewer silently missing is exactly what it exists to prevent.
