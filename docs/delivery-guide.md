# How we work: from idea to Fabric

Plain-language guide for the owner (product owner). Claude is the engineer.

## 1. The big picture

- **Claude works in a closed room:** an isolated WSL distro that sees only `C:\Dev\workbench`. No other files, no logins, no real data.
- **One shared copy per client repo:** `C:\Dev\workbench\clients\<name>`. Claude edits and commits there from WSL. You check the result in Power BI Desktop and push from Windows.
- **Locally everything runs on synthetic data:** a local SQL Server with the same tables and names as the real warehouse.
- **You are the only one who talks to the outside world:** Azure DevOps, Fabric, the business.

```
 clients\<name>  (one shared copy)
   ▲ Claude: feature branch, commits     ▲ you: check in Desktop (synthetic) → git push (your login)
                                         ▼
                          Azure DevOps: feature → pull request → dev
                                         ▼
                          Fabric: DEV (git sync) → deployment pipeline → UAT → PROD
```

## 2. Words

| Word | Meaning |
|---|---|
| WSL | A Linux computer inside Windows; ours sees only the workbench folder. |
| Workbench repo | Generic framework, on your private GitHub. Never contains client content. |
| Client repo | One per Fabric solution; branches `dev`/`uat`/`prod` = DEV/UAT/PROD workspaces. |
| Feature branch | `feature/<name>`: one piece of work, created by Claude from `dev`. |
| Git filter (`fabricconn`) | Shows `localhost` in your files while git keeps the real DEV address. |
| Model parameters | `Server` and `Database` inside the model; all sources use them. |
| Deployment rule | Fabric deployment pipeline setting: "in UAT/PROD use this server". |
| Variable Library | Fabric's environment variables, for notebooks and pipelines. Semantic models can't read it yet. |

## 3. Why the git filter

- **The constraint:** Fabric loads exactly what's in `dev` into DEV. So git must hold the real DEV address.
- **Locally:** you and Claude must only ever connect to synthetic data. The filter swaps the address to `localhost` on checkout and back on commit.
- **UAT and PROD:** their addresses come from deployment rules.
- **Before refreshing in Desktop, check:** `Server` = `localhost`.

## 4. Everyday loop

| Step | Who | What |
|---|---|---|
| 1 | You | Describe what you want. |
| 2 | You | `git switch dev` then `git pull` in the client folder (Windows). |
| 3 | Claude | Creates `feature/<name>`, builds, tests on synthetic data, commits. Summary + PR description. Don't save in Desktop meanwhile. |
| 4 | You | Open the PBIP in Desktop and check it. |
| 5 | You | Not OK: tell Claude. OK: `git push -u origin feature/<name>`. |
| 6 | You | DevOps: PR → `dev`, merge. |
| 7 | You | Fabric DEV: *Source control → Update all*, refresh, check with real data. |
| 8 | You | Tell Claude the result. On errors, paste the error text only. |

If you change something yourself in Desktop: save and tell Claude, which commits it cleanly.

## 5. Promotion

1. Deployment pipeline: DEV → UAT. First time only: parameter rules for `Server`/`Database`.
2. UAT workspace: *Source control → Commit* (into `uat`).
3. Same for UAT → PROD.

## 6. Safety rules

1. No real data under `C:\Dev\workbench`.
2. Claude never gets passwords or logins, including your Linux password.
3. Check `Server` = `localhost` before a local refresh.
4. One of you works at a time in a folder.
5. Client content stays in client repos. Lessons reach the workbench only anonymised, after your approval.

## 7. If something goes wrong

| Situation | Action |
|---|---|
| Desktop shows real numbers locally | Stop; check `Server`; tell Claude (filter not active). |
| Many files "changed" that nobody touched | Line-ending settings; tell Claude. |
| DEV "Update from Git" conflict | Someone changed DEV directly; usually keep the git version. |
| DEV refresh fails after merge | Paste the error text; Claude fixes it on a new feature branch. |
| UAT/PROD shows DEV data | Deployment rule missing for that stage. |
| Generic repo commit blocked | The guard found client content; anonymise it or move it to the client repo. |
