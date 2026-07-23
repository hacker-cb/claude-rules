# claude-rules

Personal Claude Code configuration kept under version control: global rules and
slash commands. The global **skills** that used to live here have moved to the
[`hcb-dev`](https://github.com/hacker-cb/claude-code-plugins) plugin (installed
from the marketplace, not symlinked) — see [Skills](#skills).

The repo deliberately lives outside `~/.claude` — that directory is Claude Code's
own home, full of runtime state (sessions, projects, caches) that has no business
in git. `install.sh` links the tracked parts back in.

## Layout

| Path | What it is |
|---|---|
| `rules/` | Global instructions applied to every project |
| `skills/` | Placeholder for *personal-only* skills; the shared ones moved to the `hcb-dev` plugin |
| `commands/` | Global slash commands |
| `.claude/rules/` | Rules scoped to working on *this* repo |
| `install.sh` | Links the three directories above into `~/.claude` |

## Install

```sh
./install.sh              # ask before replacing anything that is in the way
./install.sh --dry-run    # only report what would change
./install.sh --force      # don't ask (a backup is still always made)
```

Re-running is safe: correct symlinks are left alone. Anything already occupying
`~/.claude/{rules,skills,commands}` is moved to `~/.claude/.install-backups/<timestamp>/`
before being replaced — never deleted.

`CLAUDE_HOME` and `BACKUP_ROOT` override the target and backup locations.

## Skills

Global skills now ship as the **`hcb-dev`** plugin in the
[`hacker-cb-plugins`](https://github.com/hacker-cb/claude-code-plugins)
marketplace, installed through Claude Code rather than symlinked from here:

```text
/plugin marketplace add hacker-cb/claude-code-plugins
/plugin install hcb-dev@hacker-cb-plugins
```

`skills/` stays as a placeholder for any *personal-only* skill that shouldn't be
published to the marketplace; `install.sh` still links it into `~/.claude`.
