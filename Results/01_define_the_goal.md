# CPBL Home-Team Win Prediction — Goal Charter

> **Doc owner**: Sub-Agent 1 (goal-definer)
> **Status**: v0.1 — pending review by data-collector (Sub-Agent 2)
> **Source of truth for**: Sub-Agents 2 – 6
> **Loop note**: This charter is *revisable*. When data-collector surfaces
> reality (missing 大巨蛋 weather rows, 台鋼 sample size, etc.), this doc
> must be patched, not silently overridden downstream.

---

## TL;DR (exec summary, ≤ 150 words)

我們要把「中華職棒主隊在一場例行賽中是否獲勝」轉成一個可被驗證、可被決策使用的二元分類問題：
`is_home_win ∈ {1, 0}`，2020 – 2024 例行賽，平手場次剔除。透過 **m1 – m7
七層 ablation**（截距 → 球場 → 天氣 → 全模型），量化「主場優勢 / 球場特性 /
天氣」三組特徵的邊際解釋力。預先註冊的成功門檻：
**(a)** 必勝門檻 — Test ROC-AUC 顯著高於 m1 截距模型 95 % bootstrap CI 上界；
**(b)** 可發表 — Test AUC ≥ 0.60；**(c)** 可部署 — Test AUC ≥ 0.62 且
calibration slope ∈ [0.9, 1.1] 且 Brier ≤ 0.22。主要風險：選擇偏差（雨延、
大巨蛋開幕）、概念漂移、後驗特徵洩漏、CWA 觀測站斷訊。Hand-off：
data-collector 需提供 `raw_games.csv` 與 `raw_weather.csv` 兩張表 +
provenance manifest，join key 為 `date × stadium`。

---

## 1. Problem Statement

### 1.1 業務問題

對 CPBL 一場 *尚未開打* 的例行賽，給出主隊獲勝的機率 `P(is_home_win = 1)`，
並提供模型對該機率的 **校準後信心區間**。

### 1.2 為什麼這題值得做

- **主場優勢是棒球文獻中最穩定的訊號之一**：MLB 近 10 年聯盟主隊勝率
  ≈ 54 %（Baseball Reference, League Splits, 2014 – 2024 取得時間
  2025-Q1）。CPBL 因球場規模、氣候差異、賽程強度，HFA 不一定等同 MLB，需獨立量化。
- **球場 × 天氣的交互作用具物理基礎**：A. Nathan, *The Physics of Baseball*
  (4th printing, 2011) 與後續球場物理研究指出：5 mph 順風約增加
  19 ft 飛球距離；氣溫每升 5 °C，ISO/HR 有可量測上揚。CPBL 露天球場
  （桃園、洲際、台南、新莊、澄清湖、嘉義）對這類效應暴露程度不同；
  室內巨蛋（臺北大巨蛋自 2024 啟用）則為對照組。
- **資料完整可用**：野球革命 (Rebas) JSON 提供逐場結果，CPBL 官網
  (`rvest`) 提供賽程與球場 metadata，中央氣象署 CWA Open Data API 提供
  測站逐時資料。三來源皆免費且不需破解任何 ToS。

### 1.3 不在這個 MVP 範圍

- ❌ 季後賽（樣本太少，賽程結構不同）。
- ❌ 個別打者 / 投手 lineup-level features（留給 v2，避免一開始就跨層級設計）。
- ❌ 即時下注 odds（不取得運彩盤口數據，避免任何 leakage 與授權問題）。
- ❌ Kaggle 或任何 pre-bundled dataset（專案憲法層級限制）。

---

## 2. Stakeholders & Decisions

每位 stakeholder 必須能從輸出中做出一個 *具體* 決策，否則模型就是裝飾品。

| Persona | 使用情境 | 從模型輸出做的決策 | 對模型的最低要求 |
|---|---|---|---|
| **運彩分析師** | 賽前 60 min 取得當日所有比賽預測 | 與盤口賠率對照，建立 Kelly 比例下注名單 | 機率必須 **校準**；AUC 高但 over-confident 會直接賠錢 |
| **球團教練組** | 賽前一週做先發輪值排程 | 評估在桃園遇強風時是否輪掉飛球型投手 | 需要 SHAP-level 的特徵歸因，不只是黑箱機率 |
| **球迷部落格作者** | 賽前 24 hr 產出預測內容 | 標題、看點、賠率比較表 | 機率 + 中文敘述（哪個特徵主導本場） |

> **Decision-rule pre-commit**：對 *運彩分析師* persona 我們將在
> §7 設定 *decision-curve net benefit @ threshold = 0.55* 作為實際
> 商業價值的代理指標 — 比單純 accuracy 更貼近下注決策。

---

## 3. Target Variable & Unit of Analysis

### 3.1 Target

| 屬性 | 規格 |
|---|---|
| 名稱 | `is_home_win` |
| 型別 | `factor` with levels `c("0", "1")`，positive class = `"1"` |
| 定義 | `1` if `home_score > away_score`; `0` if `home_score < away_score` |
| 平手處理 | **Drop**（CPBL 例行賽歷史平手率 ≤ 1 %；不值得為了極少數類別引入多分類複雜度） |
| 缺漏處理 | 比賽取消 / 未完成 / 保護 → drop，並於 manifest 中記錄棄置原因 |

### 3.2 Unit of analysis

**一場 CPBL 例行賽**（regular season game）。每列 = 一場比賽 × 從主隊視角。

### 3.3 Scope window

- **訓練 / 驗證**：2020 – 2023 例行賽（4 季 ≈ 960 – 1 000 場）。
- **保留測試集**：2024 例行賽（≈ 240 場），time-based hold-out。
- **2025 部署視窗**：模型訓練完凍結，每日預測經 Shiny app 推送。
- **重要例外**：2020 球季因 COVID 開季延後 + 部分閉門賽，主場優勢可能異常；
  納入但會在 §9 列為敏感性分析項目。

---

## 4. Feature Groups & Data Requirements

模型只取 **賽前可得** 的特徵，避免 leakage（詳見 §9）。

### 4.1 Group A — Home Advantage（折進截距）

因為每列都從主隊視角編碼，「主 / 客」這個維度已折進 bias term。
**m1 (`~ 1`)** 即為純主場優勢的 baseline，不是空模型。

### 4.2 Group B — Stadium

| 變數 | 型別 | 域 |
|---|---|---|
| `stadium` | factor (7 levels) | {臺北大巨蛋, 樂天桃園, 洲際, 台南, 新莊, 澄清湖, 嘉義} |

理由：球場大小、外野深度、坡度與全壘打牆距離直接影響 BABIP / HR 率，
是棒球領域 *park factor* 的標準切入點。

### 4.3 Group C — Weather（賽前可得，使用比賽開始前 1 hr 的 CWA 資料）

| 變數 | 型別 | 典型域 | 物理動機 |
|---|---|---|---|
| `temperature` | numeric (°C) | 15 – 38 | +5 °C → 飛球距離 +2 – 3 ft；ISO 上揚 |
| `humidity` | numeric (%) | 30 – 100 | 高濕度 → 空氣密度上升 → 飛球阻力增加 |
| `wind_speed` | numeric (m/s) | 0 – 15 | 5 mph 順風 ≈ +19 ft 飛球距離（Nathan, 2011） |
| `wind_dir` | factor (optional) | 8-point | 與球場朝向交互；先列為 stretch goal |

> **室內巨蛋處理**：臺北大巨蛋場次的 weather 變數會以 *最近室外測站值*
> 填入並標記 `is_dome = TRUE`，避免天氣對封閉球場錯誤計入效應 —
> 由 data-collector 在 hand-off 階段實作。

### 4.4 Auxiliary（必備但非建模特徵）

| 欄位 | 用途 |
|---|---|
| `date` (Date, ISO 8601) | time-based split 必要 |
| `game_id` (chr, e.g. `20231015-G01`) | 唯一鍵、debug、provenance |
| `home_team`, `away_team` (factor) | 公平性分層用，**不進主模型**避免 over-fit 少樣本隊伍 |

---

## 5. Hypotheses (H0 / H1 per feature group)

採 **pre-registered** 假設檢定 — 在看完整資料前固定下列規格。

| ID | 虛無假設 H0 | 對立 H1 | 檢定方法 |
|---|---|---|---|
| **HS** (Stadium) | 將 `stadium` 加入截距模型，模型 AUC 與 deviance 無顯著改善 | 加入後 AUC 嚴格上升且 likelihood-ratio test (LRT) p < 0.05 | LRT (m1 vs m4) **+** DeLong ΔAUC test on hold-out |
| **HW** (Weather) | 在 `stadium + intercept` 之上加入 `temperature + humidity + wind_speed` 無增益 | 加入後 AUC 上升且 LRT p < 0.05 | LRT (m4 vs m7) **+** DeLong ΔAUC + paired bootstrap (1 000 resamples) |
| **HSW** (Joint) | Group B + C 同時加入，相對 m1 無增益 | 同上 | LRT (m1 vs m7) |

### 5.1 為什麼用三種檢定堆疊？

- **LRT** 在巢狀模型上是最有效率（在分佈假設下），但對 logistic
  regression 以外的方法不適用。
- **DeLong ΔAUC** 在 hold-out 上提供 *分類效用* 角度，與訓練 deviance 互補。
- **Paired bootstrap** 對非巢狀比較（樹模型 vs GLM）必須，避免假設違反。

### 5.2 多重比較

m1 是 anchor，m2 – m7 對 m1 各做一次比較 → 6 次 → **Holm-Bonferroni** 修正
family-wise α，保留 α = 0.05。

---

## 6. 7-Model Ablation Plan

承襲 `CLAUDE.md` §2；此處明確化 *建模演算法* 與 *調參策略*。

| Model | Formula (`is_home_win ~`) | 演算法 | Tuning |
|---|---|---|---|
| **m1** | `~ 1` | logistic regression (`parsnip::logistic_reg()`) | none |
| **m2** | `~ stadium` | logistic regression | none |
| **m3** | `~ temperature + humidity + wind_speed` | logistic regression | none |
| **m4** | `~ stadium`（含截距） | logistic regression | none |
| **m5** | `~ temperature + humidity + wind_speed`（含截距） | logistic regression | none |
| **m6** | `~ stadium + temperature + humidity + wind_speed`（無截距 baseline 視為 stretch） | logistic regression | none |
| **m7** | full + 交互項 `stadium × wind_speed` | logistic regression + glmnet 正則化 | 5-fold time-aware CV |

> **為何不一開始就上 boosting？** Phase A（POC）必須先以可解釋
> baseline 確立「stadium / weather 各自有沒有訊號」。Phase B（model-builder
> 主要工作）才以 `xgboost` / `ranger` 進場，並以 m7 作為 GLM 對照。

### 6.1 Train / Validation / Test split

- **Train**: 2020 – 2022
- **Validation (time-aware CV)**: 2023, 用 `rsample::sliding_period()` 滾月窗
- **Test (held-out, 一次性使用)**: 2024 全季

**禁止**用 `rsample::initial_split()`（random shuffle）— 會造成未來資料洩漏。

---

## 7. Success Criteria

### 7.1 Primary metric & thresholds

**主指標**：Test ROC-AUC on 2024 hold-out。

| 門檻 | 量化條件 | 觸發行為 |
|---|---|---|
| **Bar #1 — Must beat (sanity)** | Test AUC of m7 > upper bound of 95 % bootstrap CI of m1 Test AUC | 模型至少證明加了東西比沒加好；否則回 §1 重新審視假設 |
| **Bar #2 — Publishable** | Test AUC ≥ 0.60 | 可作為期末報告主結果 |
| **Bar #3 — Deployable** | Test AUC ≥ 0.62 **AND** calibration slope ∈ [0.9, 1.1] **AND** Brier ≤ 0.22 | 才把模型接進 Shiny app；否則 app 只展示 EDA |

> **為何把 calibration 拉進部署門檻？** 對 *運彩分析師* persona，
> over-confident 的 0.7 機率（實際只贏 55 %）會直接造成虧損。
> Accuracy 高且 calibration 差 → 商業上失敗。

### 7.2 Secondary metrics

於所有報表上同步呈現，但不作為 go / no-go：

- Accuracy @ threshold 0.5
- F1 (positive = `is_home_win = 1`)
- Brier score
- Log-loss
- **Decision-curve net benefit @ threshold 0.55**（最貼近下注決策）

### 7.3 Calibration & fairness targets

- **Calibration**：reliability diagram（10 bins, equal-frequency）+ slope/intercept of `glm(y ~ logit_p)` 應 (≈ 1, ≈ 0)。
- **Fairness (stratified eval)**：對每個 `stadium` 與每個 `home_team` 分層回報 AUC + Brier。樣本 < 30 的層級獨立標註（不要被 micro-average 蓋掉）。
  - 已知小樣本層：臺北大巨蛋（2024 才啟用），台鋼雄鷹（2024 擴編）。

---

## 8. Power & Sample-Size Analysis

### 8.1 我們想偵測什麼大小的效應？

ΔAUC = **0.03** — 文獻 (Hanley & McNeil, *Radiology* 1982, 取得時間
2025-Q1，用其變異公式) 上常見的 "small-but-useful" 切點。

### 8.2 計算 (back-of-envelope)

對 AUC 比較的樣本數近似（兩個相關 ROC 曲線、prevalence ≈ 0.54）：

> n ≈ z² · σ² / Δ², 其中 σ² ≈ AUC(1 – AUC) · (correction factor for paired
> design ≈ 0.5)

取 AUC₀ ≈ 0.55、α = 0.05（z = 1.96）、power = 0.80（z = 0.84）：

| 量 | 值 |
|---|---|
| σ² (paired, AUC ≈ 0.55) | ≈ 0.55 · 0.45 · 0.5 ≈ 0.124 |
| (z_α + z_β)² | (1.96 + 0.84)² ≈ 7.84 |
| n ≈ 7.84 · 0.124 / 0.03² | **≈ 1 080 場** |

### 8.3 對照可得樣本

| 來源 | 預估場數 |
|---|---|
| CPBL 一季例行賽 | ≈ 240 |
| 2020 – 2024（5 季） | **≈ 1 200** |
| 扣 10 % 雨延 / 缺資料 / 平手 | ≈ 1 080 |

**結論**：樣本剛好踩在 ΔAUC = 0.03 的可偵測線上，因此：

1. 一定要做 paired test（不可用 two-sample），否則 effective n 砍半。
2. 子群分析（單一球場、單一隊伍）會 *underpower*，須先在報告中聲明。
3. 若 data-collector 回報實際可用樣本 < 900，立刻回頭收斂目標：先做
   *stadium-only* 模型，weather 留待未來年度補資料。

---

## 9. Risk Register

| # | 風險 | 嚴重度 | 機率 | 緩解 |
|---|---|---|---|---|
| R1 | **Selection bias — 雨延 / 取消** | 高 | 中 | 取消場次顯然偏向露天球場 → 在 weather 模型上會低估雨天負面效應。緩解：保留「原排程但未開打」flag，敏感性分析時納入 |
| R2 | **Concept drift — 規則 / 球員 / 球場異動** | 高 | 高 | 大巨蛋 2024 啟用、台鋼 2024 擴編、洋將額度與 ABS 系統試行可能改變賽季結構。緩解：在 §7 fairness 階段分層；最終模型加上 `season` fixed effect 作 sanity check |
| R3 | **Data leakage — 後驗特徵** | 災難級 | 低 | 嚴禁使用 `away_score`, `total_runs`, `winning_pitcher` 等場後欄位。緩解：在 §10 hand-off 明列「賽前可得」欄位白名單；data-collector 必須遵守 |
| R4 | **Weather station outage / 缺值** | 中 | 中 | CWA 觀測站偶有斷訊；某些球場（嘉義、澄清湖）距離最近測站 > 5 km。緩解：data-collector 須記錄 `station_id`, `station_distance_km`, `obs_lag_min`；EDA 階段建立 missingness audit；超過 X % 缺值的場次列為 sensitivity check |
| R5 | **Class imbalance** | 低 | 高 | 主隊勝率 ≈ 0.54，僅輕微不平衡，不需 SMOTE。緩解：以 Brier / log-loss 監督，避免 accuracy 一面倒 |
| R6 | **小樣本層級的不穩定預測** | 中 | 高 | 臺北大巨蛋 2024 才啟用，台鋼 2024 擴編，可能單一場館 < 50 場。緩解：在 §7.3 對小樣本層明標 CI；模型部署版可考慮 partial pooling (mixed effect) |
| R7 | **WebScrape 反爬 / ToS 變動** | 中 | 中 | CPBL 官網結構可能改版。緩解：data-collector 抓取需有 retry + provenance manifest；snapshot 原始 HTML/JSON 7 天 |

---

## 10. Hand-off to Sub-Agent 2 (Data Collector)

### 10.1 必交付的兩張表

#### `data/raw/raw_games.csv`

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `game_id` | character | ✅ | e.g. `20231015-G01`，唯一 |
| `date` | Date (ISO 8601) | ✅ | 比賽日 |
| `scheduled_start_ts` | datetime (Asia/Taipei) | ✅ | 排定開賽時間，用於對齊天氣觀測 |
| `season` | integer | ✅ | e.g. 2023 |
| `stadium` | factor | ✅ | 七個 levels，見 §4.2 |
| `home_team` | factor | ✅ | 主隊代碼 |
| `away_team` | factor | ✅ | 客隊代碼 |
| `home_score` | integer | ✅ | 主隊得分（僅供生成 Y，建模不得使用） |
| `away_score` | integer | ✅ | 客隊得分（僅供生成 Y，建模不得使用） |
| `is_home_win` | factor {0,1} | ✅ | 由 score 推導；ties 為 `NA` 並 drop |
| `is_completed` | logical | ✅ | 是否完整打完九局 / 七局 |
| `is_postponed` | logical | ✅ | 雨延旗標（用於 R1 sensitivity） |
| `source_url` | character | ✅ | 原始抓取頁面 |

#### `data/raw/raw_weather.csv`

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `game_id` | character | ✅ | 對齊 raw_games |
| `station_id` | character | ✅ | CWA 測站 ID |
| `station_distance_km` | numeric | ✅ | 球場到測站距離（直線） |
| `obs_ts` | datetime | ✅ | 觀測時間（取 scheduled_start_ts 前 60 min 最近觀測） |
| `obs_lag_min` | integer | ✅ | abs(scheduled_start_ts − obs_ts) in minutes |
| `temperature` | numeric (°C) | ✅ | |
| `humidity` | numeric (%) | ✅ | |
| `wind_speed` | numeric (m/s) | ✅ | |
| `wind_dir` | factor (8-pt) | ⚠️ optional | stretch goal |
| `is_dome` | logical | ✅ | TRUE 時上述變數僅供 EDA，不進 m3/m5/m6/m7 |
| `source_url` | character | ✅ | CWA API endpoint |

#### `data/raw/_provenance/manifest.json`

| 欄位 | 說明 |
|---|---|
| `fetched_at` | ISO 8601 timestamp |
| `git_sha` | data-collector commit hash |
| `row_counts` | per-table |
| `dropped_rows` | with reason codes (`tie`, `postponed`, `incomplete`, `weather_missing`) |
| `sources` | 對每個來源網址記錄 HTTP status + retry 次數 |

### 10.2 Join keys

| Left | Right | Key |
|---|---|---|
| `raw_games` | `raw_weather` | `game_id` (主) ；備援 `date × stadium` |

### 10.3 Open questions (請 Sub-Agent 2 回答後 patch 本 charter)

1. 2020 球季因 COVID 部分閉門賽是否要旗標 `is_no_audience` 加入 Group A？
   *目前 charter 不納入；待資料盤點後決定。*
2. 大巨蛋 2024 春訓暖身賽要不要保留作為 dome 行為的初始 EDA？
   *建議：保留但不進建模，僅做 EDA 註腳。*
3. wind_dir 的 8-point 編碼在 CWA API 中是 degrees 還是字串？決定特徵
   工程做 one-hot 或 sin/cos。
4. 是否有來自 Rebas JSON 的 *先發投手手別 (L/R)*？若有，留作 v2 feature。
5. 嘉義 / 澄清湖到最近 CWA 測站超過 5 km 的場次預估佔多少？這直接決定
   §8 power 分析的 effective n。

### 10.4 Re-entry condition

當 Sub-Agent 2 完成兩張 raw 表後，goal-definer **必須** 重新審視：

- §3.3 scope window 是否仍可達 §8 power 門檻？
- §6 模型清單是否需要砍掉（例如 weather 樣本不足，m3/m5/m7 降級）？

> **這個 loop 是設計的一部分** — Define-the-Goal 與 Collect-Data 之間
> 是雙向箭頭，不是單向 hand-off。

---

## Appendix A. References

| 編號 | 來源 | 取用日期 | 用途 |
|---|---|---|---|
| A1 | Baseball Reference, League Splits 2014 – 2024 | 2025-Q1 | MLB 主場勝率 ≈ 54 % 基準 |
| A2 | Alan Nathan, *The Physics of Baseball* (4th printing) | 2011 | 風速 / 氣溫對飛球距離的物理估計 |
| A3 | Hanley J. A. & McNeil B. J., "The Meaning and Use of the Area under a ROC Curve", *Radiology* 143:29 – 36 | 1982 | AUC 變異與 sample-size 公式 |
| A4 | DeLong E. R. et al., "Comparing the areas under two or more correlated ROC curves", *Biometrics* 44:837 – 845 | 1988 | Paired AUC 比較 |
| A5 | 中央氣象署 CWA Open Data 使用條款 | 2025-Q1 | 天氣資料合法來源 |
| A6 | CPBL 官網賽程頁 (`https://www.cpbl.com.tw/schedule`) | 2025-Q1 | 賽程 + 球場 metadata |
| A7 | 野球革命 (Rebas) box-score JSON | 2025-Q1 | 逐場結果 |

> **註**：A1 – A4 的具體數值與引用頁碼將由 data-collector 在抓取真實
> 資料時 *回填* 並交叉驗證。本 charter 不展示未經本專案資料驗證的
> 二手統計。

## Appendix B. Glossary

| 縮寫 / 術語 | 中文 / 解釋 |
|---|---|
| **HFA** | Home Field Advantage，主場優勢 |
| **AUC** | Area Under ROC Curve，分類器排序能力 |
| **Brier score** | 機率預測的均方誤差，校準與分辨同時納入 |
| **Calibration slope** | reliability diagram 上 logit(p̂) vs logit(p_true) 的回歸斜率，理想 = 1 |
| **DeLong test** | 對 paired ROC curve 比較 AUC 的非參數檢定 |
| **LRT** | Likelihood-Ratio Test，巢狀模型比較 |
| **Park Factor** | 同一聯盟內，把某球場的得分 / HR 率正規化後的乘子 |
| **POC** | Proof of Concept，最小可行驗證 |
| **Time-aware split** | 以時間為界切分 train / test，避免未來資料洩漏 |
| **`tidymodels`** | R 生態系下的統一建模介面（recipes + parsnip + tune + yardstick + workflows） |
