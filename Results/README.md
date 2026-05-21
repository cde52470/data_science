# Results/

最終產出。除了 `notebook_executed.html` 之外，所有圖表與表格都按 stage 拆成子資料夾。
Stage 5（非監督特徵發現）內部再分 10 個子主題的編號資料夾，使分析流程一目了然。

## 目錄結構（含每個檔案說明）

```
Results/
├── README.md                                       你在這裡
├── notebook_executed.html                          完整 notebook 的 HTML 報告（11 MB；含 Mermaid + 結果解讀）
│
├── stage2/                                         前處理階段對照（2 檔）
│   ├── stage2_wang_merge_2024.csv                      與學長 analyze_wang 的 2024 left-merge 結果
│   └── stage2_wang_merge_comparison.csv                逐欄 equality_rate + Pearson r（35/44 數值欄 r ≥ 0.999）
│
├── stage3/                                         描述統計（6 CSV）
│   ├── stage3_describe_overall.csv                     整體 29 features 的 describe
│   ├── stage3_per_season_focus.csv                     FOCUS_FEATURES 的 2023 vs 2024 對照
│   ├── stage3_base_rates.csv                           4 個二元 features 的基準率（整體 + 分季）
│   ├── stage3_corr_vs_win.csv                          所有 features 與 win 的 Pearson r + Spearman ρ（排序）
│   ├── stage3_corr_vs_run_diff.csv                     所有 features 與 run_diff 的 Pearson r + Spearman ρ
│   └── stage3_skew_kurtosis_missing.csv                偏態 / 峰度 / 缺失率診斷
│
├── stage4/                                         EDA 視覺化（10 PNG）
│   ├── stage4_small_multiples_top10.png                10 個 FOCUS_FEATURES 的 2x5 histogram + KDE
│   ├── stage4_spearman_heatmap.png                     29×29 Spearman 相關下三角熱圖
│   ├── stage4_pairplot_top5.png                        top-5 features pairplot（hue = win）
│   ├── stage4_home_away_means.png                      主 vs 客 mean grouped bar，2023 / 2024 兩面板
│   ├── stage4_monthly_trajectory.png                   FOCUS_FEATURES 每月趨勢，兩季 overlay
│   ├── stage4_ecdf_top10.png                           10 個 FOCUS_FEATURES 的 ECDF
│   ├── stage4_calendar_heatmap.png                     球場 × ISO 週次主辦場次熱圖
│   ├── stage4_win_rate_by_team.png                     球隊勝率排序 bar（主 / 整體 / 客）
│   ├── stage4_hexbin_H_run_diff.png                    H vs run_diff hexbin density
│   └── stage4_violin_per_team.png                      top-3 features × 球隊 violin
│
├── stage5/                                         非監督特徵發現（33 檔，分 10 子資料夾）
│   │
│   ├── 01_filter_scale/                                5.1-5.2 篩選與標準化（2 檔）
│   │   ├── stage5_filter_prune_log.csv                     near-zero variance + |ρ|≥0.95 redundancy prune 過程
│   │   └── stage5_scaled_describe.csv                      X_scaled 的 describe
│   │
│   ├── 02_pca/                                         5.3-5.6 主成分分析（5 檔）
│   │   ├── stage5_pca_scree.png                            PVE bar + 累積線（90% PVE @ k=24）
│   │   ├── stage5_pca_biplot.png                           PC1-PC2 散點 + 所有 features 的 loading 箭頭
│   │   ├── stage5_pca_loadings_abs.csv                     |loadings| 矩陣（55 × 24）
│   │   ├── stage5_loadings_heatmap.png                     |loadings| 熱圖
│   │   └── stage5_pca_3d.html                              plotly 3D 互動圖
│   │
│   ├── 03_k_consensus/                                 5.7 K 值六方法共識投票（5 檔）
│   │   ├── stage5_kmeans_metrics.csv                       K-Means 的 inertia / silhouette / CH / DBI × k
│   │   ├── stage5_gap_statistic.csv                        gap 統計 + sk × k
│   │   ├── stage5_gmm_metrics.csv                          GMM BIC / AIC × k（投票用）
│   │   ├── stage5_k_consensus_votes.csv                    六方法各自最佳 k 的投票表
│   │   └── stage5_k_consensus_panel.png                    2×3 metric 曲線（每張標各方法 pick）
│   │
│   ├── 04_hierarchy/                                   5.8 階層分群最佳化：4 linkage + balance gate（5 檔）
│   │   ├── stage5_hierarchy_linkage_comparison.csv         每 linkage 的 cophenetic + 平衡後最佳 (k, sil, min_frac)
│   │   ├── stage5_hierarchy_full_matrix.csv                完整 (linkage × k) 矩陣，含 balanced flag
│   │   ├── stage5_hierarchy_silhouette_sweep.csv           (legacy) silhouette × k（已被 full_matrix 取代）
│   │   ├── stage5_dendrogram_4linkages.png                 ward / average / complete / single dendrogram 2x2
│   │   └── stage5_hierarchy_kselection.png                 silhouette × k + min_cluster_frac × k 雙圖（紅虛線 = 5% 平衡 gate）
│   │
│   ├── 05_gmm/                                         5.9 GMM（1 檔）
│   │   └── stage5_gmm_bic.png                              BIC / AIC × k 折線
│   │
│   ├── 06_hdbscan/                                     5.10 HDBSCAN（1 檔）
│   │   └── stage5_hdbscan_tree.png                         condensed tree 視覺化
│   │
│   ├── 07_validity/                                    5.11-5.12 演算法比較 + per-point silhouette（2 檔）
│   │   ├── stage5_validity_panel.csv                       kmeans / hierarchy[ward] / gmm 三方比較表
│   │   └── stage5_silhouette_per_point.png                 所有點按 cluster 分組的 silhouette bar
│   │
│   ├── 08_embeddings/                                  5.13-5.14 降維 sanity（2 檔）
│   │   ├── stage5_umap_pair.png                            UMAP × (cluster_id / season) 雙面板
│   │   └── stage5_tsne_perplexity.png                      t-SNE perplexity=15 / 50 並列
│   │
│   ├── 09_interpretation/                              5.15-5.18a 群解讀（7 檔）
│   │   ├── stage5_cluster_means.csv                        每個 cluster × 全部 features 的平均
│   │   ├── stage5_cluster_stds.csv                         每個 cluster × 全部 features 的標準差
│   │   ├── stage5_cluster_radar.png                        FOCUS_FEATURES z-score 多邊形 radar
│   │   ├── stage5_cluster_boxplots.png                     notched + bootstrap CI boxplots（2×5 grid）
│   │   ├── stage5_shap_per_cluster.csv                     surrogate RF + Tree-SHAP top-5 ranking 每 cluster
│   │   ├── stage5_meaningful_features.csv                  ANOVA F + MI + per-cluster z-score 共識排名
│   │   └── stage5_anova_top12.png                          top-12 features 的 ANOVA F bar chart
│   │
│   └── 10_cross_season/                                5.19 跨季比較（3 檔）
│       ├── stage5_season_cluster_xtab.csv                  (season_tag × cluster) cross-tab
│       ├── stage5_cluster_freq_shift.png                   2023 vs 2024 cluster 比例 grouped bar
│       └── stage5_season_cluster_sankey.html               plotly Sankey 跨季 cluster 流向圖
│
└── stage6/                                         綜合整理（4 CSV）
    ├── stage6_focus_overlap.csv                        active features × (PCA loading + SHAP) 共識排名
    ├── stage6_new_candidate_features.csv               unsupervised 新增的 8 個候選 features（cluster_id + 4 gmm_p + 3 pc）
    ├── stage6_feature_strategy.csv                     feature strategy 設計（保留 / 增添 / 可行）
    └── stage6_research_design_summary.csv              一頁研究設計摘要（面向 × 設計 × 解讀）
```

## 本次 status quo 結果（重點）

| 項目 | 數值 |
|---|---|
| Team-game rows | 1320（2023 + 2024 去重後）|
| Pre-game ready | 1308 / 1320（99.1%）|
| Wang 對照 Pearson r ≥ 0.999 | 35 / 44 數值欄 |
| PCs 至 90% 累積 PVE | 24 |
| K 共識六方法投票 | k=2 與 k=3 並列第一，採最小 k = 2 |
| 階層分群最佳 linkage | `ward` k=2（cophenetic 0.327；balance gate 過 24.2%）|
| └─ 為何不是 cophenetic 最高的 `average`？ | average k=2 退化為 1315 vs 5 外點隔離，被 5% balance gate 過濾 |
| **最終演算法** | **`kmeans` k=2**，silhouette 0.115，bootstrap-Jaccard 0.918 |
| Cluster 解讀 | cluster 0 = 近 5-10 場 run_diff↑（球隊熱）；cluster 1 = 近期 run_diff↓（球隊冷）|

## 如何重新生成

```bash
./master.sh
```

`master.sh` 只重生 `notebook_executed.html`（執行 notebook + nbconvert HTML）。

要連帶把 `Results/stage*/` 也一起重生：
1. 把 `Scripts/cpbl_unsupervised_feature_discovery.ipynb` 內 Stage 7.3 cell 的
   `DOWNLOAD_ALL = False` 改成 `True`，並把 `out_dir` 指向絕對路徑的 `Results/`。
2. 重跑整本 notebook。
3. 跑 `python3 /tmp/reorganize_stage5.py`（或 `Scripts/build/reorganize_stage5.py`）
   把 flat 輸出按主題搬進 sub-folders。

詳見 [`Scripts/build/README.md`](../Scripts/build/README.md) 描述的 pipeline。

## 設計選擇

- 檔名命名規律 `stage{N}_<snake_case>.<ext>`，視覺掃描即知歸屬。
- Stage 5 子資料夾使用 `01_..10_` 數字前綴，讓檔案管理員 / `ls` 自動依分析流程順序排列。
- Plotly 互動圖（3D PCA、Sankey）保存為 `.html`；matplotlib 圖為 `.png`。
- CSV 使用 UTF-8 with BOM（`utf-8-sig`），Excel 直接開啟不亂碼。
- Stage 0、1、7 沒有 inline tracked artifacts，所以 `Results/stage{0,1,7}/` 不存在——它們是 setup / 資料下載 / 輸出開關，不需獨立檔案。
