# Project Overview

## 專案目的

本專案使用 2024 年 CPBL 例行賽資料，建立一個 **game-context labeling model**。

目前模型的目的不是直接做未來打席預測，而是先把原始比賽數據整理成可解釋的場景資訊，作為未來打席預測模型的 context input。

整體概念如下：

```text
原始比賽資料
→ team-game-level 特徵
→ 語意化標籤
→ descriptive model / tree model / XGBoost + SHAP
→ 模型標記資料
→ 未來打席預測模型可使用的場景資訊
```

## 目前已完成內容

目前已完成：

1. 建立 team-game-level 資料。
2. 建立主客場、進攻、防守、得分節奏與比賽局勢特徵。
3. 建立語意化標籤，例如穩定攻擊、壓制力強、後段逆轉型。
4. 建立 descriptive model dataset。
5. 建立 controlled logistic model。
6. 使用 5-fold cross-validation 評估模型。
7. 建立 Random Forest 與 XGBoost 模型。
8. 使用 permutation importance、XGBoost Gain 與 SHAP 解釋模型。
9. 進行 limited XGBoost tuning。
10. 建立跨模型特徵重要性共識。
11. 將模型預測結果合併回完整資料，產出 model-labeled dataset。

## 目前主要資料產出

| 檔案 | 說明 |
| --- | --- |
| `data/cleaned/team_game_features.csv` | 每隊每場一列的完整特徵資料 |
| `data/cleaned/team_home_away_summary.csv` | 各隊主客場表現摘要 |
| `data/cleaned/model_dataset_win.csv` | descriptive model 使用的資料 |
| `data/cleaned/team_game_model_labeled.csv` | 加入模型標記後的正式資料 |

## 目前主要模型

| 模型 | 角色 |
| --- | --- |
| Controlled Logistic | 主要解釋模型，清楚、穩定、可解釋 |
| Random Forest | 非線性模型佐證，提供 permutation importance |
| XGBoost | 非線性模型與 SHAP 佐證 |
| Tuned XGBoost | 確認合理調參後是否能超越 baseline |

## 目前核心結論

2024 年 CPBL 主場勝率略高於客場，但平均分差沒有同步擴大。進一步分析顯示，主場優勢不是單純來自火力爆發，也不是由主客場欄位直接主導，而較可能透過以下因素間接呈現：

- 攻勢穩定性
- 守成能力
- 投手/防守壓制
- 比賽節奏維持
- 先得分與中後段得分能力

跨模型重要性共識顯示，重要特徵集中在：

```text
run_per_hit
innings_pitched
H
scored_first
whip_like
hr_allowed
hits_allowed
middle_runs
late_runs
```

這些特徵對未來建立打席預測模型的 context layer 有參考價值。
