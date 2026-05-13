# ============================================================================
# File   : R/elo_pythag.R
# Purpose: Pure functions for team-strength feature engineering — Elo (MoV-
#          adjusted with HFA), Pythagenpat win expectancy, and rest-days.
# Author : Sub-Agent 4 (model-builder)
# Date   : 2026-05-13
# ============================================================================

# 本檔提供三個獨立函式, 任何 script (POC 或 production) 都可 source() 後用:
#   compute_elo()         -> 賽前 Elo (home_elo_pre, away_elo_pre)
#   compute_pythagenpat() -> 30 場滾動 Pythag 勝率
#   compute_rest_days()   -> 距上一場休息天數 (cap 5)
#
# 所有函式接收按 `date` 升冪排序的 tibble (每列一場比賽), 並回傳新增 *_pre
# 欄位的 tibble。**不變更 row 順序, 不刪除 row。**
#
# 嚴禁在這些函式內使用同場比賽的 `home_score` / `away_score` 來推出當場
# Elo (這是經典 future-leakage); 賽前 Elo 必須只用該隊「在此之前」的歷史。

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
})

# ---- config defaults --------------------------------------------------------
ELO_DEFAULTS <- list(
  k_factor       = 4,          # baseball convention: 棒球單場資訊量低, K 設小
  hfa_elo        = 24,         # ≈ +0.03 win prob bump, 文獻 MLB 估計
  mov_alpha      = 0.6,        # margin-of-victory exponent
  mov_beta       = 2.2,        # MoV log-shift constant
  init_rating    = 1500
)

PYTHAG_DEFAULTS <- list(
  window         = 30,         # 過去 30 場 (隊伍視角)
  exponent       = 1.83        # Pythagenpat exponent for baseball
)

REST_CAP <- 5L                  # rest_days 超過 5 天視同 5 (capped)

# ---------------------------------------------------------------------------
# compute_elo()
# ---------------------------------------------------------------------------
# 從零開始 sequentially 跑 Elo, 同時把 home_elo_pre / away_elo_pre 寫回。
# 加上 K=4, MoV-adjusted (Silver / 538 風格), HFA = +24 (charter amendment #1).
#
# Args:
#   games: tibble with columns
#          c(game_id, date, home_team, away_team, home_score, away_score)
#   k_factor:    Elo K 係數 (default 4)
#   hfa_elo:     主場 Elo 加成 (default 24)
#   init_rating: 新隊伍初始 Elo (default 1500)
# Returns:
#   原 tibble + home_elo_pre, away_elo_pre, home_elo_post, away_elo_post

compute_elo <- function(games,
                        k_factor    = ELO_DEFAULTS$k_factor,
                        hfa_elo     = ELO_DEFAULTS$hfa_elo,
                        mov_alpha   = ELO_DEFAULTS$mov_alpha,
                        mov_beta    = ELO_DEFAULTS$mov_beta,
                        init_rating = ELO_DEFAULTS$init_rating) {

  stopifnot(
    all(c("game_id", "date", "home_team", "away_team",
          "home_score", "away_score") %in% names(games))
  )

  # 嚴格按時間順序; tie-breaker 用 game_id 字典序保證 deterministic
  games <- games |>
    arrange(.data$date, .data$game_id)

  # Coerce team columns to character ONCE.
  # 原因: 03a_phase_a_poc.R 進來時 home_team/away_team 是 factor
  # (dplyr::mutate(... as.factor)). 用 factor 做 `list[[x]]` 會被 R 內部
  # 強制轉成 integer (factor level number), 結果在空 list 上觸發
  # "subscript out of bounds". 必須以 character 做 list key 才正確。
  # 詳見 GHA run 25790218754 / 25790217325 fail trace.
  team_chr <- list(
    home = as.character(games$home_team),
    away = as.character(games$away_team)
  )

  # rating cache, list-keyed by team **character** name
  ratings <- list()
  get_rating <- function(team) {
    team <- as.character(team)   # defensive double-coerce
    if (is.null(ratings[[team]])) init_rating else ratings[[team]]
  }

  n <- nrow(games)
  home_pre  <- numeric(n)
  away_pre  <- numeric(n)
  home_post <- numeric(n)
  away_post <- numeric(n)

  for (i in seq_len(n)) {
    h_team <- team_chr$home[i]
    a_team <- team_chr$away[i]
    h_pre  <- get_rating(h_team)
    a_pre  <- get_rating(a_team)

    home_pre[i] <- h_pre
    away_pre[i] <- a_pre

    # 主場優勢: 把主隊 rating 視為 +hfa_elo 用於預測
    expected_home <- 1 / (1 + 10 ^ ((a_pre - (h_pre + hfa_elo)) / 400))

    h_score <- games$home_score[i]
    a_score <- games$away_score[i]

    # 平手 / 缺值場次 -> 不更新 rating, 直接 carry over
    if (is.na(h_score) || is.na(a_score) || h_score == a_score) {
      home_post[i] <- h_pre
      away_post[i] <- a_pre
      next
    }

    actual_home <- as.integer(h_score > a_score)

    # MoV multiplier (Silver, 2014 NFL Elo 風格, 棒球係數較緩):
    #   mov_mult = log(abs(diff) + 1) * (mov_beta / ((rating_winner_diff)*alpha + mov_beta))
    diff_abs    <- abs(h_score - a_score)
    rating_diff_winner <- if (actual_home == 1) {
      (h_pre + hfa_elo) - a_pre
    } else {
      a_pre - (h_pre + hfa_elo)
    }
    mov_mult <- log(diff_abs + 1) *
      (mov_beta / (rating_diff_winner * mov_alpha + mov_beta))
    # 防呆: mov_mult 可能在極端 rating diff 下變負, clip 到 [0.5, 4]
    mov_mult <- max(0.5, min(4, mov_mult))

    delta <- k_factor * mov_mult * (actual_home - expected_home)

    h_post <- h_pre + delta
    a_post <- a_pre - delta

    home_post[i] <- h_post
    away_post[i] <- a_post

    ratings[[h_team]] <- h_post
    ratings[[a_team]] <- a_post
  }

  games |>
    mutate(
      home_elo_pre  = home_pre,
      away_elo_pre  = away_pre,
      home_elo_post = home_post,
      away_elo_post = away_post
    )
}

# ---------------------------------------------------------------------------
# compute_pythagenpat()
# ---------------------------------------------------------------------------
# 用 Pythagenpat 公式對每支隊伍 (主 / 客視角分開) 計算「過去 N 場」期望勝率。
#   W% = RS^x / (RS^x + RA^x),  x = ((RS + RA) / G) ^ 0.287  (Pythagenpat)
# 為了簡化, 我們先 fix exponent = 1.83 (baseball convention); production 版
# 可進一步動態算 x.
#
# Args:
#   games: tibble with c(game_id, date, home_team, away_team,
#                        home_score, away_score)
#   window:   rolling window (default 30)
#   exponent: Pythagenpat exponent (default 1.83)
# Returns:
#   原 tibble + home_pythag_30g, away_pythag_30g (NA 若隊伍場數不足 5)

compute_pythagenpat <- function(games,
                                window   = PYTHAG_DEFAULTS$window,
                                exponent = PYTHAG_DEFAULTS$exponent) {

  stopifnot(
    all(c("game_id", "date", "home_team", "away_team",
          "home_score", "away_score") %in% names(games))
  )

  # 先把每場拆成 (team, opp, rs, ra, side) long-form, 然後對每隊跑滾動
  long <- games |>
    select(game_id, date, home_team, away_team, home_score, away_score) |>
    pivot_longer(
      cols      = c(home_team, away_team),
      names_to  = "side",
      values_to = "team"
    ) |>
    mutate(
      runs_scored  = if_else(side == "home_team", home_score, away_score),
      runs_allowed = if_else(side == "home_team", away_score, home_score),
      side         = if_else(side == "home_team", "home", "away")
    ) |>
    arrange(team, date, game_id)

  long <- long |>
    group_by(team) |>
    mutate(
      # cumulative pre-game (shift 1, exclude current)
      rs_lag = dplyr::lag(cumsum(runs_scored), default = 0),
      ra_lag = dplyr::lag(cumsum(runs_allowed), default = 0),
      n_lag  = dplyr::lag(row_number() - 1L, default = 0L),
      # rolling window: 取 max(1, n_lag - window + 1) 到 n_lag
      idx    = row_number(),
      win_start = pmax(1L, idx - window),
      # 滾動視窗版本: 用 zoo::rollapplyr 風格, 但只用 dplyr 即可:
      rs_win = rs_lag - dplyr::lag(cumsum(runs_scored),
                                   n = window, default = 0),
      ra_win = ra_lag - dplyr::lag(cumsum(runs_allowed),
                                   n = window, default = 0),
      pythag_pre = dplyr::if_else(
        n_lag < 5,
        NA_real_,
        (rs_win ^ exponent) /
          (rs_win ^ exponent + ra_win ^ exponent)
      )
    ) |>
    ungroup() |>
    select(game_id, side, pythag_pre)

  # 重新 pivot 回 wide, 並 join 回原表
  wide <- long |>
    pivot_wider(
      names_from  = side,
      values_from = pythag_pre,
      names_glue  = "{side}_pythag_30g"
    )

  games |>
    left_join(wide, by = "game_id")
}

# ---------------------------------------------------------------------------
# compute_rest_days()
# ---------------------------------------------------------------------------
# 對每隊算「距上一場比賽的天數」, 上限為 REST_CAP (5+ 一律當 5)。
# 新隊伍 (第一場) 賦 NA, 由下游 recipe 用中位數補。
#
# Args:
#   games: tibble with c(game_id, date, home_team, away_team)
#   cap:   rest_days 上限 (default 5)
# Returns:
#   原 tibble + home_rest_days, away_rest_days

compute_rest_days <- function(games, cap = REST_CAP) {

  stopifnot(
    all(c("game_id", "date", "home_team", "away_team") %in% names(games))
  )

  long <- games |>
    select(game_id, date, home_team, away_team) |>
    pivot_longer(
      cols      = c(home_team, away_team),
      names_to  = "side",
      values_to = "team"
    ) |>
    mutate(side = if_else(side == "home_team", "home", "away")) |>
    arrange(team, date, game_id) |>
    group_by(team) |>
    mutate(
      rest_days = as.integer(date - dplyr::lag(date)),
      rest_days = pmin(rest_days, cap)
    ) |>
    ungroup() |>
    select(game_id, side, rest_days)

  wide <- long |>
    pivot_wider(
      names_from  = side,
      values_from = rest_days,
      names_glue  = "{side}_rest_days"
    )

  games |>
    left_join(wide, by = "game_id")
}

# ---------------------------------------------------------------------------
# Convenience wrapper for downstream scripts.
# ---------------------------------------------------------------------------
# augment_team_strength()
#   一鍵把三個函式串起來: 先 Elo, 後 Pythag, 後 rest_days.
#   常見用法:
#     df_features <- augment_team_strength(raw_games)
augment_team_strength <- function(games) {
  games |>
    compute_elo() |>
    compute_pythagenpat() |>
    compute_rest_days()
}
