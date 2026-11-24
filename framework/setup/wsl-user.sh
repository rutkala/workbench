#!/usr/bin/env bash
# Runs as the normal Linux user inside the workbench distro (called by bootstrap.ps1). Safe to re-run.
set -euo pipefail
mountpoint -q /work || { echo "ERROR: /work is not mounted"; exit 1; }

echo "--- git (shared folder with Windows git)"
git config --global --replace-all safe.directory '*'
git config --global core.autocrlf true
git config --global core.filemode false
git config --global init.defaultBranch main
git config --global pull.ff only

echo "--- npm without sudo, report authoring CLI (validation only, no service access)"
mkdir -p "$HOME/.npm-global"; npm config set prefix "$HOME/.npm-global"
grep -q 'npm-global/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.dotnet/tools:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
npm install -g @microsoft/powerbi-report-authoring-cli >/dev/null 2>&1 && echo "  powerbi-report-author installed" || echo "  WARN: report CLI install failed (can retry later)"

echo "--- Claude Code (official installer)"
[ -x "$HOME/.local/bin/claude" ] || curl -fsSL https://claude.ai/install.sh | bash
"$HOME/.local/bin/claude" --version || true

grep -q 'cd /work' "$HOME/.bashrc" || echo '[ "$PWD" = "$HOME" ] && cd /work' >> "$HOME/.bashrc"
echo "--- user setup finished"
