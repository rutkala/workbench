# Workbench

Generic framework for Power BI / Fabric delivery with Claude Code as engineer, on synthetic data, in an isolated WSL environment.

```
workbench/                 generic repo (this one)
├─ CLAUDE.md               generic rules for Claude
├─ framework/
│  ├─ setup/               bootstrap.ps1 (Windows) + WSL scripts
│  ├─ client/              new-client.sh
│  └─ git/                 pre-commit guards (generic repo / client repos)
├─ docs/                   how we work, new machine guide
└─ clients/                ignored here; one git repo per client workspace family
```

- New PC: see `docs/new-machine.md`.
- How a feature goes from idea to Fabric: `docs/delivery-guide.md`.
