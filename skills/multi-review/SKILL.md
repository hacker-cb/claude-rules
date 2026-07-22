---
name: multi-review
description: >-
  Review one change with every available reviewer at once — the Codex CLI, the
  built-in code-review workflow, the built-in security review — then consolidate
  their findings and report what each one actually covered. Use when the user
  asks for a review of the current change ("прогони ревью", "review this",
  "second opinion on this diff"), and before finished work is handed off — a
  pull or merge request about to be opened, "ship this", "push this up" — while
  findings can still change the outcome. Report-only: it never applies fixes; the
  caller decides what to do with them. Not an auto-trigger on every edit — it
  runs when a review is asked for, or when a change is about to leave the
  machine.
---

# Multi-review

Runs several independent reviewers over one change and returns a single write-up:
the consolidated findings, plus a line per reviewer stating what it covered. The
reviewers disagree about what "the change" even is, and that disagreement is where
coverage silently disappears — most of this skill exists to keep it visible.

Report-only. Never fix what comes back; hand findings and coverage to the caller.

## 1. Scope

**Kind.** Default is the change itself. Two variations are available on request:
narrowed (a path, or a focus such as "only error handling") and working-tree-only
("just what I changed since the last commit"). A request to audit existing code —
"look through the whole directory", "check every component" — is *not* a change:
each reviewer builds a diff and reviews nothing when that diff is empty. Say so
and stop, rather than quietly reviewing the last commit instead.

**Base.** First hit wins:

1. a base the caller named;
2. the open PR's base — `gh pr view --json baseRefName -q .baseRefName`;
3. where this repo's PRs actually land —
   `gh pr list --state merged --limit 10 --json baseRefName -q '.[].baseRefName' | sort | uniq -c`;
4. the default branch — `git symbolic-ref --short refs/remotes/origin/HEAD`;
5. `@{upstream}`, last resort — it narrows the review to unpushed commits.

**Range.** Base → working tree, so one pass covers the branch's commits together
with the uncommitted edits sitting on top of them.

**Risk** decides effort in the next step; default it to the middle of the ladder.
Raise it when the change reaches past itself (public interface, shared helper,
config, schema, wire format), cannot be walked back (it writes, migrates,
publishes, or persists a format someone else reads), meets input whose shape you
do not control, has nothing else checking it (no tests that run, no types, no
compiler), removes a guard, an error path or a test, or touches paths the project
marks sensitive (`CLAUDE.md`, `CODEOWNERS`, `SECURITY.md`). Lower it only for
mechanics with no behavior change; an explicit instruction from the caller wins.

**Uncommitted work.** When `git status --short` or
`git ls-files --others --exclude-standard` shows anything belonging to the change,
offer a commit before starting, and name the price of declining: Codex and
code-review read the working tree and see the edits either way, the security
review reads a commit range and does not, and files that are not tracked at all
are invisible to every reviewer. Offer — never commit anything yourself. A refusal
is a fine answer; it just goes into the report.

## 2. Pick

Three questions per reviewer, in order:

- **Available?** If not, record `UNAVAILABLE` with the reason; do not launch it.
- **Applicable?** When the scope asks for something a reviewer cannot do, skip it
  with a recorded reason — `n/a`.
- **How hard?** Map the risk onto that reviewer's own ladder and pass the level
  explicitly — never a machine-local default, since this skill runs on other
  people's machines.

| Reviewer | Available when | Reads | Narrowing | Ladder |
|---|---|---|---|---|
| `codex-review` skill | `command -v codex` | base → working tree | yes, expressed in prose | `minimal` `low` `medium` `high` `xhigh` |
| `code-review` workflow | the `Workflow` tool exists | base → working tree | yes, as a target argument | `high` `xhigh` `max` |
| `security-review` skill | the skill is in your skill list | commits only; base pinned to the default branch | no | none |

What that decides in practice: the security review goes `n/a` on a narrowed or
working-tree-only scope, and is mis-scoped whenever the PR targets anything but
the default branch — report that, do not hide it. The code-review workflow is the
only reviewer checking `CLAUDE.md` compliance, and its cheap levels are out of
reach: `low` and `medium` belong to the `/code-review` slash command, which only
the user can invoke, and an unknown level is not rejected — it silently becomes
`high`, with the word forwarded as the review target.

## 3. Run

Start the detachable reviewers first so they overlap with the inline one.

- **codex-review** — invoke the skill, passing the base, the effort level, and the
  fact that this is a pipeline run so it backgrounds the call.
- **code-review** — `Workflow({ name: "code-review", args: "<level> [target]" })`
  returns immediately and runs detached. This skill is the explicit instruction
  authorizing that call.
- **security-review** — invoke the skill inline, last. Do not delegate it to a
  subagent to save context: subagents have neither the `Agent` nor the `Task`
  tool, so the skill's own filtering pass — parallel sub-tasks dropping every
  candidate below confidence 8 — silently does not run, and what comes back is
  unfiltered.

## 4. Collect

Take two things from each reviewer: what it covered — base and file count — and
its findings.

**Zero files covered is not a pass.** Decide it by the count, never by matching a
reviewer's wording: each phrases an empty review differently, and Codex phrases it
differently again between `--base` and `--uncommitted`.

When a reviewer fails, quote its error instead of guessing a cause. A `401` or an
auth complaint in Codex's log means `codex login`, and one line saying so beats
twenty lines of transcript.

## 5. Consolidate

Dedup by `(file, line)` **and** by mechanism — reviewers routinely anchor one root
cause at different lines, and one bug described twice reads as two. Keep whichever
write-up carries the concrete failure scenario, and rank by severity.

## 6. Report

Coverage first, one line per reviewer, scope before verdict:

```
Review coverage
  codex-review     origin/master, 3 files, high — 2 findings
  code-review      origin/master, 3 files, high — no findings
  security-review  n/a — narrowed scope, cannot be restricted to a path
```

Three statuses, kept apart deliberately: `UNAVAILABLE` — the reviewer could not
run; `n/a` — it was deliberately not run, and why; `nothing to review` — it ran
and covered zero files. The first and third are gaps in coverage. The second is
not.

Then the findings, and nothing else: no fixes, no patches, no offer to apply them.

When a PR or MR is about to be opened, say the gaps out loud before the handoff
rather than burying them under the findings. Whoever is shipping decides what to
do about them, but a ship with a reviewer silently missing is exactly what the
coverage lines exist to prevent.
