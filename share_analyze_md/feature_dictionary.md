# Feature Dictionary

此文件整理目前主要輸出資料的欄位意義。完整資料主要有兩份：

```text
data/cleaned/team_game_features.csv
data/cleaned/team_game_model_labeled.csv
```

分析單位為 team-game-level：

```text
一列 = 一支球隊在一場比賽中的表現
```

## 基礎欄位

| 欄位 | 意義 |
| --- | --- |
| `game_id` | 比賽識別碼 |
| `team` | 此列代表的球隊 |
| `opponent` | 對手 |
| `season` | 球季 |
| `seq` | 比賽序號 |
| `date` | 比賽時間 |
| `stadium` | 球場 |
| `is_home` | 是否為主場 |
| `home_away_label` | 主場 / 客場 |

## 勝負與得失分欄位

| 欄位 | 意義 |
| --- | --- |
| `runs_scored` | 該隊得分 |
| `runs_allowed` | 該隊失分 |
| `run_diff` | 得失分差 |
| `win` | 是否勝利 |
| `result_label` | 勝 / 敗 / 和局 |
| `run_diff_label` | 大勝 / 小勝 / 小敗 / 大敗 / 平手 |
| `scoring_level` | 低得分 / 中等得分 / 高得分 |
| `allowing_level` | 低失分 / 中等失分 / 高失分 |

## 得分節奏與局勢欄位

| 欄位 | 意義 |
| --- | --- |
| `early_runs` | 第 1-3 局得分 |
| `middle_runs` | 第 4-6 局得分 |
| `late_runs` | 第 7-9 局得分 |
| `scored_first` | 是否先得分 |
| `led_after_3` | 3 局結束是否領先 |
| `led_after_6` | 6 局結束是否領先 |
| `game_flow_label` | 比賽節奏類型，例如全場壓制型、後段逆轉型、被壓制型 |

## 進攻效率欄位

| 欄位 | 意義 |
| --- | --- |
| `AB` | 打數 |
| `H` | 安打 |
| `BB` | 四壞球 |
| `SO` | 被三振 |
| `double` | 二壘安打 |
| `triple` | 三壘安打 |
| `HR` | 全壘打 |
| `extra_base_hits` | 長打總數，`double + triple + HR` |
| `power_score` | 長打威脅分數，`double + 2 * triple + 3 * HR` |
| `run_per_hit` | 安打得分轉換效率，`runs_scored / H` |
| `offense_pressure_score` | 簡化攻勢壓力分數 |
| `offense_label` | 火力強勢 / 穩定攻擊 / 攻勢受阻等 |

## 防守與投手效率欄位

| 欄位 | 意義 |
| --- | --- |
| `outs_pitched` | 投球出局數 |
| `innings_pitched` | 投球局數 |
| `hits_allowed` | 被安打 |
| `bb_allowed` | 投手四壞球 |
| `hr_allowed` | 被全壘打 |
| `so_pitched` | 投手三振 |
| `whip_like` | 類 WHIP，`(hits_allowed + bb_allowed) / innings_pitched` |
| `strikeout_walk_ratio` | 三振保送比 |
| `run_prevention_score` | 簡化失分壓制分數 |
| `defense_label` | 壓制力強 / 穩定守成 / 失分偏高等 |

## 模型標記欄位

以下欄位位於：

```text
data/cleaned/team_game_model_labeled.csv
```

| 欄位 | 意義 |
| --- | --- |
| `model_predicted_result` | 模型判斷勝或敗 |
| `model_win_probability` | 模型預測勝率 |
| `model_confidence_label` | 高信心 / 中信心 / 低信心 |
| `model_correct` | 模型判斷是否正確 |
| `model_prediction_type` | 模型判斷勝且實際勝、模型判斷敗但實際勝等 |

## 欄位設計目的

這些欄位不是只為了模型輸入，也用來把原始棒球數字轉換成可解釋的場景資訊。未來若進入打席預測，這些概念可以轉換成打席發生前可取得的 context features。
