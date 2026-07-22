# Shipping workflow

When any work is ready — a feature, bug fix, chore, refactor, docs, or anything
else — start shipping it automatically — do not ask
for confirmation, just run the steps below. Treat work as ready once the change is
complete and verified (tests pass / behavior confirmed) and the tree is committable.

Ship it in two steps:

1. **Local review** — run `/codex-review` in the background and `/code-review` and `/security-review` alongside it, then consolidate all three reports (dedup the overlap) and apply the fixes.
2. **Open the PR** — hand off to the `github-pr-workflow` skill.
