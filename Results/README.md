# Results — converge_analysis 輸出物件

本資料夾收錄 `converge_analysis.ipynb`（CPBL 主客場勝負分析）各階段的資料表 (CSV) 與圖 (PNG)，依**分析階段 (stage)** 分目錄、檔名以 `stageN_` 前綴並按 result 命名。

## 資料與分析單位

- **資料來源**：**rebas-tw open-data 原始 release**（逐場 JSON），notebook 於執行時直接從 GitHub releases 下載並解析，快取於 `data/raw_rebas/`（不入庫）。所有節奏／情勢特徵皆**自行**由逐局得分、**逐打席 WPA／homeWE／RE24** 與每隊 batterBox 衍生，不使用任何由比賽結果反推的標籤。
  > 出處／授權：資料 © `rebas-tw/rebas.tw-open-data`，採 **ODC-By 1.0**（需標註出處）。
- **球季**：`SEASON_SCOPE` 預設 **`2023+2024`**（可設 `2024`）。跨年為 pooled 分析；Elo 與賽前滾動特徵**逐季重置**、解釋模型加入 `C(season)`。
- **分析單位**：以 **team-game（一隊一場）** 為主，「球隊」當分組因子——每隊分層 + 解釋模型同時用 **`C(team)` 固定效果**與 **team 隨機截距（混合效果）**，避免把球隊混為單一 population；`home_win`／勝差用 game-level。

## 如何重新產生

```bash
# 預設球季 2023+2024；要單看 2024 可加 CONVERGE_SEASONS=2024
CONVERGE_EXPORT=true jupyter nbconvert --to notebook --execute --inplace converge_analysis.ipynb
```

輸出由 `EXPORT_OUTPUTS`（env `CONVERGE_EXPORT`，**預設 `False`**）控制；`USE_TIME_LAG`（預設 `True`）控制階段 4b 預測特徵是否只用賽前滯後 (leak-free) 資訊。**所有 cell 的【解釋】皆由該 cell 實際算出的變數動態生成**（資料一換、敘述自動更新，無硬寫數字）。

## 目錄樹

```text
Results/
├── README.md
├── stage1_eda/                              # 階段 1：EDA（圖）
│   ├── stage1_winrate_runs.png              # 主客「平均得分(柱) vs 勝率(線)」雙軸圖
│   ├── stage1_winrate_by_team.png           # 各隊主／客勝率（主場優勢因隊而異, H5）
│   ├── stage1_runs_margin.png               # 主/客得分分布 + 主場勝vs客場勝 勝差分布
│   └── stage1_spearman_heatmap.png          # team-game 特徵（含每隊 H/BB/SO）與 win 的相關
├── stage2_descriptive/                      # 階段 2：描述統計（表）
│   ├── stage2_home_away_compare.csv         # 主客指標均值差
│   ├── stage2_runs_per_win.csv              # 每勝得分效率
│   ├── stage2_pythagenpat_home_away.csv     # 主客 Pythagorean / Pythagenpat 期望 vs 實際殘差
│   └── stage2_pythagenpat_team.csv          # 各隊同上
├── stage3_inferential/                      # 階段 3：推論統計（表 + 圖）
│   ├── stage3_chisquare_situation.csv       # H1 情勢×主客勝負 卡方
│   ├── stage3_tempo_offense_label_tests.csv # ★ 節奏／攻勢 標籤顯著檢定（卡方+Cramér's V+Holm/BH）
│   ├── stage3_tempo_offense_winrate_ci.png  # ★ 各標籤各類別勝率 + bootstrap 95% CI
│   ├── stage3_per_team_home_adv.csv         # 每隊主場優勢 + 各隊卡方（H5）
│   ├── stage3_multiple_comparison.csv       # 主檢定家族 Holm / BH 校正
│   └── stage3_hot_hand.csv                  # 連勝/手熱檢定（置換檢定，含 Miller–Sanjurjo 偏誤）
├── stage4_model/                            # 階段 4：建模（表 + 圖）
│   ├── stage4_logit_explanatory.csv         # 4a 解釋性羅吉斯：pooled vs 加 C(team)（cluster-robust）
│   ├── stage4_logit_mixed_team_re.csv       # 4a 混合效果（team 隨機截距）固定效果後驗
│   ├── stage4_logit_wpa.csv                 # 4a 情勢掌控 (WPA/RE24) 模型
│   ├── stage4_groupkfold_auc.csv            # 4a GroupKFold 樣本外 AUC
│   ├── stage4_permutation_importance.png    # 4a permutation importance
│   ├── stage4_logit_predictive_lagged.csv   # 4b 賽前滯後 (leak-free) 特徵係數
│   ├── stage4_predictive_auc_compare.csv    # 4b leak-free vs 同場(洩漏) AUC 對照
│   ├── stage4_bradley_terry.csv / .png      # 4c Bradley–Terry 球隊實力（分離主場優勢）
│   └── stage4_home_by_stadium.csv           # 4d 主場優勢的球場層級檢視（attendance/裁判欄位不存在）
└── stage5_unsupervised/                     # 階段 5：非監督觀察（表 + 圖）
    ├── stage5_pca.png                       # PCA scree + 2D（以勝負上色）
    ├── stage5_cluster_profile.csv           # KMeans 各原型剖面（勝率/主客比/節奏情勢特徵）
    └── stage5_cluster_winrate.png           # 各原型勝率
```

## 重點摘要（快照：`SEASON_SCOPE=2023+2024` 預設執行；實際數字以 notebook 動態輸出為準）

| 階段 | 主要發現 |
|---|---|
| stage1 EDA | 主場勝率 52.9% > 客場 47.1%，但主場平均得分 4.19 **反而略低於**客場 4.25；各隊主場優勢因隊而異（台鋼最高、中信最低）。 |
| stage2 描述 | 以 **Pythagenpat** 動態指數，主場殘差 **+0.035**（贏在把得失分更有效率轉成勝場，而非總量）。 |
| stage3 推論 | ★ **6/6 個節奏／攻勢標籤經 Holm/BH 校正後仍顯著**，效果量最大為**六局領先態勢**（Cramér's V=0.73）；先馳得點者約七成獲勝；**連勝/手熱效應不顯著**（置換 p=0.62，已含 Miller–Sanjurjo 偏誤校正）。 |
| stage4 建模 | 控制得分／節奏／球隊（及 season）後 **`is_home` OR=2.09（p=0.006）**，固定效果與混合效果雙重佐證為隊內真實主場效應；情勢掌控 (WPA/RE24) 與勝負顯著相關；**Bradley–Terry** 分離球隊實力與主場優勢（HFA→主隊勝率 0.529）；**賽前 leak-free 預測 AUC≈0.51≈隨機**，同場洩漏特徵 AUC≈0.96。 |
| stage5 非監督 | PCA／KMeans 純由節奏／情勢／攻勢特徵分出的原型，其勝率剖面與規則性標籤一致 → 再次佐證節奏／情勢是勝負主軸。 |

> **結論**：主場優勢真實但溫和，來源**不是得分變多**，而是「近身戰佔優 ＋ 把得分更有效率轉換為勝場（Pythagenpat 正殘差）＋ 節奏／情勢（先馳得點、六局領先、情勢掌控）」；控制球隊與得分後主場身分仍顯著（OR≈2）且為隊內效應。然而**賽前可預測性極低**（leak-free AUC≈0.5）——主場優勢可『解釋』卻難以『預測』。
