# Plan: CPBL Home/Away — Tempo & Situation Driven, Not Score Volume

## Research question

> **單看「得分量」是否足以解釋中華職棒 (CPBL) 的主場與客場勝負差異？
> 若不夠，是「節奏／情勢」補上了什麼？**

Hypotheses to be tested in Stage 3 (formulated *after* EDA in Stage 1):

- **H1 (Situation structure)** — 比賽情勢（險勝／常態／大比分）與主客勝負**不獨立**。
- **H2 (Margin size)** — **主場勝的勝差小於客場勝**（主隊贏在近身戰）。
- **H3 (Volume vs HFA)** — 每隊自身得分量與勝負正相關，但**主場優勢非由得分量驅動**
  → 預期 Pythagorean 主場正殘差。
- **H4 (Tempo / Situation) — 核心** — 先馳得點、六局領先、情勢掌控 (WPA)、攻勢
  強度 (RE24) 等**節奏／攻勢標籤**與勝負相關。
- **H5 (Team heterogeneity)** — **主場優勢因隊而異**，需以「球隊」分組理解。

---

## Data

- **Source**: [rebas-tw open data](https://github.com/rebas-tw/rebas.tw-open-data)
  — CPBL 官方逐場 JSON 的社群整理，授權 **ODC-By 1.0**.
- **Releases** (downloaded at runtime by `Scripts/converge_analysis.ipynb`
  stage 0.3; cached locally):
  - `v0.1.0-2023.0` (regular season G1–G150)
  - `v0.1.0-2023.1` (regular season G151–G300)
  - `v0.1.0-2024` (regular season G1–G360)
- **Default scope**: `SEASON_SCOPE=2023+2024` (overridable via env var `CONVERGE_SEASONS`).
- **Unit of analysis**: **team-game** (一隊一場); team is the grouping factor.
  Game-level only for `home_win` / `|margin|`.

---

## Method

| Stage | What | Key methods |
|---|---|---|
| 0 | Env / gates / data load / feature engineering / labels | rebas downloader;逐局 → 節奏 (early/mid/late_runs, scored_first, led_after_3/6); 逐打席 WPA → 情勢掌控 (we_volatility, we_lead_changes, high_lev_wpa, bat_wpa, bat_re24); batterBox → 投打量 (per-team H/BB/SO/HR). `HAS_WPA` gate auto-fallback. 6 不含結果標籤. |
| 1 | EDA | 主客輪廓雙軸 + 每隊主場優勢 bar + 得分／勝差 KDE + Spearman heatmap. **觀察 → 浮現 H1–H5**. |
| 2 | 描述 | 主客均值差 + 每勝得分效率 + Pythagorean 1.83 + **Pythagenpat 動態指數 `((RS+RA)/G)^0.287`** 殘差. |
| 3 | 推論 | 卡方 + Cramér's V + bootstrap 95% CI + **Holm/BH 校正**. ★**3.2 對 6 個不含結果的節奏／攻勢標籤逐一檢定**. 連勝/手熱用置換檢定（**內含 Miller–Sanjurjo 偏誤校正**）. **circularity 安全閥**：含結果的 `game_flow_label` 僅描述、不進推論. |
| 4 | 建模 | (a) 邏輯迴歸 FE + cluster-robust SE；(a 補) 混合效果 + 情勢 WPA 模型；(a 續) GroupKFold AUC + permutation importance；(b) **leak-free 賽前滯後特徵預測** (GroupKFold by `game_id`)；(c) **Bradley–Terry** 分離球隊實力與 HFA；(d) 主場成因（rebas 無 attendance/umpire → 改看球場層級）. |
| 5 | 非監督 | PCA scree + 2D 散點 + loadings → KMeans (k 由 silhouette) → 各群剖面 + 與規則標籤交叉表. **若資料驅動分群與規則標籤一致 → 節奏／情勢確為主軸**. |
| 6 | 收斂 | 從變數彙整關鍵數據（不重算）+ 敘事框架（含侷限）. |
| 7 | 輸出 | 27 個 PNG/CSV 依 `EXPORT_OUTPUTS` 寫到 `Results/stage{1..5}*/`. |

### Methodological guardrails

1. **No hard-coded numbers**: every【解釋】is `display(Markdown(f"..."))` driven by computed variables.
2. **circularity safeguard**: outcome-defined labels excluded from inference.
3. **Leak-free predictive view**: pre-game lag features only; GroupKFold by `game_id`.
4. **Multiple comparison**: Holm/BH on the whole H1–H4 family.
5. **Per-team grouping**: avoid Simpson's paradox via `C(team)` FE + team RE mixed model.
6. **Hot-hand bias**: permutation test inherently bias-corrects (Miller–Sanjurjo).
7. **Dynamic exponent for Pythagorean**: Pythagenpat over fixed 1.83 — better for low-run leagues.
8. **真實 per-PA WPA**: 不自建勝率矩陣；缺漏自動退回逐局推導.

---

## Verification

| Claim | Where to check |
|---|---|
| 主場勝率 > 客場 & 得分未較高 | `Results/stage1_eda/stage1_winrate_runs.png` + Stage 1.1 解釋 |
| Pythagenpat 主場 +0.035 | `Results/stage2_descriptive/stage2_pythagenpat_home_away.csv` |
| ★ 6/6 節奏／攻勢標籤顯著 (V=0.73 最強) | `Results/stage3_inferential/stage3_tempo_offense_label_tests.csv` + `stage3_tempo_offense_winrate_ci.png` |
| 控制後 is_home OR≈2.09 (p=0.006) | `Results/stage4_model/stage4_logit_explanatory.csv` |
| leak-free AUC≈0.506 vs 同場洩漏 0.960 | `Results/stage4_model/stage4_predictive_auc_compare.csv` + `stage4_groupkfold_auc.csv` |
| 手熱 p=0.623 (不存在) | `Results/stage3_inferential/stage3_hot_hand.csv` |
| Bradley–Terry HFA +0.116 | `Results/stage4_model/stage4_bradley_terry.csv` |
| 非監督 群#0/群#1 勝率 84% vs 22% | `Results/stage5_unsupervised/stage5_cluster_profile.csv` + `stage5_cluster_winrate.png` |

完整渲染版（含上述全部圖表 + 每節讀法指引）：[`Results/notebook_executed.html`](../Results/notebook_executed.html)。

---

## Scope / limits

- 單一聯盟 (CPBL) 一年期 (2023+2024)，球隊數 6 → H5 跨隊一致性檢力受限.
- rebas 原始資料**不含**觀眾數／裁判／天氣 → 主場成因僅能看球場層級.
- 跨年為 pooled，但 Elo / 滾動特徵**逐季重置**且解釋模型加 `C(season)`；
  Bradley–Terry 將實力視為跨季固定，是近似（台鋼 2024 才加入）.
- WPA / RE24 / homeWE 為 rebas 提供口徑.

---

## References

完整參考來源見 `Results/notebook_executed.html` 末段「附錄 R.1」與 notebook
最後一個 markdown cell（含 cde52470/data-analysis 的 build template、KB
markdown、rebas 授權、方法論文獻）。
