# `.claude/agents/` — CPBL Sub-Agent Index

This folder contains six Claude Code sub-agents, one per data-science
lifecycle step, plus this index. They are **gitignored** so AI runtime
files never reach the public repo.

## How to invoke

In Claude Code (CLI or Desktop):

```text
@goal-definer    please draft Results/01_define_the_goal.md
@data-collector  run the 2023-10 POC then the full window
@eda-explorer    knit reports/01_EDA_Patterns.Rmd
@model-builder   run Phase A; if OK, run Phase B
@model-evaluator load m1_to_m7_workflow_results.rds and write the verdict
@shiny-deployer  build app/ and ship to shinyapps.io
```

In **claude.ai / web** (this surface), you can paste the *Polished XML
Prompt* section from any agent file into a fresh conversation — every
agent file is self-bootstrapping.

## Inventory

| # | File | Frontmatter `name` | Model | Role |
|---|---|---|---|---|
| 1 | `01-goal-definer.md` | `goal-definer` | opus | Charter + success thresholds + risk register |
| 2 | `02-data-collector.md` | `data-collector` | sonnet | CPBL + CWA crawler with provenance |
| 3 | `03-eda-explorer.md` | `eda-explorer` | sonnet | Park Factor, PCA, missingness, weather × runs |
| 4 | `04-model-builder.md` ⭐ | `model-builder` | opus | **Phase A POC → Phase B `tidymodels` production** |
| 5 | `05-model-evaluator.md` | `model-evaluator` | opus | Confusion / calibration / SHAP / fairness |
| 6 | `06-shiny-deployer.md` | `shiny-deployer` | sonnet | `bslib` dashboard + deploy |

## Hand-off contract

```
goal-definer ──▶ Results/01_define_the_goal.md
                        │
                        ▼
data-collector ──▶ data/raw/raw_games.csv
                   data/raw/raw_weather.csv
                   data/raw/_provenance/manifest.json
                        │
                        ▼
eda-explorer ────▶ data/processed/park_factors.rds
                   data/processed/weather_pca_loadings.csv
                   reports/01_EDA_Patterns.html
                        │
                        ▼
model-builder ───▶ models/poc/poc_results.rds           ← Phase A
                   models/m1_to_m7_workflow_results.rds  ← Phase B
                   models/finalized/top_*.rds
                   models/_manifest.json
                        │
                        ▼
model-evaluator ─▶ Results/eval/_selection.json
                   Results/figures/* (ROC, conf, calib, SHAP, DCA)
                   Results/05_model_evaluation.md
                        │
                        ▼
shiny-deployer ──▶ app/app.R
                   Dockerfile + renv.lock
                   Results/06_deployment.md
```

Each downstream agent **must** consume only the documented hand-off
files. No reaching upstream into earlier agents' working notes.

## Skills installed in this repo

| Skill | Where | Purpose |
|---|---|---|
| `find-skills` | `.claude/skills/find-skills/SKILL.md` | Search & install further skills via `npx skills find <query>` |

Future installs (suggested):

```bash
# inside Claude Code, ask: "find me a skill for <X>"
npx skills find tidymodels
npx skills find shiny-best-practices
npx skills find shap
npx skills find rvest-scraping
```

## MCP servers in use

| Server | Scope | Notes |
|---|---|---|
| GitHub MCP (`mcp__github__*`) | `cde52470/data_science` only | PR creation, commits, file pushes |
| (others may attach during a session) | — | List via ToolSearch |

## Conventions inherited from `CLAUDE.md`

- Tidyverse Style Guide.
- `here::here()` for paths; no `setwd()`.
- Secrets via `.Renviron`; never hard-coded.
- 繁體中文 narrative comments; English code.
- Time-aware splits on game data — never `initial_split()`.
- All AI runtime files (this folder, `CLAUDE.md`, etc.) **gitignored**.
