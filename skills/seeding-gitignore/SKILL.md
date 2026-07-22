---
name: seeding-gitignore
description: Use when creating a new `.gitignore`, editing an existing one, initializing a new repo (`git init`), or whenever a write to a file named `.gitignore` at any depth is about to happen. Also use when the user asks to ignore `.DS_Store`, Claude Code local files, Superpowers artifacts, git worktrees, or any OS-level noise. Provides the canonical baseline every project of this user carries: OS files, editor swap, Claude Code per-developer files (`.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/scheduled_tasks.lock`) while keeping team-shared `.claude/` config committed, Superpowers per-session artifacts (`.superpowers/`), and git worktrees from both the Superpowers skill (`.worktrees/`) and Claude Code's native `/worktree` (`.claude/worktrees/`). Apply unconditionally regardless of language or framework; language-specific patterns (`node_modules`, `target/`, `__pycache__`) come from the language's own tooling and are out of scope. Never ignore `docs/superpowers/` — its `specs/` and `plans/` files are committed.
---

# Seeding `.gitignore` with the canonical baseline

## Scope

A baseline of `.gitignore` entries every repo of this user carries, regardless of language, framework, or layout. Four buckets that always apply:

1. **OS noise** — macOS metadata, Windows thumbnails, recycle bins.
2. **Editor scratch** — vim swap, generic backup files.
3. **Claude Code per-developer files** — `settings.local.json`, `CLAUDE.local.md`, plugin lock state. Team-shared `.claude/` config (`settings.json`, `agents/`, `commands/`, `hooks/`, `rules/`, `skills/`, `agent-memory/`) stays committed.
4. **Workflow tooling** — Superpowers per-session brainstorming under `.superpowers/` and git worktrees in two locations: `.worktrees/` (Superpowers `using-git-worktrees` skill default) and `.claude/worktrees/` (Claude Code native `/worktree` default). Both are covered because both mechanisms are in use. The planning files at `docs/superpowers/specs/` and `docs/superpowers/plans/` are **committed**, not ignored — they are project planning records, not local state.

When seeding, ensure all four buckets are present. If the file already exists, **add only what is missing** — never reorder, rewrite, or wholesale-replace an existing file. If the file follows a third-party / vendor convention, skip this skill and follow that convention.

## The canonical baseline

```gitignore
# --- OS ---
.DS_Store
.AppleDouble
.LSOverride
Icon
._*
Thumbs.db
ehthumbs.db
desktop.ini
$RECYCLE.BIN/

# --- Editor swap / backup ---
*.swp
*.swo
*~

# --- Claude Code: per-developer files ---
# Committed: .claude/settings.json, .claude/agents/, .claude/commands/,
#            .claude/hooks/, .claude/rules/, .claude/skills/,
#            .claude/agent-memory/, CLAUDE.md, .mcp.json, .worktreeinclude
.claude/settings.local.json
.claude/*.local.json
CLAUDE.local.md
# Lock from the /schedule and /loop plugins; harmless if those are unused.
.claude/scheduled_tasks.lock

# --- Superpowers per-session artifacts ---
# Sibling docs/superpowers/{specs,plans}/ is COMMITTED — never list it here.
.superpowers/

# --- Git worktrees ---
# .worktrees/         — Superpowers `using-git-worktrees` skill default
# .claude/worktrees/  — Claude Code native `/worktree` default (overridable via WorktreeCreate hook)
.worktrees/
.claude/worktrees/
```

## Committed vs ignored

The Claude Code and Superpowers buckets are **selective ignore**, not blanket ignore. Team-shared files belong in git so collaborators (and future-you on another machine) get the same setup.

| Committed (do not ignore) | Ignored (per-developer / per-session) |
|---|---|
| `CLAUDE.md` | `CLAUDE.local.md` |
| `.mcp.json` | `.claude/settings.local.json` |
| `.worktreeinclude` | `.claude/*.local.json` |
| `.claude/settings.json` | `.claude/scheduled_tasks.lock` |
| `.claude/agents/` | `.superpowers/` |
| `.claude/commands/` | `.worktrees/` (Superpowers skill default) |
| `.claude/hooks/` | `.claude/worktrees/` (Claude Code native `/worktree` default) |
| `.claude/rules/` | OS / editor noise (see baseline) |
| `.claude/skills/` |  |
| `.claude/agent-memory/` (autogen, written by subagents with `memory: project`) |  |
| `docs/superpowers/specs/` |  |
| `docs/superpowers/plans/` |  |

## Why no `.claude/cache/`, `state/`, `logs/`, `tmp/` in the baseline

Claude Code's scratch directories — caches, debug logs, paste/image caches, file history, session env — live under the user's **global** `~/.claude/`, never under the project-local `.claude/`. A project-level rule cannot fire on a path that never appears, so preempting them adds noise without benefit.

Two related auto-ignore facts worth knowing:

- Claude Code appends `.claude/settings.local.json` to `~/.config/git/ignore` the first time it writes one. The project `.gitignore` entry is still required so the rule travels with the repo and applies to teammates.
- `CLAUDE.local.md` is **not** auto-ignored anywhere. The project `.gitignore` is the only barrier.

## Editing an existing `.gitignore`

1. Read the file first. Identify which baseline buckets are present and which are missing.
2. Add only the missing buckets. Do not reorder or rewrite existing sections.
3. Match the existing comment style and section dividers (`# --- ... ---` if used, otherwise whatever the file already does).
4. Keep the inline `# Committed: ...` comment in the Claude Code section when adding it — it documents the selective-ignore split for future readers.

## Common mistakes

| Mistake | Fix |
|---|---|
| Blanket-ignoring `.claude/` | Use the selective list — team-shared config (`settings.json`, `agents/`, `commands/`, `hooks/`, `rules/`, `skills/`, `agent-memory/`) must stay committed |
| Forgetting `CLAUDE.local.md` | Claude Code does **not** auto-ignore it anywhere; the project `.gitignore` is the only barrier |
| Covering only `.worktrees/` (or only `.claude/worktrees/`) | Both paths are in active use — Superpowers `using-git-worktrees` defaults to `.worktrees/`, Claude Code native `/worktree` defaults to `.claude/worktrees/`. List both |
| Preemptively adding `.claude/cache/`, `.claude/state/`, `.claude/logs/`, `.claude/tmp/` | Those scratch dirs live in the user's global `~/.claude/`, never in the project — project-level rules cannot fire |
| Ignoring `docs/superpowers/` because the path looks Superpowers-related | The `specs/` and `plans/` files there are project planning records and must be committed; only the dotted `.superpowers/` is local |
| Adding `node_modules/`, `target/`, `dist/`, `__pycache__/` inside the baseline section | Language-specific patterns belong in their own section below; the baseline is language-agnostic |
| Replacing an existing `.gitignore` wholesale to match the baseline | Only append what is missing; preserve existing structure and comments |
| Skipping Windows OS entries because the developer is on macOS | Collaborators may be on Windows; keep cross-platform OS entries |
