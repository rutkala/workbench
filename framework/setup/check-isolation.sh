#!/usr/bin/env bash
# Checks that the workbench distro sees only the workbench folder and is locked down. Safe to run any time.
ok=0
pass() { echo "OK    $*"; }; bad() { echo "FAIL  $*"; ok=1; }
mountpoint -q /work && pass "workbench folder mounted at /work" || bad "/work not mounted"
# real mounts only: empty /mnt/c left from first boot and WSL's own /mnt/wsl, /mnt/wslg are fine
drives="$(findmnt -rn -o TARGET | grep -E '^/mnt/[a-z]$' || true)"
[ -z "$drives" ] && pass "no Windows drives mounted under /mnt" || bad "Windows drive mounted: $(echo $drives)"
other="$(mount | grep -iE 'drvfs|9p' | grep -v ' on /work ' | grep -viE 'wslg|/usr/lib/wsl|/tmp/.X11' || true)"
[ -z "$other" ] && pass "no other Windows mounts" || { bad "other Windows mounts:"; echo "$other"; }
if command -v powershell.exe >/dev/null 2>&1 || command -v cmd.exe >/dev/null 2>&1; then bad "Windows programs reachable"; else pass "Windows programs not reachable"; fi
[ -f /etc/claude-code/managed-settings.json ] && [ "$(stat -c %U /etc/claude-code/managed-settings.json)" = root ] && [ ! -w /etc/claude-code/managed-settings.json ] \
  && pass "enforced Claude settings present and read-only" || bad "managed Claude settings missing or writable"
sudo -n true 2>/dev/null && bad "sudo works without password" || pass "sudo needs your password"
command -v az >/dev/null 2>&1 && bad "Azure CLI installed" || pass "no Azure CLI"
if command -v sqlcmd >/dev/null 2>&1 && [ -f "$HOME/.config/workbench/sql.env" ]; then
  . "$HOME/.config/workbench/sql.env"
  # SQL Server needs ~30 s after the distro starts: retry up to 90 s
  sqlok=1
  for i in $(seq 1 30); do
    sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -C -Q "SET NOCOUNT ON; SELECT SERVERPROPERTY('Collation')" -h -1 2>/dev/null | grep -q BIN2_UTF8 && { sqlok=0; break; }
    sleep 3
  done
  [ $sqlok -eq 0 ] && pass "synthetic SQL Server reachable, Fabric collation" || bad "synthetic SQL Server not reachable"
fi
[ $ok -eq 0 ] && echo "RESULT: isolated" || echo "RESULT: NOT isolated - tell Claude"
exit $ok
