# Projection Version

這個資料夾是目前 Shiny prototype 的獨立展示版本。

## 模型構想

在資料分析時，我們發現一個值得注意的現象：主場勝率雖然高於客場，但是主場得分卻低於客場得分。這代表「得分多寡」不一定能完整解釋勝負，於是我們開始思考：比賽的節奏與情勢推動，可能是影響勝負的重要因素。

因此，目前的預測模型不是只單純預測某一局會不會得分，而是嘗試用「推動情勢」的方式來預測後續結果。

我們的構想是利用類似state transform 的架構，依據現在的局勢預測該半局可能會收斂成哪一種 state，例如：

```text
安靜無得分
攻勢浪費
單分進帳
多分進帳
大局形成
```

接著，再用每局預測出的 state 與目前的比分、局段、主客場、對戰組合等資訊，去比對是否類似過往比賽中的某些 pattern，進一步推估未來勝負的可能性。

換句話說，目前模型的核心想法是：

```text
目前局勢
-> 預測這局可能形成的 result state
-> 用 result state 推動比賽情勢
-> 對照歷史相似 pattern
-> 預測後續勝負機率
```

## 內容

```text
projection/app.R
projection/data/stage1_result_state_stage2_win_bridge_output.csv
projection/data/batter_type_profile.csv
projection/data/pitcher_type_profile.csv
```

## 目前功能

使用者可以輸入：

```text
局數
主場 / 客場進攻
進攻方分差
base-out state
真實打者
真實投手
```

系統會輸出：

```text
Stage 1：五類半局結果 state 機率
Stage 2：各 result state 對應勝率
加權後 win probability
```

五類 result state：

```text
安靜無得分
攻勢浪費
單分進帳
多分進帳
大局形成
```

## 資料來源

`stage1_result_state_stage2_win_bridge_output.csv` 來自：

```text
prediction/46_build_stage1_result_state_stage2_win_bridge.R
```

它包含：

```text
Stage 1 result-state probability distribution
各 result state 對應的 Stage 2 win probability
weighted_result_bridge_win_probability
```

`batter_type_profile.csv` 與 `pitcher_type_profile.csv` 用來讓前端選擇真實球員，並自動帶入球員類型與簡要 profile。

## 目前限制

這個版本仍是 lookup-based prototype。

目前流程是：

```text
選真實球員
-> 自動帶入 batter / pitcher type
-> 用球員類型與局勢查相似歷史情境
-> 估計 result-state distribution 與 weighted win probability
```

也就是說，模型尚未即時使用每位球員的完整分數重新計算 transition probability。若兩位球員屬於同一類型，或相似情境樣本不足導致 fallback 到粗層級，畫面變化可能不明顯。

目前 Stage 1 lookup 會依序嘗試：

```text
同局勢 + 真實打者 + 真實投手
同局勢 + 打者類型 + 投手類型
同局勢 + 真實打者
同局勢 + 真實投手
同局勢
base-out
global
```

畫面上的「Stage 1 查詢層級 / 樣本數」可以用來判斷這次預測是否真的吃到球員資訊。樣本數越小，對戰組合影響會越明顯，但穩定性也會比較低。
