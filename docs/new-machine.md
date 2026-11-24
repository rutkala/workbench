# New machine and new client: step by step

## A. Set up a PC (once per PC)

Works for both scenarios:
- **Client PC** (the client provides a laptop): one workbench, that client's repos only.
- **Own PC** (several smaller clients): one workbench, several client repos under `clients/`.

1. **Prerequisites:** Windows 10/11 with WSL 2 (`wsl --status` works) and Git for Windows. No admin rights needed.
2. **Get the workbench:** `git clone <your private GitHub URL> C:\Dev\workbench`. The path must not contain spaces.
3. **Run the bootstrap** in a normal PowerShell:
   ```
   powershell -ExecutionPolicy Bypass -File C:\Dev\workbench\framework\setup\bootstrap.ps1
   ```
   - Asks for a Linux user name and password. **Keep the password to yourself.** When the Linux prompt appears, type `exit`.
   - Takes 15–30 minutes (downloads, including SQL Server).
   - Ends with an isolation check. It must say `RESULT: isolated`.
   - Options: `-Distro <name>` (default `workbench`), `-NoSql` (skip SQL Server), `-Reconfigure` (re-run on an existing distro after framework updates).
4. **Start Claude:** `wsl -d workbench`, then `claude`, and log in. The first time, check `/sandbox` shows the sandbox as enabled.

## B. Add a client repo (once per client workspace family)

One repo per Fabric solution. Its DEV/UAT/PROD workspaces are the branches `dev`/`uat`/`prod` of that one repo.

**If the client's DevOps repo exists:**
1. **You, on Windows:** `git clone <DevOps repo URL> C:\Dev\workbench\clients\<name>`. Your DevOps login stays in Windows.
2. **Claude or you, in WSL:**
   ```
   /work/framework/client/new-client.sh <name> --adopt --dev-server <DEV SQL endpoint host> --database <db> --term "<Client name>"
   ```
   This adds the client files that are missing, the data guard, the `localhost` connection filter, and registers the client terms for the generic-repo guard.

**If you start from scratch:**
1. Run `new-client.sh <name> --dev-server ... --database ... --term ...` (without `--adopt`). It creates the repo with branch `dev`.
2. **You, on Windows:** `git -C C:\Dev\workbench\clients\<name> remote add origin <DevOps repo URL>`, then push.

**Then in Fabric (you):** connect each workspace to the repo. *Workspace settings → Git integration*, with DEV → `dev`, UAT → `uat`, PROD → `prod`, folder `fabric`.

## C. Power BI Desktop on the synthetic database

- Server `localhost`, the database name as in the model, **Database** authentication. The login is in WSL: `cat ~/.config/workbench/sql.env`.
- If Desktop warns about encryption (the local server uses a self-signed certificate), accept the unencrypted local connection. It's local and synthetic only.
- Before refreshing: *Transform data → Manage parameters*, `Server` must be `localhost`.

## D. Updating the framework on a PC

1. `git pull` in `C:\Dev\workbench` (Windows).
2. Re-run the bootstrap with `-Reconfigure`.

## E. Safety checklist

- [ ] Real data files never go anywhere under `C:\Dev\workbench`.
- [ ] The Linux password is never typed into a Claude session.
- [ ] Pushes happen only from Windows, by you.
- [ ] `check-isolation.sh` says `RESULT: isolated` (run any time: `bash /work/framework/setup/check-isolation.sh`).
