# CPBL 主客場勝負分析：節奏／情勢，而非「得分量」(2023 + 2024)

114-2 資料科學期末專題。以 **team-game**（一隊一場）為單位、循 `EDA → 描述 → 推論 → 建模 → 非監督 → 結論` 流程，從 [rebas.tw](https://github.com/rebas-tw/rebas.tw-open-data) 官方 release 取得 CPBL 中華職棒 **2023 + 2024** 賽季資料，回答「**得分『量』能否解釋主客差異，還是『節奏／情勢』在主導？**」

## 主要交付物

| 路徑 | 內容 |
|---|---|
| `Scripts/converge_analysis.ipynb` | 主 notebook（47 cells，7 stage + Reference 附錄；已執行 + 每 cell【解釋】由變數動態生成） |
| `Results/notebook_executed.html` | 程式碼無關的 HTML 報告：sidebar TOC + 每子節三段式呈現（讀法指引／output／本次結果與意義）；無 Jupyter 也可開 |
| `Results/stage{1..5}*/` | 27 個 PNG / CSV 產物，按 stage 分資料夾，支撐每個論點 |
| `docs/plan.md` | 研究計畫書（problem / method / verification / scope） |

## 完整目錄樹

```
.
├── README.md                                你在這裡
├── tldr.md                                  兩分鐘可讀完的專案總覽
├── master.sh                                一鍵 rebuild（執行 notebook + 重生 HTML）
├── .gitignore
│
├── Scripts/                                 程式碼
│   ├── converge_analysis.ipynb              主 notebook（含 inline outputs）
│   └── build/                               產生 / 重建 HTML 報告的腳本鏈
│       ├── README.md                        build pipeline 說明
│       ├── build_converge_report.py         notebook → styled HTML 轉換器
│       └── report_assets/{report.css,sidebar.js}
│
├── Results/                                 最終產出（27 檔；詳見 Results/README.md）
│   ├── notebook_executed.html               程式碼無關的 HTML 報告（含 References 附錄）
│   ├── stage1_eda/                          階段 1 EDA（4 PNG）
│   ├── stage2_descriptive/                  階段 2 描述統計（4 CSV）
│   ├── stage3_inferential/                  階段 3 推論統計（5 CSV + 1 PNG）
│   ├── stage4_model/                        階段 4 建模（8 CSV + 2 PNG）
│   └── stage5_unsupervised/                 階段 5 非監督觀察（1 CSV + 2 PNG）
│
└── docs/
    └── plan.md                              研究計畫書
```

## 主要結論（status quo，2023+2024 預設執行快照）

| 指標 | 結果 |
|---|---|
| 樣本數 | **1294** team-game rows（647 場去和局，2023 + 2024） |
| 主場勝率 | **52.9%** > 客場 47.1%，但主場平均得分 4.19 **反而略低於**客場 4.25 |
| **Pythagenpat 主場殘差** | **+0.035**（贏在效率而非總量） |
| **★ 節奏／攻勢標籤顯著數** | **6 / 6**（Holm/BH 校正後），最強為**六局領先態勢**（Cramér's V = 0.73，勝率差 78%） |
| 先馳得點勝率 | 70.5% |
| 解釋 is_home OR（加 C(team)） | **2.09**（p = 0.006，隊內真實效應） |
| Bradley–Terry HFA | +0.116 logit → 對等對戰主隊勝率 0.529 |
| 手熱效應 | 差 −0.009、置換 p = 0.623 → **不存在**（內含 Miller–Sanjurjo 校正） |
| **預測 AUC** | **leak-free 0.506 ≈ 隨機** / 同場洩漏 0.960 |
| 非監督 KMeans (k=2) | 群 #0 勝率 84% vs 群 #1 22%（**主場比皆 ≈ 0.5**——分群是節奏，不是主客） |

→ **主場優勢「可解釋、難預測」**。節奏／情勢（六局領先、攻勢強度、情勢掌控）是勝負主軸；得分『量』不足以解釋主場優勢。

## Pipeline 流程

```
Stage 0  環境 + 下載 rebas 原始資料
            ↓  (647 場 → 1294 team-game · HAS_WPA · 節奏／攻勢 6 標籤)
Stage 1  EDA（不預設立場）→ 浮現 H1–H5
            ↓
Stage 2  描述統計（含每隊 Pythagenpat 殘差）
            ↓
Stage 3  推論統計（H1–H5 檢定 + ★ 節奏／攻勢標籤顯著檢定 + 連勝/手熱）
            ↓
Stage 4  建模（解釋 vs 預測，固定+隨機效果、WPA 模型、Bradley–Terry、主場成因）
            ↓
Stage 5  非監督觀察（PCA + KMeans 比賽原型 + 與規則標籤交叉表）
            ↓
Stage 6  收斂結論（從變數彙整關鍵數據 + 敘事框架）
            ↓
Stage 7  輸出（27 個 figure/table 落地到 Results/）
附錄  References — 參考來源
```

## 快速開始

### 1. 直接讀

打開 [`Results/notebook_executed.html`](Results/notebook_executed.html) 即可——所有 7 個 stage 的渲染輸出 + 每節「讀法指引／本次結果與意義」皆 inline，不需 Jupyter。

### 2. 在 Jupyter 重跑

```bash
./master.sh
```

env 開關（皆 optional）：

- `CONVERGE_SEASONS=2024` — 只跑單季（預設 `2023+2024`）。
- `CONVERGE_EXPORT=false` — 不要把 figure/table 寫進 `Results/`（預設 `True`）。

## 授權

- **程式碼**：MIT。
- **資料**：來自 [rebas-tw/rebas.tw-open-data](https://github.com/rebas-tw/rebas.tw-open-data)，授權 **ODC-By 1.0**（須標註出處，notebook stage 0.3 自動加註）。
- **方法／風格參考**：見 [`Results/notebook_executed.html` 附錄 R.1](Results/notebook_executed.html)。
