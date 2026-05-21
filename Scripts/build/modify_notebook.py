"""Modify the optimized CPBL notebook with the 3 user-approved changes:
1. Pre-game feature gate + lag-feature engineering
2. Wang analyze_wang team_game_features.csv merge & compare
3. Multi-method K consensus + ANOVA/MI meaningful-features
"""
import nbformat
import textwrap

UPLOAD = '/root/.claude/uploads/cad06a4e-a255-443f-bbbd-04e533a80f6a/54ae2f85-cpbl_unsupervised_feature_discovery_optimized.ipynb'
OUT = '/tmp/cpbl_unsupervised_feature_discovery.ipynb'

nb = nbformat.read(UPLOAD, as_version=4)


def md(text):
    return nbformat.v4.new_markdown_cell(textwrap.dedent(text).strip("\n"))


def code(src):
    return nbformat.v4.new_code_cell(textwrap.dedent(src).strip("\n"))


def explain(n, title, what, how, why, follow=None):
    body = (
        f"### {n} — {title}\n\n"
        f"- **程式碼目標**：{what}\n"
        f"- **執行方式**：{how}\n"
        f"- **產出與解讀**：{why}"
    )
    if follow:
        body += f"\n- **與後續步驟的關聯**：{follow}"
    return md(body)


# ── 2.7a — Wang merge ─────────────────────────────────────────────────────
wang_md = explain(
    "2.7a", "對照 analyze_wang 學長的 team-game features",
    "從 analyze_wang 分支讀取 Wang 學長已產出的 team_game_features.csv，與本 notebook 重新建出的 `team_game` 在 (game_id, team) 上 left-merge，逐欄比較相等率與相關性。",
    "用 `git -C /home/user/data_science show origin/analyze_wang:data/cleaned/team_game_features.csv` 從本地 clone 讀檔，做 merge，計算數值欄位的相等率與 Pearson r，類別欄位的相等率，並把比較結果存到 `wang_merge_2024.csv`。Wang 只涵蓋 2024，所以比較只在 2024 subset 上做。",
    "若相等率 > 0.99 且 r > 0.99，代表本 notebook 對 Wang 的 R 邏輯移植正確；若有明顯落差，可早一步發現 port bug。",
    "比較表會在 Stage 6 的 feature catalog 附近被引用，作為 reproducibility note。",
)

wang_code = code(r"""
import subprocess
from io import StringIO

try:
    proc = subprocess.run(
        ["git", "-C", "/home/user/data_science",
         "show", "origin/analyze_wang:data/cleaned/team_game_features.csv"],
        capture_output=True, text=True, check=True,
    )
    wang_df = pd.read_csv(StringIO(proc.stdout))
    print(f"✓ 讀到 Wang 學長 team_game_features.csv：{len(wang_df)} rows × {wang_df.shape[1]} cols")
except Exception as e:
    print(f"⚠ 無法讀取 Wang 檔案：{e}")
    wang_df = pd.DataFrame()

wang_compare = pd.DataFrame()
wang_merge = pd.DataFrame()

if not wang_df.empty:
    common_keys = [k for k in ["game_id", "team"] if k in wang_df.columns and k in team_game.columns]
    if not common_keys:
        print("⚠ 找不到共同 key 欄位")
    else:
        wang_merge = team_game.merge(wang_df, on=common_keys, how="left", suffixes=("", "_wang"))
        wang_2024 = wang_merge[wang_merge["season_tag"] == "2024"].copy()
        common_cols = [c for c in wang_df.columns
                       if c in team_game.columns and c not in common_keys]
        rows = []
        for c in common_cols:
            a = wang_2024[c]
            b = wang_2024[f"{c}_wang"]
            both = a.notna() & b.notna()
            if both.sum() == 0:
                rows.append({"feature": c, "n_compared": 0,
                             "equality_rate": np.nan, "pearson_r": np.nan})
                continue
            try:
                eq = float((a[both].astype(str) == b[both].astype(str)).mean())
            except Exception:
                eq = np.nan
            try:
                r = float(pd.Series(a[both]).astype(float).corr(pd.Series(b[both]).astype(float)))
            except Exception:
                r = np.nan
            rows.append({"feature": c, "n_compared": int(both.sum()),
                         "equality_rate": round(eq, 4) if not pd.isna(eq) else np.nan,
                         "pearson_r":     round(r,  4) if not pd.isna(r)  else np.nan})
        wang_compare = pd.DataFrame(rows).sort_values("equality_rate", ascending=True)
        show_and_track(wang_compare, "stage2_wang_merge_comparison.csv", "table")
        show_and_track(wang_2024, "stage2_wang_merge_2024.csv", "table")
        display(Markdown("**對照結果（equality_rate 由低到高）**"))
        display(wang_compare)
        n_high = int((wang_compare["equality_rate"] >= 0.99).sum())
        print(f"\n比對欄位數：{len(wang_compare)}；equality_rate ≥ 0.99 的有 {n_high} 個 "
              f"⇒ 與 Wang 的 R port 對齊程度為 {n_high}/{len(wang_compare)}")
""")


# ── 2.7b — Pre-game lag features ──────────────────────────────────────────
pregame_md = explain(
    "2.7b", "建立 pre-game 滾動 lag features（避免 data leakage）",
    "對每支球隊依日期排序，計算最近 N 場（N=5、10）的 prior rolling 平均，並把對手的同類特徵 self-merge 進來。所有計算都用 `shift(1)` 後再 `rolling`，嚴格只看過去。",
    "Group by `team` + sort by `date`；對 runs_scored / runs_allowed / win / scored_first / H / BB / extra_base_hits / whip_like / strikeout_walk_ratio / late_runs / run_per_hit 等欄位計算 `prior_<col>_mean_{5,10}`；以及 `days_rest`、`day_of_week`、`season_to_date_*`、`h2h_prior_win_rate`、`stadium_prior_run_mean`；最後用 (opponent, date) self-merge 取得對手鏡像。",
    "新欄位代表「進場前可拿到的資訊」。每支球隊的最初 1–5 場 lag 會是 NaN（用 `pre_game_ready` 旗標標記），Stage 5 的 imputer 會把 NaN 補成中位數。",
    "Stage 5 的 PCA / clustering 在 gate=ON 時會只用這些 pre-game lag features。",
)

pregame_code = code(r"""
# Sort and build rolling lag features (past-only)
tg_sorted = team_game.sort_values(["team", "date"]).reset_index(drop=True)

LAG_COLS_RAW = ["runs_scored", "runs_allowed", "run_diff",
                "win", "scored_first", "H", "BB", "extra_base_hits",
                "whip_like", "strikeout_walk_ratio",
                "late_runs", "run_per_hit"]
LAG_WINDOWS = [5, 10]

for col in LAG_COLS_RAW:
    for w in LAG_WINDOWS:
        tg_sorted[f"prior_{col}_mean_{w}"] = (
            tg_sorted.groupby("team")[col]
                     .transform(lambda s: s.shift(1).rolling(w, min_periods=2).mean())
        )

# Rename to read more naturally for binary-rate features
for w in LAG_WINDOWS:
    tg_sorted.rename(columns={
        f"prior_win_mean_{w}": f"prior_win_rate_{w}",
        f"prior_scored_first_mean_{w}": f"prior_scored_first_rate_{w}",
    }, inplace=True)

# Days of rest and weekday
tg_sorted["days_rest"] = (
    tg_sorted.groupby("team")["date"]
             .transform(lambda s: (s - s.shift(1)).dt.days)
)
tg_sorted["day_of_week"] = tg_sorted["date"].dt.dayofweek

# Season-to-date (cumulative, past-only) win-rate and run-diff
tg_sorted["season_to_date_win_rate"] = (
    tg_sorted.groupby(["team", "season_tag"])["win"]
             .transform(lambda s: s.shift(1).expanding(min_periods=2).mean())
)
tg_sorted["season_to_date_run_diff_mean"] = (
    tg_sorted.groupby(["team", "season_tag"])["run_diff"]
             .transform(lambda s: s.shift(1).expanding(min_periods=2).mean())
)

# Head-to-head running win-rate (past games vs same opponent)
tg_sorted = tg_sorted.sort_values(["team", "opponent", "date"]).reset_index(drop=True)
tg_sorted["h2h_prior_win_rate"] = (
    tg_sorted.groupby(["team", "opponent"])["win"]
             .transform(lambda s: s.shift(1).expanding(min_periods=2).mean())
)
tg_sorted = tg_sorted.sort_values(["team", "date"]).reset_index(drop=True)

# Stadium prior run-scoring (past-only)
tg_sorted["stadium_prior_run_mean"] = (
    tg_sorted.groupby("stadium")["runs_scored"]
             .transform(lambda s: s.shift(1).expanding(min_periods=5).mean())
)

# Opponent mirror — merge opponent's lag block on (opponent, date)
opp_cols = [c for c in tg_sorted.columns
            if c.startswith("prior_") or c in {"season_to_date_win_rate",
                                                "season_to_date_run_diff_mean",
                                                "h2h_prior_win_rate",
                                                "stadium_prior_run_mean",
                                                "days_rest"}]
opp_view = tg_sorted[["team", "date"] + opp_cols].rename(columns={"team": "_opp_match"})
opp_view = opp_view.rename(columns={c: f"opp_{c}" for c in opp_cols})
tg_sorted = tg_sorted.merge(
    opp_view, left_on=["opponent", "date"],
    right_on=["_opp_match", "date"], how="left",
).drop(columns=["_opp_match"])

# Flag rows with all key lags populated
key_lags_5 = ["prior_runs_scored_mean_5", "prior_runs_allowed_mean_5",
              "prior_win_rate_5", "prior_whip_like_mean_5"]
tg_sorted["pre_game_ready"] = tg_sorted[key_lags_5].notna().all(axis=1).astype(int)

team_game = tg_sorted.reset_index(drop=True)
n_ready = int(team_game["pre_game_ready"].sum())
print(f"team_game 更新後：{team_game.shape}（含 pre-game lag features）")
print(f"pre_game_ready=1 的列數：{n_ready} / {len(team_game)} "
      f"({n_ready/len(team_game):.1%})")
display(team_game.filter(regex="^prior_|^opp_prior_|days_rest|season_to_date|h2h_|stadium_prior")
        .describe().T.round(3).head(20))
""")


# ── 2.9 — Pre-game feature gate ───────────────────────────────────────────
gate_md = explain(
    "2.9", "Pre-game / post-game 特徵 gate（預設 pre-game-only）",
    "明確分流：`PREGAME_FEATURES_ALL` 為 2.7b 算出來的 lag 特徵，`POSTGAME_FEATURES_ALL` 為比賽中/後的 box-score 特徵。`USE_PREGAME_ONLY=True` 時 Stage 5 的 PCA/Clustering 只看 pre-game，後續 cluster_id 可作為 leak-free 預測因子；切成 False 退回原本描述性 game-archetype 分析。",
    "兩個 list 都從 `team_game` 實際存在的欄位過濾以避免 KeyError。Gate 變數 `FEATURES_FOR_UNSUP` 會被 Stage 5.1 的 `filter_prune` 直接吃下去。Heavy-tailed lag（whip_like 衍生）走 RobustScaler，其餘走 StandardScaler。",
    "Stage 3 / 4 的描述統計與 EDA 仍然用全部欄位（描述就是描述）；只有 Stage 5 起會根據 gate 決定輸入特徵集合。",
    "切換 `USE_PREGAME_ONLY` 並重跑 Stage 5–7 即可得到對應視角的 cluster_id 與 derived features。",
)

gate_code = code(r"""
# === Pre-game / post-game feature gate ===
USE_PREGAME_ONLY = True   # 預設：只看 pre-game lag features

PREGAME_FEATURES_ALL = [c for c in team_game.columns
                        if (c.startswith("prior_") or c.startswith("opp_prior_"))
                        or c in {"days_rest", "day_of_week",
                                 "season_to_date_win_rate",
                                 "season_to_date_run_diff_mean",
                                 "h2h_prior_win_rate",
                                 "stadium_prior_run_mean",
                                 "is_home"}]

POSTGAME_FEATURES_ALL = [c for c in NUMERIC_FEATURES if c in team_game.columns]

FEATURES_FOR_UNSUP = PREGAME_FEATURES_ALL if USE_PREGAME_ONLY else POSTGAME_FEATURES_ALL

# Scaling group classification (heavy-tailed vs symmetric) for the chosen set
HEAVY_TAIL_GATE = [c for c in FEATURES_FOR_UNSUP
                   if any(k in c for k in ["whip", "run_per_hit",
                                           "stadium_prior_run",
                                           "strikeout_walk", "run_prevention",
                                           "power_score", "innings"])]
SYMMETRIC_GATE = [c for c in FEATURES_FOR_UNSUP if c not in HEAVY_TAIL_GATE]

mode = "pre-game (leak-free, predictive)" if USE_PREGAME_ONLY else "post-game (descriptive)"
print(f"USE_PREGAME_ONLY = {USE_PREGAME_ONLY}  →  Stage 5 模式：{mode}")
print(f"  選用特徵共 {len(FEATURES_FOR_UNSUP)} 個")
print(f"  RobustScaler 群組（{len(HEAVY_TAIL_GATE)} 個）：{HEAVY_TAIL_GATE[:6]}{'...' if len(HEAVY_TAIL_GATE) > 6 else ''}")
print(f"  StandardScaler 群組（{len(SYMMETRIC_GATE)} 個）：{SYMMETRIC_GATE[:6]}{'...' if len(SYMMETRIC_GATE) > 6 else ''}")

if USE_PREGAME_ONLY:
    n_ready = int(team_game["pre_game_ready"].sum())
    print(f"\n注意：pre_game_ready=0 的 {len(team_game) - n_ready} 列（每隊前幾場比賽）會在 Stage 5.2 由 imputer 用中位數填補。")
""")


# ── 5.7 — Multi-method K consensus (replaces original) ───────────────────
k_consensus_md = explain(
    "5.7", "K 值選擇：六方法共識（取代單一 silhouette）",
    "同時跑六個課程教過的最佳-K 評估方法：elbow（inertia kneed）、silhouette、Calinski–Harabasz、Davies–Bouldin、gap statistic、GMM BIC，最後用「投票 + bootstrap-Jaccard tiebreak」決定 `K_CONSENSUS`。",
    "對 k=2..10 重複：KMeans 取 inertia/silhouette/CH/DBI、GMM 取 BIC；gap statistic 對 B=10 個 uniform null reference 取 log 差。`kneed` 找 elbow（沒裝就用 2nd-derivative 後備）。",
    "六個方法常常選不同的 k——這正是「為什麼之前 silhouette 一個方法判 k=2 看起來太粗」的原因。投票圖會直接顯示哪幾個 k 各有多少方法支持。",
    "`K_CONSENSUS` 進入 Stage 5.8 (Ward) 與 5.11 (validity panel)。GMM 仍由其 BIC 自選 `K_GMM`。",
)

k_consensus_code = code(r"""
ks = list(range(2, 11))

km_records = []
for k in ks:
    km = KMeans(n_clusters=k, n_init=10, random_state=RANDOM_STATE).fit(X_pca)
    lab = km.labels_
    km_records.append({
        "k": k,
        "inertia": km.inertia_,
        "silhouette": silhouette_score(X_pca, lab),
        "calinski_harabasz": calinski_harabasz_score(X_pca, lab),
        "davies_bouldin": davies_bouldin_score(X_pca, lab),
    })
gmm_records = []
for k in ks:
    gm = GaussianMixture(n_components=k, covariance_type="diag",
                         n_init=3, random_state=RANDOM_STATE).fit(X_pca)
    gmm_records.append({"k": k, "bic": gm.bic(X_pca), "aic": gm.aic(X_pca)})

def gap_statistic(X, k_values, B=10, seed=RANDOM_STATE):
    X = np.asarray(X)
    n, d = X.shape
    mins, maxs = X.min(axis=0), X.max(axis=0)
    rng = np.random.default_rng(seed)
    log_W_real = []
    for k in k_values:
        km = KMeans(n_clusters=k, n_init=10, random_state=seed).fit(X)
        log_W_real.append(np.log(km.inertia_ + 1e-12))
    ref_logs = np.zeros((B, len(k_values)))
    for b in range(B):
        Xb = rng.uniform(mins, maxs, size=(n, d))
        for j, k in enumerate(k_values):
            km = KMeans(n_clusters=k, n_init=5,
                        random_state=int(rng.integers(1e9))).fit(Xb)
            ref_logs[b, j] = np.log(km.inertia_ + 1e-12)
    mean_ref = ref_logs.mean(axis=0)
    sd_ref = ref_logs.std(axis=0)
    return mean_ref - np.array(log_W_real), sd_ref * np.sqrt(1 + 1.0/B)

gaps, sks = gap_statistic(X_pca.values, ks, B=10)
gap_df = pd.DataFrame({"k": ks, "gap": gaps.round(4), "sk": sks.round(4)})

km_df = pd.DataFrame(km_records)
gmm_df = pd.DataFrame(gmm_records)

def pick_elbow(inertia_series):
    try:
        from kneed import KneeLocator
        kl = KneeLocator(list(inertia_series.index), list(inertia_series.values),
                         curve="convex", direction="decreasing")
        return int(kl.knee) if kl.knee else int(inertia_series.index[0])
    except ImportError:
        diffs = np.diff(inertia_series.values, 2)
        return int(inertia_series.index[np.argmax(diffs) + 1])

elbow_k = pick_elbow(km_df.set_index("k")["inertia"])
sil_k   = int(km_df.loc[km_df["silhouette"].idxmax(), "k"])
ch_k    = int(km_df.loc[km_df["calinski_harabasz"].idxmax(), "k"])
dbi_k   = int(km_df.loc[km_df["davies_bouldin"].idxmin(), "k"])
bic_k   = int(gmm_df.loc[gmm_df["bic"].idxmin(), "k"])
gap_k = ks[-1]
for j in range(len(ks) - 1):
    if gaps[j] >= gaps[j+1] - sks[j+1]:
        gap_k = ks[j]
        break

votes = pd.DataFrame({
    "method": ["elbow (kneed)", "silhouette", "Calinski-Harabasz",
               "Davies-Bouldin (min)", "gap statistic", "GMM BIC (min)"],
    "best_k": [elbow_k, sil_k, ch_k, dbi_k, gap_k, bic_k],
})
show_and_track(votes, "stage5_k_consensus_votes.csv", "table")
show_and_track(km_df.round(3), "stage5_kmeans_metrics.csv", "table")
show_and_track(gap_df, "stage5_gap_statistic.csv", "table")

vote_counts = votes["best_k"].value_counts().sort_index()
K_CONSENSUS = int(vote_counts.idxmax())

print("各方法投票：")
display(votes)
print(f"\n得票分布：{dict(vote_counts)}")
print(f"K_CONSENSUS（最多票）= {K_CONSENSUS}")

# Visualise the six metric curves
fig, axes = plt.subplots(2, 3, figsize=(16, 8))
axes[0, 0].plot(km_df["k"], km_df["inertia"], "o-")
axes[0, 0].axvline(elbow_k, color="red", linestyle="--", label=f"elbow={elbow_k}")
axes[0, 0].set_title("inertia (elbow)"); axes[0, 0].legend()

axes[0, 1].plot(km_df["k"], km_df["silhouette"], "o-", color="green")
axes[0, 1].axvline(sil_k, color="red", linestyle="--", label=f"sil={sil_k}")
axes[0, 1].set_title("silhouette"); axes[0, 1].legend()

axes[0, 2].plot(km_df["k"], km_df["calinski_harabasz"], "o-", color="purple")
axes[0, 2].axvline(ch_k, color="red", linestyle="--", label=f"CH={ch_k}")
axes[0, 2].set_title("Calinski-Harabasz"); axes[0, 2].legend()

axes[1, 0].plot(km_df["k"], km_df["davies_bouldin"], "o-", color="brown")
axes[1, 0].axvline(dbi_k, color="red", linestyle="--", label=f"DBI={dbi_k}")
axes[1, 0].set_title("Davies-Bouldin (lower better)"); axes[1, 0].legend()

axes[1, 1].errorbar(gap_df["k"], gap_df["gap"], yerr=gap_df["sk"], marker="o", color="navy")
axes[1, 1].axvline(gap_k, color="red", linestyle="--", label=f"gap={gap_k}")
axes[1, 1].set_title("gap statistic (Tibshirani)"); axes[1, 1].legend()

axes[1, 2].plot(gmm_df["k"], gmm_df["bic"], "o-", color="orange")
axes[1, 2].axvline(bic_k, color="red", linestyle="--", label=f"BIC={bic_k}")
axes[1, 2].set_title("GMM BIC (lower better)"); axes[1, 2].legend()

for ax in axes.flat:
    ax.set_xlabel("k")
fig.suptitle(f"Stage 5.7 — K 值選擇：六方法共識（K_CONSENSUS = {K_CONSENSUS}）", y=1.02)
plt.tight_layout()
show_and_track(fig, "stage5_k_consensus_panel.png")
plt.show()

K_KM = K_CONSENSUS
K_GMM = bic_k
print(f"\n下游使用：K_KM (= K_CONSENSUS) = {K_KM}; K_GMM (BIC) = {K_GMM}")
""")


# ── 5.18a — ANOVA + MI meaningful features ────────────────────────────────
anova_md = explain(
    "5.18a", "每個 cluster 的有意義特徵：ANOVA F-stat + mutual information",
    "用 ANOVA F-statistic 與 mutual information 評估「哪些特徵在 cluster 之間差異最大」，再加上 per-cluster z-score 方向，補足 SHAP 給出的 cluster 命名。",
    "ANOVA：`scipy.stats.f_oneway` 把每個特徵依 cluster 分組；MI：`sklearn.feature_selection.mutual_info_classif`。Z-score：每個 cluster 的平均減去整體平均再除以整體標準差。",
    "F 值大的特徵代表 cluster 中心差距大，是 cluster 解讀的「主軸」；MI 補強非線性關係；Z-score 的符號決定 cluster 名稱中的↑/↓。",
    "輸出的 ranking 進入 Stage 6.1 的 focus features 對照。",
)

anova_code = code(r"""
from sklearn.feature_selection import mutual_info_classif

rows = []
for c in FEATURES_FOR_UNSUP:
    groups = [tg_clustered.loc[tg_clustered["cluster"] == cl, c].dropna().values
              for cl in sorted(tg_clustered["cluster"].unique())]
    if all(len(g) > 1 for g in groups):
        try:
            f_stat, p_val = stats.f_oneway(*groups)
        except Exception:
            f_stat, p_val = np.nan, np.nan
    else:
        f_stat, p_val = np.nan, np.nan
    rows.append({"feature": c, "anova_F": f_stat, "anova_p": p_val})
anova_df = pd.DataFrame(rows)

mi_scores = mutual_info_classif(X_scaled.values, final_labels,
                                discrete_features=False, random_state=RANDOM_STATE)
mi_df = pd.DataFrame({"feature": list(X_scaled.columns), "mi": mi_scores})

meaningful = anova_df.merge(mi_df, on="feature", how="outer")

# Per-cluster z-score
grand_mean = tg_clustered[FEATURES_FOR_UNSUP].mean()
grand_std = tg_clustered[FEATURES_FOR_UNSUP].std(ddof=0).replace(0, 1)
z_table = ((tg_clustered.groupby("cluster")[FEATURES_FOR_UNSUP].mean() - grand_mean)
           / grand_std).T.round(2)
z_table.columns = [f"z_cluster_{c}" for c in z_table.columns]
meaningful = meaningful.merge(z_table, left_on="feature", right_index=True, how="left")

meaningful["combined_rank"] = (
    meaningful["anova_F"].rank(ascending=False, method="min")
    + meaningful["mi"].rank(ascending=False, method="min")
).rank(method="dense", na_option="bottom")
meaningful["combined_rank"] = meaningful["combined_rank"].fillna(-1).round().astype(int)
meaningful = meaningful.sort_values("combined_rank").reset_index(drop=True)
show_and_track(meaningful.round(3), "stage5_meaningful_features.csv", "table")

display(Markdown("**有意義特徵排名（ANOVA F + MI 共識，前 15）**"))
display(meaningful.head(15).round(3))

top12 = meaningful.head(12)
fig, ax = plt.subplots(figsize=(10, 6))
ax.barh(top12["feature"][::-1], top12["anova_F"][::-1], color="steelblue")
ax.set_xlabel("ANOVA F-statistic")
ax.set_title("Stage 5.18a — Top-12 cluster-defining features by ANOVA F")
plt.tight_layout()
show_and_track(fig, "stage5_anova_top12.png")
plt.show()
""")


# ── Compose new notebook with insertions and replacements ────────────────
new_cells = []
inserted_27a = False
inserted_29 = False
inserted_anova = False

for i, c in enumerate(nb.cells):
    src = c.source

    # Before "### 2.8" md → insert 2.7a + 2.7b
    if (not inserted_27a and c.cell_type == "markdown"
            and src.startswith("### 2.8")):
        new_cells.extend([wang_md, wang_code, pregame_md, pregame_code])
        inserted_27a = True

    # Before "## Stage 3" md → insert 2.9 gate
    if (not inserted_29 and c.cell_type == "markdown"
            and src.startswith("## Stage 3")):
        new_cells.extend([gate_md, gate_code])
        inserted_29 = True

    # Replace 5.7 md + code
    if c.cell_type == "markdown" and src.startswith("### 5.7"):
        new_cells.append(k_consensus_md)
        continue
    if (c.cell_type == "code" and i > 0
            and nb.cells[i-1].cell_type == "markdown"
            and nb.cells[i-1].source.startswith("### 5.7")):
        new_cells.append(k_consensus_code)
        continue

    # Patch Stage 5.1 filter_prune call
    if c.cell_type == "code" and "filter_prune(team_game, NUMERIC_FEATURES)" in src:
        patched = src.replace(
            "filter_prune(team_game, NUMERIC_FEATURES)",
            "filter_prune(team_game, FEATURES_FOR_UNSUP)",
        )
        new_cells.append(nbformat.v4.new_code_cell(patched))
        continue

    # Patch Stage 5.15 cmean to span both NUMERIC_FEATURES and FEATURES_FOR_UNSUP
    if (c.cell_type == "code"
            and "cmean = tg_clustered.groupby" in src
            and "[NUMERIC_FEATURES]" in src):
        patched = src.replace(
            "cmean = tg_clustered.groupby(\"cluster\")[NUMERIC_FEATURES].mean().round(3)\ncstd = tg_clustered.groupby(\"cluster\")[NUMERIC_FEATURES].std().round(3)",
            "ALL_FEATS_FOR_DESC = sorted(set(NUMERIC_FEATURES) | set(FEATURES_FOR_UNSUP))\n"
            "cmean = tg_clustered.groupby(\"cluster\")[ALL_FEATS_FOR_DESC].mean().round(3)\n"
            "cstd = tg_clustered.groupby(\"cluster\")[ALL_FEATS_FOR_DESC].std().round(3)"
        )
        new_cells.append(nbformat.v4.new_code_cell(patched))
        continue

    # Patch Stage 6.1 overlap to iterate FEATURES_FOR_UNSUP (the active feature set)
    if (c.cell_type == "code"
            and "for f in FOCUS_FEATURES:" in src
            and "overlap_rows" in src):
        patched = src.replace("for f in FOCUS_FEATURES:",
                              "for f in FEATURES_FOR_UNSUP:")
        new_cells.append(nbformat.v4.new_code_cell(patched))
        continue

    # Patch Stage 5.17 markdown — mention notch + bootstrap CI + caveats
    if c.cell_type == "markdown" and src.startswith("### 5.17"):
        new_cells.append(md(
            "### 5.17 — cluster feature boxplots（notched + bootstrap CI）\n\n"
            "- **程式碼目標**：檢查 focus features 在各 cluster 的分布形狀並比較中位數，加上 notch 顯示中位數的 ≈95% bootstrap CI。\n"
            "- **執行方式**：`sns.boxplot(..., notch=True, bootstrap=2000)`；若任一 cluster 的樣本數 < 10 自動退回普通 boxplot 以避免 flipped-notch（CI 比 IQR 還寬，造成「螞蟻腰」異常形狀）。\n"
            "- **產出與解讀**：兩個 cluster 的 notch 不重疊 ⇒ 中位數有差距的視覺證據（非正式檢定）。重疊很大或 notch 反摺則代表 cluster 大小差距過大、heavy-tailed 分布讓 1.58·IQR/√n 失準，或該 feature 區分力不足。\n"
            "- **與後續步驟的關聯**：和 5.18 surrogate-SHAP、5.18a ANOVA F/MI 並排對讀；正式顯著性結論以 5.18a 為準，本格用於形狀直覺。"
        ))
        continue

    # Patch Stage 5.17 boxplot — add notch + bootstrap CI + min-n guard
    if c.cell_type == "code" and 'sns.boxplot(data=tg_clustered, x="cluster"' in src:
        patched = """min_cluster_n = tg_clustered["cluster"].value_counts().min()
use_notch = bool(min_cluster_n >= 10)
print(f"min cluster size = {min_cluster_n} → notch={'on' if use_notch else 'off'}")

fig, axes = plt.subplots(2, 5, figsize=(18, 8))
for ax, feat in zip(axes.flat, FOCUS_FEATURES):
    sns.boxplot(
        data=tg_clustered, x="cluster", y=feat,
        ax=ax, palette="tab10", hue="cluster", legend=False,
        notch=use_notch, bootstrap=2000 if use_notch else None,
        width=0.6, showfliers=True,
    )
    ax.set_title(feat, fontsize=10)
fig.suptitle("Stage 5.17 — Per-cluster distribution of focus features (notched, bootstrap CI)")
plt.tight_layout()
show_and_track(fig, "stage5_cluster_boxplots.png")
plt.show()"""
        new_cells.append(nbformat.v4.new_code_cell(patched))
        continue

    # Patch Stage 5.2 standardize cell — switch HT/SYM groups
    if c.cell_type == "code" and "HT_kept = [c for c in HEAVY_TAIL if c in KEPT]" in src:
        patched = src.replace(
            "HT_kept = [c for c in HEAVY_TAIL if c in KEPT]",
            "HT_kept = [c for c in HEAVY_TAIL_GATE if c in KEPT]",
        )
        new_cells.append(nbformat.v4.new_code_cell(patched))
        continue

    # Insert 5.18a ANOVA right before 5.19 md
    if (not inserted_anova and c.cell_type == "markdown"
            and src.startswith("### 5.19")):
        new_cells.extend([anova_md, anova_code])
        inserted_anova = True

    new_cells.append(c)

# Sanity reporting
print(f"insertions: 2.7a/2.7b = {inserted_27a}, 2.9 gate = {inserted_29}, 5.18a ANOVA = {inserted_anova}")
print(f"new cell count: {len(new_cells)} (was {len(nb.cells)})")

nb.cells = new_cells
nb.metadata.setdefault("kernelspec", {"display_name": "Python 3",
                                       "language": "python", "name": "python3"})
with open(OUT, "w", encoding="utf-8") as f:
    nbformat.write(nb, f)
print(f"Wrote {OUT}")
