# CLAUDE.md — CPBL Analytics Project Memory

> **Purpose:** Shared project context for any Claude session (Code, web, or
> Desktop) working on the **中職主客場勝率預測 (CPBL Home/Away Win Prediction)**
> project. This file is **gitignored** so AI runtime artefacts stay off the
> remote repo. See `.gitignore` for the full exclusion list.

---

## 1. Project Snapshot

| Item | Value |
|---|---|
| **Domain** | 中華職棒 (CPBL) 賽事預測 / Sports analytics |
| **Task** | Binary classification — `is_home_win` ∈ {0, 1} |
| **Drivers** | Park Factor × Home Advantage × Weather |
| **Language** | R (Tidyverse, `tidymodels`, `shiny`, `bslib`) |
| **Data sources** | 野球革命 (Rebas) JSON, CPBL 官網 (`rvest`), 中央氣象署 CWA Open Data API |
| **Constraint** | ❌ NO Kaggle / NO pre-bundled datasets |
| **Final artefact** | R Shiny dashboard with daily prediction + EDA + model comparison |
| **Dev branch** | `claude/install-skills-setup-eUMPo` |
| **Remote** | `cde52470/data_science` |

---

## 2. The 7 Progressive Models (m1 → m7)

Ablation study to quantify each feature group's contribution.

| Model | Formula (target `is_home_win`) | Role |
|---|---|---|
| **m1** | `~ 1` (intercept only) | Baseline — captures pure home-field advantage in a home-team-centric dataset |
| **m2** | `~ stadium_factor` | Stadium-only |
| **m3** | `~ temperature + humidity + wind_speed` | Weather-only |
| **m4** | m1 features + stadium | Home × Stadium |
| **m5** | m1 features + weather | Home × Weather |
| **m6** | stadium + weather | Stadium × Weather |
| **m7** | **stadium + weather (full)** | Full model |

> Because every row is encoded from the home team's perspective, "home/away"
> is folded into the intercept (m1). m1 is therefore the apples-to-apples
> baseline that m2-m7 must statistically beat.

---

## 3. Six-Agent Lifecycle

This repo hosts six specialised sub-agents under `.claude/agents/`,
mirroring the data-science lifecycle:

```
┌───────────────────────────────────────────────────────────────┐
│  1. Goal Definer  ──▶  2. Data Collector  ──▶  3. EDA         │
│         │                                          │           │
│         ▼                                          ▼           │
│  6. Shiny Deployer ◀── 5. Evaluator ◀──── 4. Model Builder    │
└───────────────────────────────────────────────────────────────┘
```

| # | Agent file | One-line job |
|---|---|---|
| 1 | `01-goal-definer.md` | Lock the business question, target, success thresholds |
| 2 | `02-data-collector.md` | Crawl CPBL + CWA, persist raw CSVs with provenance |
| 3 | `03-eda-explorer.md` | Park Factor, weather impact, PCA, missingness audit |
| 4 | `04-model-builder.md` | Two-phase POC → production `tidymodels` pipeline |
| 5 | `05-model-evaluator.md` | Confusion matrix, calibration, SHAP, fairness |
| 6 | `06-shiny-deployer.md` | `bslib` dashboard, inference UI, deploy guide |

Each agent file is **self-contained**: role definition, detailed workflow,
critical considerations, suitable skills/MCPs, and a polished XML prompt
that can be pasted into a fresh Claude session.

---

## 4. Directory Contract (Alignment)

```
data_science/
├── CLAUDE.md                        # this file (gitignored)
├── .gitignore                       # blocks AI files, data, models, secrets
├── .claude/                         # AI runtime (gitignored)
│   ├── agents/                      # 6 sub-agents
│   └── skills/                      # find-skills + future installs
├── data/
│   ├── raw/                         # read-only, gitignored
│   │   ├── raw_games.csv
│   │   └── raw_weather.csv
│   └── processed/                   # gitignored
│       ├── model_ready_data.csv
│       └── park_factors.rds
├── R/                               # reusable functions (committable)
│   ├── scrape_cpbl.R
│   ├── fetch_cwa.R
│   ├── compute_park_factor.R
│   └── helpers.R
├── scripts/                         # entry-point pipelines (committable)
│   ├── 01_collect_manage_data.R
│   ├── 02_explore_data.R
│   ├── 03_build_models.R
│   ├── 04_evaluate_models.R
│   └── 05_predict_today.R
├── models/                          # .rds outputs gitignored
├── reports/                         # *.Rmd source committable, *.html ignored
├── Results/                         # final figures (path-of-truth for sharing)
│   └── figures/
├── app/                             # Shiny
│   └── app.R
├── renv.lock                        # committable
├── requirements.R                   # fallback package list
├── data_science.Rproj
└── README.md
```

---

## 5. Variable Alignment (`alignment.md` spec)

| Symbol | Type | Description | Domain |
|---|---|---|---|
| `is_home_win` | factor {0,1} | Y — main target | 1 if `home_score > away_score`; ties dropped |
| `stadium` | factor | Stadium identifier | {臺北大巨蛋, 樂天桃園, 洲際, 台南, 新莊, 澄清湖, 嘉義} |
| `temperature` | numeric (°C) | Game-time temperature | typically 15-38 |
| `humidity` | numeric (%) | Game-time humidity | 30-100 |
| `wind_speed` | numeric (m/s) | Game-time wind | 0-15 |
| `wind_dir` | factor (optional) | 8-point compass | N/NE/E/.../NW |
| `date` | Date | Game date | ISO 8601 |
| `game_id` | character | Unique key | e.g. `20231015-G01` |

---

## 6. Code Conventions (enforced across all agents)

1. **Tidyverse Style Guide** (snake_case, ≤ 80 col, `<-` for assignment).
2. **`here::here()` for ALL paths** — never `setwd()` or absolute paths.
3. **Secrets** in `.Renviron`, loaded via `Sys.getenv("CWA_API_KEY")`. Never
   hardcode. `.Renviron` is gitignored.
4. **Reproducibility** — pin deps with `renv`; record session info at end of
   every script (`sessionInfo()` → `Results/session_info.txt`).
5. **Time-aware splits** — for any model touching time-series sports data,
   use `rsample::initial_time_split()` or `sliding_period()`. **Never**
   `initial_split()` (random) on game data.
6. **Comments in 繁體中文** for domain logic; English for code.
7. **`{logger}` package** for structured logs in long-running pipelines.

---

## 7. Skills & MCPs

| Tool | Where | Purpose |
|---|---|---|
| `find-skills` | `.claude/skills/find-skills/` | Discover further skills via `npx skills find <query>` |
| GitHub MCP | always available | Create PRs, push files, manage issues. Repo scope: `cde52470/data_science` only |

Each agent's frontmatter lists `tools:` and the body suggests skills/MCPs to
install when needed (use `find-skills` to discover them).

---

## 8. Git Policy (CRITICAL)

- **All work on:** `claude/install-skills-setup-eUMPo`
- **Never push** without explicit user approval ("Plz push"-style intent).
- **AI runtime files** (`CLAUDE.md`, `.claude/`, `.cursor/`, etc.) are
  gitignored — they **must not** appear on the remote.
- Open PRs as **draft**.
- Never use `--no-verify`, `--force` to `main`, or `git config` edits.

---

## 9. Environment Notes

| Where you are | Implication |
|---|---|
| **Anthropic sandbox VM** (this session) | Ephemeral; **R is not installed**; only `git push` makes work durable. |
| **Local RStudio Desktop** | Where R scripts actually execute; install deps via `renv::restore()`. |
| **Posit Cloud / RStudio Server** | Optional remote board for browser-based execution. |

---

## 10. How to Use a Sub-Agent

In Claude Code:

```
@01-goal-definer  please draft 01_define_the_goal.md
@04-model-builder run Phase A (POC) on data/raw/raw_games.csv
```

Or paste the **XML prompt section** from any
`.claude/agents/0X-*.md` file into a fresh Claude conversation — every
agent file is self-bootstrapping.
