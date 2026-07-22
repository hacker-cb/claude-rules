#!/usr/bin/env bash
#
# Link this repo's rules/, skills/ and commands/ into the Claude home, so Claude
# Code keeps finding them at ~/.claude/<name> while the git project itself lives
# here, outside that home.
#
# Nothing is ever replaced silently: if a path is already taken, the script asks
# first and always moves the old content to a timestamped backup before relinking.
#
# Usage: ./install.sh [--force] [--dry-run]
#   --force     don't ask before replacing (backups still happen — always)
#   --dry-run   only report what would change

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BACKUP_ROOT="${BACKUP_ROOT:-$CLAUDE_HOME/.install-backups}"
LINKS=(rules skills commands)

assume_yes=false
dry_run=false
backup_dir=""   # created lazily, only if something actually needs backing up
replaced=0 linked=0 kept=0 skipped=0

for arg in "$@"; do
  case "$arg" in
    -f|--force)   assume_yes=true ;;
    -n|--dry-run) dry_run=true ;;
    -h|--help)    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }

# Ask before destroying anything. Without a terminal we refuse rather than guess.
confirm() {
  $assume_yes && return 0
  if [[ ! -t 0 ]]; then
    warn "no terminal to ask on — re-run with --force to allow replacing"
    return 1
  fi
  local reply
  read -r -p "  replace it? [y/N] " reply
  [[ $reply == [yY] ]]
}

# Move the current path out of the way. Mandatory — never called conditionally.
backup() {
  local path=$1
  if [[ -z $backup_dir ]]; then
    backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    $dry_run || mkdir -p "$backup_dir"
  fi
  say "  $($dry_run && echo 'would back up' || echo 'backup') -> $backup_dir/$(basename "$path")"
  $dry_run || mv "$path" "$backup_dir/"
}

link_one() {
  local name=$1
  local src="$REPO_ROOT/$name"
  local dst="$CLAUDE_HOME/$name"

  if [[ ! -d $src ]]; then
    warn "$name: missing in the repo ($src) — skipped"
    ((skipped++)) || true
    return
  fi

  # Already pointing where it should: leave it alone, so re-running is a no-op.
  if [[ -L $dst && "$(readlink "$dst")" == "$src" ]]; then
    say "= $name: already linked"
    ((kept++)) || true
    return
  fi

  # -e alone would miss a broken symlink, hence the explicit -L.
  if [[ -e $dst || -L $dst ]]; then
    if [[ -L $dst ]]; then
      say "* $name: symlink already points to $(readlink "$dst")"
    else
      say "* $name: real $([[ -d $dst ]] && echo directory || echo file) is in the way"
    fi
    if ! confirm; then
      say "  left untouched"
      ((skipped++)) || true
      return
    fi
    backup "$dst"
    ((replaced++)) || true
  else
    ((linked++)) || true
  fi

  say "+ $name -> $src"
  $dry_run || ln -s "$src" "$dst"
}

$dry_run && say "dry run — nothing will be changed"
say "repo:        $REPO_ROOT"
say "claude home: $CLAUDE_HOME"
say ""

$dry_run || mkdir -p "$CLAUDE_HOME"
for name in "${LINKS[@]}"; do
  link_one "$name"
done

say ""
say "linked $linked, replaced $replaced, already ok $kept, skipped $skipped"
[[ -n $backup_dir ]] && say "$($dry_run && echo 'backup would go to' || echo 'backup'): $backup_dir"
exit 0
