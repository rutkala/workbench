#!/usr/bin/env bash
# Runs as root inside the workbench distro (called by bootstrap.ps1). Safe to re-run.
#   wsl-root.sh <linux-user> <windows-root, e.g. C:/Dev/workbench> <sql|nosql>
# Does: base tools, Node, .NET, sqlcmd, isolation (wsl.conf + fstab), sudo hardening,
#       enforced Claude Code settings, optional synthetic SQL Server (container).
set -euo pipefail
USER_NAME="${1:?user}"; WINROOT="${2:?windows root}"; SQL="${3:-sql}"
UID_N="$(id -u "$USER_NAME")"; GID_N="$(id -g "$USER_NAME")"; HOME_U="$(getent passwd "$USER_NAME" | cut -d: -f6)"
export DEBIAN_FRONTEND=noninteractive
log() { echo; echo "--- $*"; }

log "base tools"
apt-get update -y
apt-get install -y git curl ca-certificates gnupg unzip jq bubblewrap socat python3 python3-venv python3-pip

log "Node.js 22 (NodeSource)"
if ! node --version 2>/dev/null | grep -q '^v22'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

log "Microsoft package feed (sqlcmd) with .NET pinned to Ubuntu's feed"
if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
  . /etc/os-release
  curl -fsSL "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -o /tmp/msprod.deb
  dpkg -i /tmp/msprod.deb && rm -f /tmp/msprod.deb
fi
cat > /etc/apt/preferences.d/dotnet-from-ubuntu <<'EOF'
Package: dotnet* aspnet* netstandard*
Pin: origin "packages.microsoft.com"
Pin-Priority: -10
EOF
apt-get update -y
apt-get install -y dotnet-sdk-8.0 sqlcmd

log "isolation: /etc/wsl.conf"
cat > /etc/wsl.conf <<EOF
[boot]
systemd=true

[automount]
# No Windows drive is mounted. Only /etc/fstab entries (the workbench folder) are.
enabled=false
mountFsTab=true

[interop]
# Linux cannot start Windows programs.
enabled=false
appendWindowsPath=false

[user]
default=$USER_NAME
EOF

log "isolation: mount only $WINROOT at /work"
mkdir -p /work; chown "$USER_NAME:$USER_NAME" /work
OPTS="rw,noatime,metadata,uid=$UID_N,gid=$GID_N,umask=022"
WIN_FWD="${WINROOT//\\//}"; WIN_ESC="${WIN_FWD//\//\\134}"
try_entry() {
  sed -i '\# /work drvfs #d' /etc/fstab
  echo "$1 /work drvfs $OPTS 0 0" >> /etc/fstab
  umount /work 2>/dev/null || true
  mount /work 2>/dev/null && mountpoint -q /work && [ -e /work/framework ]
}
if try_entry "$WIN_FWD"; then echo "mount OK"
elif try_entry "$WIN_ESC"; then echo "mount OK (escaped)"
else echo "ERROR: could not mount $WINROOT"; cat /etc/fstab; exit 1; fi
umount /work || true

log "sudo always asks for the password (no cached sudo for processes started later)"
echo "Defaults:$USER_NAME timestamp_timeout=0" > /etc/sudoers.d/workbench
chmod 440 /etc/sudoers.d/workbench; visudo -cf /etc/sudoers.d/workbench

log "enforced Claude Code settings: /etc/claude-code/managed-settings.json (root-owned, read-only for you)"
mkdir -p /etc/claude-code
cat > /etc/claude-code/managed-settings.json <<'EOF'
{
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": [
      "Bash(az:*)", "Bash(az *)", "Bash(fab:*)", "Bash(fab *)",
      "Bash(sudo:*)", "Bash(sudo *)", "Bash(su:*)", "Bash(su *)",
      "Bash(git push:*)", "Bash(git push *)",
      "Bash(docker:*)", "Bash(docker *)",
      "WebFetch(domain:api.fabric.microsoft.com)",
      "WebFetch(domain:api.powerbi.com)",
      "WebFetch(domain:management.azure.com)",
      "WebFetch(domain:login.microsoftonline.com)",
      "WebFetch(domain:dev.azure.com)"
    ]
  },
  "sandbox": {
    "enabled": true,
    "network": {
      "allowedDomains": [
        "registry.npmjs.org", "*.npmjs.org",
        "pypi.org", "files.pythonhosted.org",
        "api.nuget.org", "*.nuget.org",
        "github.com", "*.githubusercontent.com",
        "packages.microsoft.com",
        "learn.microsoft.com",
        "localhost:1433", "127.0.0.1:1433"
      ],
      "deniedDomains": [
        "*.fabric.microsoft.com", "*.powerbi.com", "*.analysis.windows.net",
        "login.microsoftonline.com", "management.azure.com",
        "dev.azure.com", "*.visualstudio.com",
        "*.sharepoint.com", "*.blob.core.windows.net", "*.dfs.core.windows.net"
      ]
    }
  }
}
EOF
chown root:root /etc/claude-code/managed-settings.json; chmod 644 /etc/claude-code/managed-settings.json

if [ "$SQL" = "sql" ]; then
  log "synthetic SQL Server 2022 (container, Fabric collation, auto-start)"
  apt-get install -y docker.io
  systemctl enable --now docker || service docker start
  mkdir -p /root/workbench; chmod 700 /root/workbench
  gen() { echo "Wb$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)a1x"; }
  [ -f /root/workbench/sql-sa.env ] || echo "SA_PASSWORD=$(gen)" > /root/workbench/sql-sa.env
  chmod 600 /root/workbench/sql-sa.env; . /root/workbench/sql-sa.env
  if ! docker ps -a --format '{{.Names}}' | grep -qx sql-synthetic; then
    docker run -d --name sql-synthetic --restart unless-stopped \
      -e ACCEPT_EULA=Y -e MSSQL_PID=Developer -e "MSSQL_SA_PASSWORD=$SA_PASSWORD" \
      -e MSSQL_COLLATION=Latin1_General_100_BIN2_UTF8 \
      -p 1433:1433 -v sql-synthetic-data:/var/opt/mssql \
      mcr.microsoft.com/mssql/server:2022-latest
  fi
  echo -n "waiting for SQL Server"
  for i in $(seq 1 60); do
    sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" >/dev/null 2>&1 && break
    echo -n "."; sleep 2
  done; echo
  install -d -o "$USER_NAME" -g "$USER_NAME" -m 700 "$HOME_U/.config/workbench"
  DEVENV="$HOME_U/.config/workbench/sql.env"
  if [ ! -f "$DEVENV" ]; then
    DEVPW="$(gen)"
    sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -C -Q "IF SUSER_ID('wb_dev') IS NULL CREATE LOGIN wb_dev WITH PASSWORD = '$DEVPW', CHECK_POLICY = OFF; ALTER SERVER ROLE dbcreator ADD MEMBER wb_dev;"
    printf 'SQL_SERVER=localhost,1433\nSQL_USER=wb_dev\nSQL_PASSWORD=%s\n' "$DEVPW" > "$DEVENV"
    chown "$USER_NAME:$USER_NAME" "$DEVENV"; chmod 600 "$DEVENV"
  fi
  echo "SQL Server ready. Login for Desktop/tools: see $DEVENV (synthetic data only)."
fi

log "root setup finished"
