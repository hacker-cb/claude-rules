# claude-rules

Personal Claude Code configuration kept under version control: global rules,
skills and slash commands.

The repo deliberately lives outside `~/.claude` — that directory is Claude Code's
own home, full of runtime state (sessions, projects, caches) that has no business
in git. `install.sh` links the tracked parts back in.

## Layout

| Path | What it is |
|---|---|
| `rules/` | Global instructions applied to every project |
| `skills/` | Global skills |
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
