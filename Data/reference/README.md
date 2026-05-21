# Data/reference/

對照組與外部參考資料。

## 目前內容

（空。本資料夾預留給跨 repo / 跨研究的快照。）

## 預計放置

- **Wang 學長 2024 cleaned features**：來自
  [`cde52470/data_science@analyze_wang`](https://github.com/cde52470/data_science/tree/analyze_wang)
  的 `data/cleaned/team_game_features.csv`。
  notebook Stage 2.7a 目前直接用
  `git -C /home/user/data_science show origin/analyze_wang:data/cleaned/team_game_features.csv`
  讀檔；若想在沒有該本機 clone 的環境下重現，可手動 `wget` / `curl` 一份過來。

- 未來其他研究的對照 CSV / parquet（請以一致命名習慣 `{owner}_{repo}_{branch}_{purpose}.{ext}` 命名）。
