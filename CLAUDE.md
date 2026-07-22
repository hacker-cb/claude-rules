# claude-rules

Personal Claude Code configuration under version control — global `rules/`,
`skills/`, and `commands/`, plus an `install.sh` that symlinks them into
`~/.claude`. See [README.md](README.md) for the full layout and install flow.

## Working on this repo

- **Skills** live in `skills/<name>/SKILL.md` with YAML frontmatter (`name`,
  `description`). The `description` is what makes a skill trigger, so keep it
  precise. Frontmatter must be valid YAML: if a `description` contains a
  colon-space (`: `) or quotes, wrap the value in a folded block scalar (`>-`)
  so GitHub's strict parser doesn't reject it.
- **Rules** — everything in `rules/` applies to every project. A rule that should
  only govern work on this repo goes in `.claude/rules/` instead.
- After changing tracked files, `./install.sh` (re)links `rules/`, `skills/`,
  and `commands/` into `~/.claude` (safe to re-run; backs up anything replaced).

## Official Claude Code docs

Fetch the `.md` variant of any page for raw markdown.

- [Skills](https://code.claude.com/docs/en/skills.md)
- [Memory / CLAUDE.md](https://code.claude.com/docs/en/memory.md)
- [Slash commands](https://code.claude.com/docs/en/commands.md)
- [Settings](https://code.claude.com/docs/en/settings.md)
- [Hooks](https://code.claude.com/docs/en/hooks.md)
- [MCP](https://code.claude.com/docs/en/mcp.md)
- [Subagents](https://code.claude.com/docs/en/sub-agents.md)
- [Docs index (`llms.txt`)](https://code.claude.com/docs/llms.txt)
