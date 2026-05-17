# Context Labeling Model Design

## 目前模型定位

目前建立的是：

```text
game-context labeling model
```

它不是最終打席預測模型，而是把比賽資料轉換成場景資訊的中間層。

目前角色：

```text
原始比賽資料
→ team-game 特徵
→ 語意化標籤
→ 模型輔助標記
→ 未來打席預測模型可使用的 context input
```

## 為什麼需要場景標記？

原始數字本身可以進模型，但不一定能直接表達比賽情境。例如：

```text
H = 10
BB = 4
HR = 1
```

這些數字可以進一步轉換成：

```text
穩定攻擊
高得分
火力強勢
```

場景標記的目的，就是把數字轉成較有解釋力的資訊。

## 目前已建立的場景標籤

目前資料已包含：

```text
home_away_label
result_label
run_diff_label
scoring_level
allowing_level
game_flow_label
offense_label
defense_label
model_confidence_label
model_prediction_type
```

這些標籤可以描述：

- 主客場情境
- 勝負結果
- 得失分強度
- 比賽節奏
- 進攻狀態
- 防守/投手狀態
- 模型對該場景的判斷信心

## 目前分析得到的 Context 主軸

目前分析顯示：

```text
主場勝率略高，但平均分差沒有明顯同步提升。
```

跨模型重要性中，`is_home` 不是最核心的直接特徵。更重要的是：

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

因此目前的解釋是：

> 主場影響更可能透過攻守效率、投手壓制與比賽節奏間接呈現，而不是由主客場欄位直接決定勝負。

## 與未來打席預測模型的銜接

未來若要做打席預測，可以拆成三層：

```text
Layer 1: Context Labeling Model
Layer 2: Player Recent Form Features
Layer 3: Plate Appearance Prediction Model
```

### Layer 1: Context Labeling Model

負責提供比賽情境，例如：

```text
比賽節奏
球隊攻擊狀態
球隊防守狀態
主客場情境
目前是否屬於高壓場景
```

### Layer 2: Player Recent Form Features

負責整理球員近期狀態，例如：

```text
近 N 場打擊表現
近 N 打席上壘率
近 N 打席長打率
近期三振率
近期四壞率
投手近期壓制狀態
```

### Layer 3: Plate Appearance Prediction Model

未來可以預測：

```text
是否上壘
是否安打
是否長打
是否三振
是否四壞球
打席結果類型
```

## Data Leakage 注意事項

目前的 team-game labels 是賽後整理出來的，所以不能直接拿去預測同一場比賽中的打席。

未來若要做 PA-level prediction，只能使用該打席發生前已知的資訊，例如：

```text
當下局數
當下出局數
當下壘上狀態
當下分差
目前雙方累積得分
投手目前已投球數
打者近期 rolling features
投手近期 rolling features
球隊賽前或打席前狀態
```

不能使用該打席之後才知道的資訊，例如：

```text
該場最終勝敗
該場最終總得分
該場最終安打數
該場最終投手表現
整場比賽結束後才知道的 game_flow_label
```

## 現階段結論

目前工作已完成 context labeling 的第一版原型。它的價值是把原始比賽數據轉成可解釋場景資訊，未來可作為打席預測模型的 context layer 設計基礎。
