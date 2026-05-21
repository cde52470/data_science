# CPBL Unsupervised Feature Discovery (2023 + 2024)

114-2 資料科學期末專題。從 [rebas.tw](https://github.com/rebas-tw/rebas.tw-open-data)
官方 release 取得 CPBL 中華職棒 2023 + 2024 賽季資料，建構 team-game-level
特徵，並用**非監督式學習**找出可作為 leak-free 預測因子的
`cluster_id` / PC scores / GMM soft probabilities。

## 主要交付物

| 路徑 | 內容 |
|---|---|
| `Scripts/cpbl_unsupervised_feature_discovery.ipynb` | 主 notebook（193 cells，7 stage，已執行 + 中文「結果解讀」評註） |
| `Results/notebook_executed.html` | 程式碼無關的 HTML 報告：Mermaid 流程圖 + per-stage 渲染輸出 + 解讀；無 Jupyter 也可開啟 |
| `Results/stage{2..6}/` | 51 個 CSV / PNG / HTML 產物，按 stage 分資料夾 |
| `docs/plan.md` | 研究計畫書（goal / context / verification / risks） |
| `docs/knowledge_base/` | 從 `course-material/` 蒸餾出來的 10 份 Markdown 知識庫 |

## 完整目錄樹

```
.
├── README.md                                你在這裡
├── master.sh                                一鍵 rebuild（執行 notebook + 重生 HTML）
├── .gitignore
│
├── Data/                                    原始與外部資料
│   ├── 2023/                                    rebas releases（內附；~76 MB JSON，4 個 release 子資料夾）
│   ├── 2024/                                    佔位夾；notebook Stage 1 第一次跑會自動下載 zip
│   └── reference/                               對照組（analyze_wang cleaned CSV 等）
│
├── Scripts/                                 程式碼（版本控制）
│   ├── cpbl_unsupervised_feature_discovery.ipynb   主 notebook（193 cells，含 inline outputs）
│   ├── build/                                   產生 / 重建 notebook 與 HTML 報告的腳本鏈
│   └── legacy/                                  前期 pre-game win prediction 舊 notebook + 5 PNG
│
├── Derived/                                 中間 artefacts；gitignored；由 master.sh 重建
│
├── Results/                                 最終產出（53 檔，~21 MB；詳見 Results/README.md）
│   ├── notebook_executed.html                   程式碼無關的 HTML 報告（11 MB）
│   ├── stage2/                                  Wang 對照（2 CSV）
│   ├── stage3/                                  描述統計（6 CSV）
│   ├── stage4/                                  EDA 視覺化（10 PNG）
│   ├── stage5/                                  非監督特徵發現（33 檔，分 10 子資料夾）
│   │   ├── 01_filter_scale/                         5.1-5.2 篩選與標準化（2 檔）
│   │   ├── 02_pca/                                  5.3-5.6 主成分分析（5 檔）
│   │   ├── 03_k_consensus/                          5.7 K 值六方法共識投票（5 檔）
│   │   ├── 04_hierarchy/                            5.8 階層分群最佳化：4 linkage + balance gate（5 檔）
│   │   ├── 05_gmm/                                  5.9 GMM（1 檔）
│   │   ├── 06_hdbscan/                              5.10 HDBSCAN（1 檔）
│   │   ├── 07_validity/                             5.11-5.12 演算法比較 + per-point silhouette（2 檔）
│   │   ├── 08_embeddings/                           5.13-5.14 UMAP / t-SNE（2 檔）
│   │   ├── 09_interpretation/                       5.15-5.18a 群解讀（7 檔）
│   │   └── 10_cross_season/                         5.19 跨季比較（3 檔）
│   └── stage6/                                  綜合整理（4 CSV）
│
└── docs/
    ├── plan.md                                  研究計畫書
    └── knowledge_base/                          從 course-material 蒸餾的 10 份 KB markdown + README
```

> 詳細的 stage5 子分類與每個檔案說明請看 [`Results/README.md`](Results/README.md)。
> KB 內容索引請看 [`docs/knowledge_base/README.md`](docs/knowledge_base/README.md)。

## 主要結論（status quo）

| 指標 | 結果 |
|---|---|
| 樣本數 | 1320 team-game rows（2023 + 2024，去重後） |
| Pre-game features | 60+ 個 `prior_*` / `opp_prior_*` / `season_to_date_*` / `h2h_*` / `stadium_prior_*` |
| Pre-game ready | 1308/1320（99.1%）；前 1-4 場 NaN 由 imputer 補中位數 |
| Wang R port 對照 | 35/44 數值欄位 Pearson r ≥ 0.999（移植在數值上等價） |
| PCA k* @ 90% PVE | 24 PCs |
| K 共識（6 方法投票）| k=2 與 k=3 各得 2 票；採最小 k=2 |
| 階層分群最佳 linkage | `ward` k=2（cophenetic 0.327；balance gate 過 24.2%）。注意 average 雖 cophenetic 最高（0.647）但 k=2 退化成 1315 vs 5，被 balance gate 過濾 |
| **最終演算法** | **`kmeans` k=2**（silhouette 0.115、bootstrap-Jaccard 0.918） |
| Cluster 解讀 | cluster 0 = 近 5-10 場 run_diff↑（球隊熱）；cluster 1 = 近期 run_diff↓（球隊冷） |
| 新增候選 features | 8 個：`cluster_id` + `gmm_p0..p3` + `pc1..pc3` |

## Pipeline 流程

```
Stage 0  setup           ─→ Stage 1  rebas 下載
                              │
                              ▼
Stage 2  preprocessing       team-game feature engineering
            │                ↳ 2.7a Wang 對照
            │                ↳ 2.7b pre-game lag features
            │                ↳ 2.9  pre-game / post-game gate
            ▼
Stage 3  descriptive stats
            ▼
Stage 4  EDA viz（10 張）
            ▼
Stage 5  unsupervised
            │ 5.1-5.6   filter → scale → PCA
            │ 5.7       K 共識（六方法投票）
            │ 5.8       階層分群（4 linkage + balance gate）
            │ 5.9-5.11  GMM / HDBSCAN / validity + Jaccard
            │ 5.12-5.14 silhouette diag / UMAP / t-SNE
            │ 5.15-5.18 cluster mean / radar / notched box / SHAP
            │ 5.18a     ANOVA F + MI 重要性
            │ 5.19-5.20 跨季 shift + derived feature register
            ▼
Stage 6  synthesis（overlap、new candidates、design summary）
            ▼
Stage 7  export（DOWNLOAD_ALL flag 控制是否寫出 Results/stage*/）
```

## 快速開始

### 1. 直接讀

打開 [`Results/notebook_executed.html`](Results/notebook_executed.html) 即可——
所有 7 個 stage 的渲染輸出 + 中文解讀都已 inline，不需 Jupyter。

### 2. 在 Jupyter 重跑

```bash
./master.sh
```

`master.sh` 會：
1. 用 `jupyter nbconvert --execute` 跑完整本 notebook
2. 重新匯出 `Results/notebook_executed.html`

第一次跑會從 rebas.tw 下載 2024 release zip 到 `Data/2024/`（2023 已內附）。

### 3. 從零重建 notebook 或重生 Results/stage*/

詳見 [`Scripts/build/README.md`](Scripts/build/README.md)。

## 版本控制慣例

- **進 git**：`README.md` / `master.sh` / `.gitignore` / `Scripts/` / `Results/` / `docs/` / `Data/2023/`
- **不進 git**：`Derived/` 與 `Data/2024/CPBL-*` 內的執行時下載檔（由 `master.sh` 重新產出）
- 大型外部資料（如原本 199 MB 的 `course-material/` HTML 原檔）建議遷往 GitHub Release asset，不要進主 repo

## 主要參考

- [rebas.tw 開放資料](https://github.com/rebas-tw/rebas.tw-open-data) — 比賽原始 JSON（ODC-By 授權）
- [analyze_wang branch](https://github.com/cde52470/data_science/tree/analyze_wang) — 學長前期 supervised 預測程式 + cleaned CSV
- 課程 `course-material/`（199 MB HTML 原檔，已移出 repo；蒸餾版見 `docs/knowledge_base/`）
- Lo, T.-Y. et al. (2025). "Application of Machine Learning Models for Baseball Outcome Prediction." *Applied Sciences*.
