<#
  Workbench bootstrap: turns this PC into an isolated Claude workbench.
  Run in a normal (non-admin) PowerShell, from the cloned workbench repo:

    powershell -ExecutionPolicy Bypass -File <workbench>\framework\setup\bootstrap.ps1 [-Distro workbench] [-NoSql] [-Reconfigure]

  Result:
   - WSL distro (default name "workbench") that sees ONLY this workbench folder (at /work).
   - No Windows drives, no Windows programs, no cached sudo, enforced Claude Code settings.
   - Tools: git, Node 22, .NET 8, Python, sqlcmd, report authoring CLI, Claude Code.
   - Synthetic SQL Server 2022 (Fabric collation) on localhost:1433 (skip with -NoSql).
   - Git guards for the generic repo (no client content) and for client repos (no data files).
  Scenario 1 (client PC): run once on that PC. Scenario 2 (own PC, several clients): run once; add clients with new-client.sh.
#>
param(
  [string]$Distro = 'workbench',
  [switch]$NoSql,
  [switch]$Reconfigure
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Say($m, $c = 'Cyan') { Write-Host "`n=== $m ===" -ForegroundColor $c }
function Get-Distros { (wsl -l -q) -replace "`0", '' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
function To-WslPath($p) { '/mnt/' + $p.Substring(0,1).ToLower() + ($p.Substring(2) -replace '\\','/') }

if ($Root -match '\s') { throw "The workbench path must not contain spaces: $Root" }
if (-not (Test-Path (Join-Path $Root 'framework\setup\wsl-root.sh'))) { throw "Run this script from inside the workbench repo." }
try { wsl --status | Out-Null } catch { throw "WSL is not available on this PC." }
$sql = if ($NoSql) { 'nosql' } else { 'sql' }

Say "Windows side: git settings for the workbench repo"
Push-Location $Root
if (-not (Test-Path .git)) { git init -q -b main; Write-Host "  initialised git repo" }
git config core.autocrlf true
git config core.filemode false
git config core.hooksPath framework/git/hooks
New-Item -ItemType Directory -Force clients | Out-Null
if (-not (Test-Path clients\.client-terms)) { "# one term per line; never committed (clients/ is ignored)" | Out-File -Encoding ascii clients\.client-terms }
Pop-Location

$exists = (Get-Distros) -contains $Distro
if ($exists -and -not $Reconfigure) { throw "WSL distro '$Distro' already exists. Re-run with -Reconfigure to update it, or choose another -Distro name." }

if (-not $exists) {
  Say "Step 1/5: install Ubuntu 24.04 as '$Distro'"
  Write-Host "Choose a Linux user name and a password. Keep the password to yourself (Claude must never know it)."
  Write-Host "When you see the Linux prompt (ending with `$), type: exit" -ForegroundColor Yellow
  wsl --install Ubuntu-24.04 --name $Distro
  if (-not ((Get-Distros) -contains $Distro)) { throw "Install did not finish." }
} else {
  Say "Reconfigure: temporarily re-enabling drive access to run the setup" 'Yellow'
  wsl -d $Distro -u root -- bash -c "sed -i 's/^enabled=false/enabled=true/' /etc/wsl.conf"
  wsl --terminate $Distro; Start-Sleep 2
}

$User = ((wsl -d $Distro -- whoami) -replace "`0", '').Trim()
if (-not $User -or $User -eq 'root') { throw "Could not detect your Linux user." }
Write-Host "Linux user: $User"

Say "Step 2/5: tools, isolation, enforced settings$(if(-not $NoSql){', SQL Server'}) (as root; takes a while)"
$rootScript = (To-WslPath $Root) + '/framework/setup/wsl-root.sh'
wsl -d $Distro -u root -- bash $rootScript $User ($Root -replace '\\','/') $sql
if ($LASTEXITCODE -ne 0) { throw "Root setup failed. Copy the last lines and tell Claude." }

Say "Step 3/5: restart '$Distro' so isolation takes effect"
wsl --terminate $Distro; Start-Sleep 3

Say "Step 4/5: user tools and Claude Code (as $User)"
wsl -d $Distro -- bash /work/framework/setup/wsl-user.sh
if ($LASTEXITCODE -ne 0) { throw "User setup failed. Copy the last lines and tell Claude." }

Say "Step 5/5: isolation check"
wsl -d $Distro -- bash /work/framework/setup/check-isolation.sh

Say "Done" 'Green'
Write-Host "Start working:  wsl -d $Distro   then   claude        (log in the first time)"
Write-Host "New client:     inside WSL:  /work/framework/client/new-client.sh <name> --dev-server <host> --database <db> --term <client name>"
if (-not $NoSql) { Write-Host "Desktop login for the synthetic SQL Server: inside WSL run  cat ~/.config/workbench/sql.env" }
