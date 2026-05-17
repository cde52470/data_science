# Analysis Workflow and Findings

## 1. 資料與分析單位

原始資料：

```text
data/raw/CPBL-2024-OpenData/CPBL-2024-OpenData.json
```

資料內容為 2024 年 CPBL 例行賽 360 場比賽。

本分析主要使用 team-game-level：

```text
一列 = 一支球隊在一場比賽中的表現
```

因此 360 場比賽會轉換成 720 筆 team-game 資料。

## 2. 特徵工程

主要程式：

```text
share_analyze/01_build_team_game_features.R
```

此步驟建立：

- 主客場欄位
- 得分、失分、分差
- 逐局節奏特徵
- 進攻效率特徵
- 防守/投手效率特徵
- 語意化標籤

主要語意標籤包括：

```text
home_away_label
result_label
run_diff_label
scoring_level
allowing_level
game_flow_label
offense_label
defense_label
```

## 3. 主客場 EDA

主要程式：

```text
share_analyze/02_eda_home_away.R
share_analyze/03_eda_status_labels.R
```

整體主客場結果：

```text
主場勝率：52.5%
客場勝率：46.9%
主場平均分差：-0.086
客場平均分差： 0.086
```

這代表主場勝率略高，但平均分差沒有同步呈現明顯優勢。

狀態標籤 EDA 顯示：

- 主客場「火力強勢」比例相同，皆為 19.7%。
- 主場「穩定攻擊」比例較高。
- 主場「穩定守成」比例較高。
- 客場「被壓制型」比例較高。

因此，主場優勢較可能不是單純火力更強，而是與攻勢穩定、守成能力與局勢維持有關。

## 4. Descriptive Model

主要程式：

```text
share_analyze/04_prepare_model_dataset.R
share_analyze/05_train_descriptive_models.R
share_analyze/06_cross_validate_descriptive_models.R
```

目前模型屬於 descriptive model，不是賽前預測模型。模型使用賽後與比賽過程資訊，用來解釋哪些特徵與勝負有關。

Controlled logistic model 移除過度直接反映勝負的欄位：

```text
runs_scored
runs_allowed
run_diff
led_after_6
offense_pressure_score
run_prevention_score
```

Controlled logistic 5-fold CV 結果：

```text
accuracy    0.9320
sensitivity 0.9386
specificity 0.9254
precision   0.9264
f1          0.9322
```

## 5. Random Forest 與 XGBoost

主要程式：

```text
share_analyze/08_train_tree_models.R
share_analyze/09_cv_tree_models.R
share_analyze/10_xgboost_shap_analysis.R
share_analyze/11_visualize_xgboost_and_model_comparison.R
```

三模型 5-fold CV 結果：

```text
Controlled Logistic
accuracy: 0.9320
f1:       0.9322

XGBoost
accuracy: 0.9250
f1:       0.9268

Random Forest
accuracy: 0.9209
f1:       0.9221
```

三個模型表現皆約 92% 以上，表示目前建立的特徵對勝負具有穩定解釋能力。

## 6. Limited XGBoost Tuning

主要程式：

```text
share_analyze/13_tune_xgboost_limited.R
share_analyze/14_update_model_comparison_with_tuned_xgboost.R
```

Limited tuning 測試 72 組參數，每組使用 5-fold CV。

最佳參數：

```text
max_depth:        4
eta:              0.05
subsample:        0.8
colsample_bytree: 0.8
nrounds:          200
```

調參後比較：

```text
Controlled Logistic accuracy: 0.9320
Controlled Logistic F1:       0.9322

Untuned XGBoost accuracy:     0.9250
Untuned XGBoost F1:           0.9268

Tuned XGBoost accuracy:       0.9319
Tuned XGBoost F1:             0.9332
```

XGBoost tuning 後幾乎追平 Logistic，F1 略高，但差距很小。這表示 XGBoost 合理調參後確實改善，但 Logistic 仍適合作為主要解釋模型。

## 7. 為什麼 Tuning 可能改善 XGBoost？

Tuning 可能讓模型變好的原因包括：

1. `max_depth` 調整模型複雜度，避免太簡單或太複雜。
2. `eta` 控制學習速度，較小步伐可讓模型更穩定。
3. `subsample` 與 `colsample_bytree` 讓每棵樹只看部分資料與特徵，可降低 overfitting。
4. `nrounds` 控制 boosting 輪數，足夠輪數可讓模型逐步修正錯誤。

本次最佳參數顯示，資料中可能存在一定程度的特徵互動，但不需要過度複雜的模型。

## 8. XGBoost SHAP 與特徵重要性

XGBoost Gain 與 SHAP 皆指出相似的重要特徵：

```text
run_per_hit
innings_pitched
whip_like
H
hits_allowed
hr_allowed
scored_first
```

這代表勝負解釋不只看總分，而是與安打得分轉換效率、投手/防守壓制、上壘壓力、被安打、被全壘打與先得分有關。

## 9. 跨模型特徵重要性共識

主要程式：

```text
share_analyze/12_feature_importance_consensus.R
```

整合來源：

- Controlled logistic coefficient
- Random Forest permutation importance
- XGBoost Gain
- XGBoost SHAP

跨模型共識前幾名：

```text
1. run_per_hit        進攻效率
2. innings_pitched    防守/投手效率
3. H                  進攻效率
4. scored_first       得分節奏
5. whip_like          防守/投手效率
6. hr_allowed         防守/投手效率
7. hits_allowed       防守/投手效率
8. AB                 進攻效率
9. middle_runs        得分節奏
10. late_runs         得分節奏
```

此結果表示，不同模型雖然演算法不同，但多數都指向相近的核心特徵。

## 10. 模型標記資料

主要程式：

```text
share_analyze/15_create_model_labeled_dataset.R
```

正式輸出：

```text
data/cleaned/team_game_model_labeled.csv
```

新增模型標記欄位：

```text
model_predicted_result
model_win_probability
model_confidence_label
model_correct
model_prediction_type
```

信心標籤分布：

```text
高信心 664 筆，92.2%
中信心 40 筆，5.6%
低信心 16 筆，2.2%
```

預測類型：

```text
模型判斷勝且實際勝 338
模型判斷敗且實際敗 340
模型判斷勝但實際敗 22
模型判斷敗但實際勝 20
```

這代表目前已完成用模型對資料進行分類與標記。

## 11. 目前主軸結論

目前分析支持以下說法：

> 2024 年 CPBL 主場勝率略高於客場，但平均分差並未同步擴大。從 EDA、語意化標籤、controlled logistic model、Random Forest、XGBoost 與 SHAP 結果來看，主場優勢不是單純來自火力爆發，也不是由主客場欄位直接主導，而較可能透過攻勢穩定性、守成能力、投手壓制與比賽節奏維持間接呈現。

這也是目前 context labeling model 的主要價值：把原始數字轉換成可解釋的場景資訊，供未來更細粒度的打席預測模型使用。
