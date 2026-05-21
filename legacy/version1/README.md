# legacy/version1/

本資料夾保存 **data-analysis 分支在切換到 feature-engineering 結構之前**
的完整 v1 快照（2026 年 5 月）。所有檔案保持原始位置，便於追溯。

## 內容

| 項目 | 用途 |
|---|---|
| `README.md` | 原 repo 入口（114-2 Data Science 字串）|
| `CLAUDE.md` | 給 Claude Code 的專案指引 / 慣例 |
| `requirements.R` | R 套件相依清單 |
| `R/build_recipes.R` | 用 `recipes` 套件建構 ML 前處理 pipeline 的 helper |
| `R/elo_pythag.R` | Elo / Pythagorean expectation 計算（球隊強度估計）|
| `scripts/00_session_info.R` | print sessionInfo（環境快照）|
| `scripts/00_synthetic_smoke.R` | 合成資料 smoke test |
| `scripts/03a_phase_a_poc.R` | Phase A POC：跑 baseline 模型 |
| `models/poc/strategy_memo.md` | 模型策略筆記 |
| `Results/01_define_the_goal.md` | Stage 1 目標定義文件 |
| `Results/v1_final_report.html` | v1 完整報告（包含完整模型結果與圖表，~1 MB）|
| `.claude/agents/` | 6 個 Claude Code 子代理人定義（goal-definer 到 shiny-deployer）|
| `.claude/skills/find-skills/` | find-skills 技能設定 |

## 為何收進 legacy/

新版（top-level）已切換到 `data_science_final_project@feature-engineering`
的結構：Python notebook + Data/Scripts/Results/docs 四層分類。本 v1
snapshot 保留作為對照——學長學弟想看當時的 R 程式碼、agents 設計或
v1 報告時直接到這裡找。

## 對應的新版位置

| 舊位置 | 新版位置（在 repo 根目錄） |
|---|---|
| `Results/v1_final_report.html` | `Results/notebook_executed.html`（新版 HTML 報告）|
| `R/`、`scripts/` | `Scripts/cpbl_unsupervised_feature_discovery.ipynb`（單一 Python notebook 替代）|
| `models/poc/` | `Results/stage5/` 的 cluster 與 PCA artifacts |
| `CLAUDE.md` | 移除（沒有跨檔案的全域指引；專案文件改放 `docs/`）|
