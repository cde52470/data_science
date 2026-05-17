# Analysis Scripts

此資料夾是給組員看的整理版分析程式。請從專案根目錄執行。

## 一鍵重跑

```bash
Rscript share_analyze/run_all_analysis.R
```

## 腳本流程

| 順序 | 腳本 | 目的 |
| --- | --- | --- |
| 1 | `01_build_team_game_features.R` | 建立 team-game-level 特徵、語意標籤、主客場摘要 |
| 2 | `02_eda_home_away.R` | 主客場整體 EDA 與圖表 |
| 3 | `03_eda_status_labels.R` | 狀態標籤在主客場的分布分析 |
| 4 | `04_prepare_model_dataset.R` | 建立 descriptive model dataset |
| 5 | `05_train_descriptive_models.R` | 訓練 logistic descriptive models |
| 6 | `06_cross_validate_descriptive_models.R` | Controlled logistic 5-fold CV |
| 7 | `07_visualize_model_results.R` | Logistic 模型結果視覺化 |
| 8 | `08_train_tree_models.R` | Random Forest 與 permutation importance |
| 9 | `09_cv_tree_models.R` | Random Forest 5-fold CV 與重要性圖 |
| 10 | `10_xgboost_shap_analysis.R` | XGBoost、CV、Gain importance、SHAP importance |
| 11 | `11_visualize_xgboost_and_model_comparison.R` | XGBoost/SHAP 圖與三模型比較 |
| 12 | `12_feature_importance_consensus.R` | 跨模型特徵重要性共識 |
| 13 | `13_tune_xgboost_limited.R` | Limited XGBoost tuning |
| 14 | `14_update_model_comparison_with_tuned_xgboost.R` | 加入 tuned XGBoost 的模型比較 |
| 15 | `15_create_model_labeled_dataset.R` | 建立模型標記資料 |

## 目前分析定位

目前成果是 **game-context labeling model**，目標是將比賽資料轉換成可解釋的場景資訊，而不是最終的打席預測模型。

主要輸出：

```text
data/cleaned/team_game_features.csv
data/cleaned/team_home_away_summary.csv
data/cleaned/model_dataset_win.csv
data/cleaned/team_game_model_labeled.csv
```

重要圖表與模型輸出位於：

```text
outputs/
```
