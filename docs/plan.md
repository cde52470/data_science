# Plan: CPBL Unsupervised Feature Discovery Notebook (2023+2024)

## Context

The senior **王學長** analysed only the **2024** CPBL regular season on the
`cde52470/data_science@analyze_wang` branch, using rule-based semantic
labels and supervised models (logistic / Random Forest / XGBoost + SHAP).
His cross-model consensus top-10 features were:

> `run_per_hit`, `innings_pitched`, `H`, `scored_first`, `whip_like`,
> `hr_allowed`, `hits_allowed`, `AB`, `middle_runs`, `late_runs`.

This plan delivers **one Python notebook** that

1. Pre-processes the rebas.tw raw CPBL OpenData for **both 2023 and 2024**,
2. Produces **descriptive statistics + EDA visualisations**, and
3. Discovers features via **unsupervised learning only** (filter / PCA / clustering
   / dim-reduction), then cross-checks the result against Wang's supervised list.

All methods come from the 10 files in `data_science_final_project/course-material/`
(now in our knowledge base — next section) plus established practice when the
lecture is silent. Karpathy-Skills principles apply throughout
(Think Before Coding · Simplicity First · Surgical Changes · Goal-Driven).

---

## Knowledge Base (built ✅)

10 Markdown KB entries, **4,556 lines total**, in `/tmp/course-material-kb/`:

| KB file | Topic | Lines | What we'll actually use |
|---|---|---|---|
| `Application_of_Machine_Learning_Models_for_Basebal.md` | Lo et al. 2025 paper on rebas CPBL | 423 | Sabermetric prior features (wRC+, WHIP, FIP, wRAA…); overlap with Wang's list. |
| `topic03_measurement_1.md` | Evaluation metrics — overview | 269 | Cluster-validity terminology; prevalence-aware metric choice. |
| `topic03_measurement_3.md` | Evaluation metrics — Practical-DS-with-R angle | 519 | Silhouette, Calinski–Harabasz, NMI; "r=0.8 still 36% unique" caveat. |
| `topic05-1_PCA-SVD.md` | PCA / SVD | 250 | `sklearn.decomposition.PCA`, scree, biplot, loadings narrative. |
| `topic05-2_featureExplain.md` | LIME / SHAP / PDP | 276 | PCA loadings as cheap Shapley; surrogate-Tree-SHAP for cluster naming. |
| `topic05_featureReduction.md` | Feature selection + extraction | 347 | Filter → embedded → PCA order; Lasso/RFECV cross-vote. |
| `topic06_visualization.md` | Visualisation catalogue | 605 | Small multiples, Spearman heatmap, UMAP + cluster + radar. |
| `topic07_data.md` | Data handling / preprocessing | 817 | `pd.json_normalize`, `ColumnTransformer`, RobustScaler, missing indicators. |
| `topic08_unsupervised.md` | **Unsupervised learning (core)** | 746 | k-Means / Ward / GMM / HDBSCAN; sil + CH + DBI + bootstrap-Jaccard ≥ 0.75. |
| `topic09_supervised1_mem.md` | kNN / Naive Bayes / distance | 304 | Mahalanobis = Euclidean on PCA-whitened data; scaling discipline. |

The KB lives outside the repos and is not part of the deliverable — it
is consulted while writing the notebook.

---

## Graphify status

- Skill **installed**: `~/.claude/skills/graphify/SKILL.md` registered;
  `/graphify` appears in the available-skills list.
- Extraction **blocked**: the anthropic SDK invoked by `graphify extract`
  needs `ANTHROPIC_API_KEY` as an `x-api-key`. This sandbox only exposes a
  Claude-Code OAuth file-descriptor, which the SDK rejects with HTTP 401.
- Workaround if you later provide a key:
  `ANTHROPIC_API_KEY=sk-… graphify extract /home/user/data_science_final_project/course-material --backend claude`
- **Not blocking** — the per-file KB above gives equivalent coverage for
  guiding the notebook.

---

## Data sources (all local, no network needed)

- **2023 raw JSON** — fully present in
  `data_science_final_project/data/raw/`:
  - `CPBL-2023-G1-G150-OpenData/` (151 files, regular-season G1–G150)
  - `CPBL-2023-G151-G300-OpenData/` (regular-season G151–G300)
  - `CPBL-2023-Challenge-OpenData/` (postseason challenge)
  - `CPBL-2023-TaiwanSeries-OpenData/` (Taiwan Series)
- **2024 raw JSON** — `cde52470/data_science@origin/analyze_wang`
  at `data/raw/CPBL-2024-OpenData/CPBL-2024-OpenData.json`. The branch is
  already fetched locally; read it via
  `git -C /home/user/data_science show origin/analyze_wang:data/raw/CPBL-2024-OpenData/CPBL-2024-OpenData.json`
  (read-only, no checkout).
- **rebas schema** — six nested tables documented under
  `cde52470/data_science@analyze_wang` and the rebas-tw upstream repo:
  game / batterBox / pitcherBox / PA / event / runner.

---

## Files to create or touch

| Action | Path | Notes |
|---|---|---|
| **Create** | `data_science_final_project/python/cpbl_unsupervised_feature_discovery.ipynb` | the deliverable |
| **Copy (identical)** | `data_science/python/cpbl_unsupervised_feature_discovery.ipynb` | dual-push (per user) |

No other files added — no helper modules, no README, no PNG exports, no
intermediate CSVs (figures stay inline in the notebook outputs).
`~/.claude/CLAUDE.md` was already written by `graphify install`; leave it alone.

---

## Reuse from 王學長 (port R → Python)

Source files on `cde52470/data_science@origin/analyze_wang`:

| Function (Wang) | Port target (this notebook) | Behaviour |
|---|---|---|
| `clean_games.py::sum_scores`, `sum_batter_stat` | reused verbatim | sum inning scores; aggregate batterBox stat |
| `share_analyze/01_build_team_game_features.R::build_team_game_base` | Python `build_team_game_base()` | 1 game → 2 team-game rows |
| `…::add_game_result_labels` | Python `add_game_result_labels()` | run_diff_label, scoring_level |
| `…::add_game_flow_features` | Python `add_game_flow_features()` | early/middle/late_runs, scored_first, led_after_3/6, game_flow_label |
| `…::add_offense_features` | Python `add_offense_features()` | H/AB/BB/SO/2B/3B/HR, run_per_hit, offense_pressure_score |
| `…::add_defense_pitching_features` | Python `add_defense_pitching_features()` | IPOuts→IP, whip_like, strikeout_walk_ratio, run_prevention_score |
| `share_analyze_md/feature_dictionary.md` | consulted for definitions | — |

---

## Cell convention (every code cell)

EVERY code cell is preceded by a Markdown cell with three labelled sections,
in this exact order and bracket style:

```markdown
### N.M — <short cell title>

**【目標 What?】** One sentence: what this cell will compute or produce.

**【說明 How to implement?】** 1–3 lines: key functions / parameters /
which KB topic the recipe comes from.

**【解釋結果 Why? How to explain the result】** How to read the upcoming
output: what we expect, what would be surprising, how it answers the
stage's research question.
```

For non-trivial findings, an OPTIONAL Markdown cell may follow the output
with **【後續觀察 Observations】** to record actual interpretation after
seeing the result.

---

## Output handling — inline-only by default, one-click bundle export

All tables and figures **render inline** in the notebook outputs — no PNG,
CSV, or other side-files are written by default. A single global registry
tracks every artifact that *could* be exported:

```python
DOWNLOAD_ALL = False        # flip to True in the final cell to export
ARTIFACTS: list[dict] = []  # each: {"name", "kind", "payload"}

def show_and_track(obj, name: str, kind: str = "figure"):
    """Render inline AND register for optional export."""
    ARTIFACTS.append({"name": name, "kind": kind, "payload": obj})
    return obj
```

- Every `plt.show()` / figure return goes through
  `show_and_track(fig, "stage3_spearman_heatmap.png")`.
- Every summary `DataFrame` displayed goes through
  `show_and_track(df, "stage2_describe_per_team.csv", kind="table")`.
- Naming convention: `stage{N}_{snake_case}.{png|csv}`.

**Stage 6 — Export switch** (final cell of the notebook):

- `DOWNLOAD_ALL = False` (default): print the artifact registry as a
  pandas table — names + kinds only; **nothing written to disk**.
- `DOWNLOAD_ALL = True`: write each artifact to
  `/tmp/cpbl_artifacts/`, zip to `/tmp/cpbl_artifacts.zip`, and emit an
  `IPython.display.FileLink` for one-click download.

This keeps the committed `.ipynb` self-contained and reproducible
(Karpathy "Simplicity First" — no surprise side-effects) while still
enabling export when the user flips the flag.

---

## Notebook structure (single `.ipynb`, ~30–50 cells)

Each stage opens with a Markdown cell stating **goal · KB citation · success
criterion**, ends with a check cell that asserts the criterion.

### Stage 0 — Setup
- Imports (`pandas`, `numpy`, `scikit-learn`, `hdbscan`, `umap-learn`,
  `matplotlib`, `seaborn`, `scipy`, `plotly` optional), version print,
  `RANDOM_STATE = 42`.
- Helper to load 2024 JSON via `git show` (no checkout).
- **Define `DOWNLOAD_ALL = False`, `ARTIFACTS = []`, and the
  `show_and_track(obj, name, kind)` helper** described above.
- Karpathy-style success-criteria checklist for all stages.

### Stage 1 — Preprocessing  *(KB ← `topic07_data`, Wang)*
1. Load 2023 JSON (4 release dirs) and 2024 JSON.
2. `pd.json_normalize` → tidy DataFrames (game, batterBox, pitcherBox, PA),
   IDs cast to `string`.
3. Season tag `2023 | 2024`.
4. Build team-game rows + Wang's derived features (ported above).
5. Quality report: missing-rate, dtypes, duplicates, n per season.
6. `ColumnTransformer`: median impute + `*_was_missing` indicator;
   `RobustScaler` for heavy-tailed pitching rates, `StandardScaler` for symmetric counts.

### Stage 2 — Descriptive Statistics  *(KB ← `topic03_*`, `topic07`)*
1. `.describe()` slices: overall, per season, per team, home / away.
2. Explicit base rates for binary features (`scored_first`, `win`).
3. **Both** Pearson r and Spearman ρ vs `run_diff` / `win`, plus R².
4. Skew, kurtosis, missing-rate table.

### Stage 3 — EDA  *(KB ← `topic06_visualization`)*
1. Small-multiples 2×5 FacetGrid: histogram + KDE of Wang's 10 features;
   season as hue (split-violin overlay).
2. Masked Spearman correlation heatmap (diverging palette).
3. Pairplot of top-5 features, hue = `win`.
4. Home/away mean comparison, 2023 vs 2024 (grouped bar).
5. Monthly trajectory of feature means, seasons overlaid (line chart).
6. ECDF panels for the 10 features (skew-tolerant view).
7. Calendar / weekly heatmap of game counts per stadium.
8. Win-rate by team bar chart (sorted), home vs away breakdown.
9. Hexbin: `H` vs `run_diff` (over-plotting safe) per season.
10. Per-team violin of top features (game-archetype previewing).

### Stage 4 — Unsupervised Feature Discovery  *(KB ← `topic05-1`, `topic05`, `topic05-2`, `topic08`, `topic09`)*
1. **Filter pruning**: variance threshold + drop one of each |Spearman ρ| ≥ 0.95 pair (keep 0.7–0.95).
2. **Standardise** (RobustScaler heavy-tailed; StandardScaler else).
3. **PCA**: scree + cumulative-PVE line; loadings heatmap.
3a. **PCA biplot** PC1–PC2 with feature-name arrows (matplotlib quiver),
    hue = `scored_first` / season.
3b. **Loadings narrative table** → PC axes labelled (PC1 = offense intensity, etc.).
3c. **3-D PCA scatter** (optional plotly) coloured by season — eye-catching view.
4. **Multi-algorithm clustering** on PC scores AND raw standardised:
   - K-Means with elbow + silhouette + CH for k ∈ {2…10} (panel of 3 metric plots)
   - Ward agglomerative + dendrogram + cophenetic
   - GMM with BIC vs k plot; retain soft probabilities
   - HDBSCAN (auto-k, noise allowed); condensed-tree visual
5. **Validity panel** per (algo, k): silhouette + Calinski-Harabasz +
   Davies-Bouldin + **bootstrap-Jaccard ≥ 0.75** (clusterboot-style)
   — render as a heat-table.
5a. **Per-point silhouette diagnostic** (yellowbrick-style horizontal bars)
    for the chosen final algorithm.
6. **UMAP 2-D scatter** coloured by chosen `cluster_id` and by season —
   the headline pair.
6a. **t-SNE 2-D scatter** alongside UMAP as a sanity check (different
    perplexity → topology comparison panel).
7. **Cluster interpretation**:
   - cluster mean ± SD table across all features
   - cluster-mean radar / parallel-coordinates
   - per-cluster feature boxplot grid
   - surrogate one-vs-rest classifier + Tree-SHAP → baseball-archetype labels
     (e.g., "pitcher duel", "front-running offense", "late-rally bullpen").
8. **2023 vs 2024 cluster-frequency shift** — grouped bar + alluvial/Sankey
   (plotly) of cluster-membership flow if seasons share IDs.
9. **Discovered-feature register** (in-memory df columns):
   `cluster_id`, GMM soft probs, top PCA scores.

### Stage 5 — Synthesis
- Overlap table: unsupervised-discovered features ↔ Wang's 10.
- Newly proposed candidate features (justified by loadings/cluster centroids).
- Honest caveats (no supervised validation in this scope; sample size).

### Stage 6 — Export switch  *(the FINAL cell of the notebook)*
- Print the full `ARTIFACTS` registry as a pandas table (name + kind + index).
- `if DOWNLOAD_ALL is False:` exit gracefully — no files written.
- `if DOWNLOAD_ALL is True:`
  1. `os.makedirs("/tmp/cpbl_artifacts", exist_ok=True)`
  2. Iterate `ARTIFACTS`: `fig.savefig(...)` or `df.to_csv(...)`.
  3. `shutil.make_archive("/tmp/cpbl_artifacts", "zip", "/tmp/cpbl_artifacts")`.
  4. `display(FileLink("/tmp/cpbl_artifacts.zip"))` — one-click download.
- A preceding Markdown cell explains the toggle and lists every artifact name
  so the user knows what they'll receive before flipping the flag.

---

## Verification

1. `jupyter nbconvert --to notebook --execute` succeeds end-to-end (no errors).
2. **Cell-convention compliance**: every code cell is preceded by a Markdown
   cell containing the three bracketed sections
   (`【目標 What?】`, `【說明 How to implement?】`, `【解釋結果 …】`) —
   automated grep on the saved notebook JSON.
3. Every stage prints ≥ 1 summary table AND renders ≥ 1 figure.
4. **Total figures ≥ 15** across the notebook (EDA + unsupervised).
5. Cluster validity table shows silhouette ≥ 0.25 AND bootstrap-Jaccard ≥ 0.75
   for the chosen final algorithm.
6. **Corroboration check** — at least 6 of Wang's 10 consensus features
   appear with high |loading| on PC1+PC2 (printed assertion in Stage 4.3).
7. **Output-handling check**:
   - With `DOWNLOAD_ALL = False` (default), executing Stage 6 writes nothing
     to disk and only prints the registry.
   - With `DOWNLOAD_ALL = True`, `/tmp/cpbl_artifacts.zip` exists and the
     `FileLink` is displayed.
8. Notebook file size < 50 MB (inline figures only; no embedded data dumps).

---

## Deployment

Both repos are already cloned at `/home/user/`. For **each** repo:

```
git -C <repo> fetch origin <branch>
git -C <repo> checkout <branch>           # NO -b; existing branch only
cp /workspace/notebook.ipynb <repo>/python/cpbl_unsupervised_feature_discovery.ipynb
git -C <repo> add python/cpbl_unsupervised_feature_discovery.ipynb
git -C <repo> commit -m "Add CPBL 2023+2024 unsupervised feature-discovery notebook"
git -C <repo> push -u origin <branch>     # retry ≤ 4× exponential backoff on transient
```

| Repo | Branch |
|---|---|
| `jiangjiangian/data_science_final_project` | `feature-engineering` |
| `cde52470/data_science` | `data-analysis` |

**No new branches. No PR.** (Per user instruction.)
If `data_science/python/` directory doesn't exist on `data-analysis`, create it
(directory creation ≠ branch creation, so allowed).

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| 2023 vs 2024 JSON schema drift | Validate intersection; print a column-diff report; drop union-only fields. |
| Some 2023 games missing pitcher box | `*_was_missing` indicator (KB ← topic07). |
| `hdbscan` / `umap-learn` not pre-installed | Cell 0 runs `%pip install hdbscan umap-learn` quietly. |
| Notebook runtime > 5 min on full data | Cache cleaned dataframe in memory; bootstrap-Jaccard with B=100 (not 1000). |
| Graphify still wanted | Optional follow-up once `ANTHROPIC_API_KEY` is provided; KB is sufficient. |
| Karpathy "Surgical Changes" | Touch only the new notebook in each repo; do not modify `cpbl_pregame_winprob.ipynb`, `agents/`, `course-material/`, `share_analyze/`, etc. |
