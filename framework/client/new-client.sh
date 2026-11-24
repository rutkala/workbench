#!/usr/bin/env bash
# Create or adopt a CLIENT repo under <workbench>/clients/<name>.
#
#   new-client.sh <name> [--adopt] [--track-files] [--dev-server <host>] [--database <db>] [--term <client term>]...
#
#   <name>          folder name: lowercase, digits, dashes (one repo per Fabric workspace family: DEV/UAT/PROD = branches)
#   --adopt         the folder is already a git repo (e.g. you cloned the client's DevOps repo there).
#                   Workbench files stay LOCAL (never pushed): CLAUDE.md, docs/, synthetic/ are listed in
#                   .git/info/exclude and the connection filter in .git/info/attributes. The client's tree is untouched.
#   --track-files   with --adopt: write .gitignore/.gitattributes into the repo instead (client agreed to host them)
#   --dev-server    real DEV SQL endpoint host of the client (kept in git; swapped to localhost locally)
#   --database      database name (same name is used for the local synthetic database)
#   --term          a word that must never appear in the generic repo (client name, domain...). Repeatable.
#
# Works in WSL bash and in Git Bash on Windows. Never pushes, never needs credentials.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
wb="$(cd "$here/../.." && pwd)"
name="${1:?usage: new-client.sh <name> [--adopt] [--dev-server host] [--database db] [--term t]...}"; shift
adopt=0; track=0; server=""; db=""; terms=()
while [ $# -gt 0 ]; do
  case "$1" in
    --adopt) adopt=1;;
    --track-files) track=1;;
    --dev-server) server="$2"; shift;;
    --database) db="$2"; shift;;
    --term) terms+=("$2"); shift;;
    *) echo "unknown option $1"; exit 2;;
  esac; shift
done
case "$name" in *[!a-z0-9-]*|"") echo "name must be lowercase letters, digits, dashes"; exit 2;; esac
dir="$wb/clients/$name"
mkdir -p "$wb/clients"
touch "$wb/clients/.client-terms"

if [ $adopt -eq 1 ]; then
  [ -d "$dir/.git" ] || { echo "--adopt: $dir is not a git repo"; exit 1; }
else
  [ -e "$dir" ] && { echo "$dir already exists (use --adopt for an existing repo)"; exit 1; }
  mkdir -p "$dir"; git -C "$dir" init -q -b dev
fi
cd "$dir"

# --- files (only created when missing) ---
mk() { [ -e "$1" ] || { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  created $1"; }; }
IGNORE_RULES='# never commit anything that can hold real data
**/.pbi/cache.abf
**/.pbi/localSettings.json
*.pbix
*.abf
*.bak
.env
/synthetic/out/'
ATTR_RULES='# local/synthetic connection swap (see CLAUDE.md "Connections")
*.tmdl filter=fabricconn'
# add_once <file> <lines>: append each line not yet present
add_once() { mkdir -p "$(dirname "$1")"; touch "$1"; while IFS= read -r l; do grep -qxF -- "$l" "$1" || echo "$l" >> "$1"; done <<< "$2"; }
local_only=0
[ $adopt -eq 1 ] && [ $track -eq 0 ] && local_only=1
if [ $local_only -eq 1 ]; then
  add_once .git/info/exclude "$IGNORE_RULES
# workbench files: local only, never pushed to the client
/CLAUDE.md
/docs/
/synthetic/"
  add_once .git/info/attributes "$ATTR_RULES"
  echo "  local-only: rules in .git/info/exclude and .git/info/attributes (nothing added to the client's tree)"
else
  mk .gitignore <<< "$IGNORE_RULES"
  mk .gitattributes <<< "* text=auto
*.sh text eol=lf
$ATTR_RULES"
fi
mk CLAUDE.md <<EOF
# Client: $name

Generic rules come from the workbench CLAUDE.md (parent folder). This file adds client rules.

## Layout
- Fabric item folders: synced to the client's workspaces (one branch per workspace, see client-specific rules).
- \`synthetic/\`: synthetic data profile, generator config, local database scripts.
- \`docs/\`: client decisions (\`docs/decisions.md\`) and notes.

## Connections
- Semantic models read \`Server\`/\`Database\` parameters.
- In git: the real DEV host. Locally: \`localhost\` (synthetic SQL Server), via the \`fabricconn\` git filter.
- Work only on \`dev\` and \`feature/*\` branches locally (the filter maps the DEV host only).

## Client-specific rules
- (fill in: data sensitivity, naming conventions, contacts, workspace names)
EOF
mk docs/decisions.md <<'EOF'
# Decisions

| Date | Decision | Reason |
|---|---|---|
EOF
mkdir -p synthetic

# --- git settings (local only; shared by Windows git and WSL git) ---
git config core.autocrlf true
git config core.filemode false
git config core.hooksPath "../../framework/git/client-hooks"
if [ -n "$server" ]; then
  esc="$(printf '%s' "$server" | sed 's/[.]/\\./g')"
  git config filter.fabricconn.smudge "sed -e 's|\"$esc\"|\"localhost\"|g'"
  git config filter.fabricconn.clean  "sed -e 's|\"localhost\"|\"$server\"|g'"
  git config workbench.devServer "$server"
  echo "  connection filter: $server <-> localhost"
fi
[ -n "$db" ] && git config workbench.database "$db"

# --- client terms for the generic-repo guard ---
for t in "$name" "${terms[@]}"; do
  grep -qixF -- "$t" "$wb/clients/.client-terms" || echo "$t" >> "$wb/clients/.client-terms"
done

# re-apply the filter to files already checked out (adopt case)
if [ $adopt -eq 1 ] && [ -n "$server" ] && git rev-parse --verify -q HEAD >/dev/null; then
  if [ -z "$(git status --porcelain)" ]; then
    git ls-files '*.tmdl' -z | xargs -0 -r rm -f && git checkout -- . && echo "  filter applied to checked-out .tmdl files"
  else
    echo "  NOTE: uncommitted changes present; filter not re-applied. Commit or stash, then run: git checkout -- ."
  fi
fi

echo "Client repo ready: $dir"
[ $adopt -eq 0 ] && echo "Next (you, on Windows): git -C \"clients/$name\" remote add origin <DevOps repo URL>"
exit 0
