# Workbench: generic rules for Claude Code

This repo is the generic framework (personal GitHub). Client work lives in `clients/<name>/` (separate git repos, ignored here).
When started inside a client folder, Claude also loads that client's CLAUDE.md, which adds client rules.

## Roles
- The owner is product owner: decides, checks results in Power BI Desktop, pushes, merges, syncs Fabric, promotes.
- Claude is the engineer: model (TMDL/DAX), report (PBIR), SQL/notebooks, synthetic data, tests, docs.
- Present decisions as short options with a recommendation. At most 2–3 to-dos for the owner per request.

## Environment (enforced, do not try to work around)
- Claude runs in an isolated WSL distro. Only the workbench folder is visible (`/work`).
- No credentials for Azure, Fabric, Power BI Service, Azure DevOps or GitHub. Never install `az`/`fab`, never sign in, never push, never call client APIs.
- Enforced settings: `/etc/claude-code/managed-settings.json` (root-owned).

## Data
- Only metadata (TMDL, PBIR, SQL, DAX) and synthetic data. Real data never enters `/work`.
- If you notice a file that may hold real data (`.pbix`, `cache.abf`, exports), stop and tell the owner.

## Separation (strict)
- Generic repo (`/work`): no client names, hosts, workspace/item IDs, data, or client decisions. A pre-commit hook checks this.
- Client repos (`/work/clients/<name>`): everything client-specific, including client docs.
- Lessons move from a client to the framework only via an anonymised "promote" step the owner approves.

## Git
- Client repos: branches `dev`, `uat`, `prod` (synced to the Fabric workspaces by the owner). Claude works on `feature/<name>` from `dev`; never commits to `dev`/`uat`/`prod`; never pushes.
- One logical change per commit. At the end of a feature: summary + PR description.
- One of us works at a time in a folder; start with a clean `git status`.

## Fabric parity
- Everything built locally must run on Fabric unchanged: Fabric Warehouse T-SQL subset and data types, same object names, case-sensitive UTF-8 collation (the local SQL Server uses `Latin1_General_100_BIN2_UTF8`).
- Validate warehouse SQL with a SQL database project targeting Fabric Data Warehouse before handing over.
- Semantic models read `Server`/`Database` parameters; the `fabricconn` git filter keeps the real DEV host in git and `localhost` locally.

## Tools in the workbench
- Synthetic SQL Server: `localhost,1433`, login in `~/.config/workbench/sql.env`.
- `sqlcmd`, `dotnet` (SQL projects), `node` + `powerbi-report-author` (PBIR validation only), Python.
- New client repo: `framework/client/new-client.sh`.
