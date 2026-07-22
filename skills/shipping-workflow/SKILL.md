---
name: shipping-workflow
description: >-
  Take finished work from the working tree to an open pull request — local review
  across every available reviewer, the fixes it turns up, a coverage check, then
  the PR. Use it when the user says to ship, open a PR or MR, push this up, or get
  this merged; and use it unprompted the moment a piece of work is complete and
  verified and the tree is committable, since shipping is the default ending for
  finished work. Do not use it for work still in progress, or where the user or
  the project has said not to commit yet.
---

# Shipping workflow

Finished work ships automatically. Do not ask for confirmation; the coverage gate
below is the one exception. Work counts as ready once the change is complete and
verified — tests pass, or the behavior is confirmed — and the tree is committable.

1. **Local review** — hand off to the `multi-review` skill.
2. **Apply the fixes** — that skill reports, it does not fix. Skip a finding only
   if the fix would change intended behavior, reach well outside the diff, or the
   finding is plainly wrong, and note the skip in one line. Do not open the PR
   with findings left unresolved.
3. **Check the coverage** — the gate below.
4. **Open the PR** — hand off to the `github-pr-workflow` skill.

## The coverage gate

The review reports what each reviewer actually covered, and separates a gap — a
reviewer that could not run, or one that ran and covered nothing — from a
deliberate skip with a stated reason. Only gaps matter here.

With no gaps, go straight to the PR; no confirmation needed. **With a gap, stop
before the PR.** Report it, pass on whatever the review says would close it, and
ship only once the user says to. This is the single confirmation gate in this
workflow — a ship with a reviewer silently missing is exactly what it exists to
prevent.

A project's own rules outrank this one: where the repository says to commit
straight to a branch, or not to commit until asked, or not to open PRs at all,
follow that and say which step you are skipping and why.
