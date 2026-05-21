# ============================================================================
# File   : scripts/00_synthetic_smoke.R
# Purpose: Generate a synthetic CSV mimicking data-collector's full schema so
#          Phase A POC can be smoke-tested without waiting for real CPBL data.
# Author : Sub-Agent 4 (model-builder)
# Date   : 2026-05-13
# ============================================================================

# 本腳本產出 ~400 場 fake regular season games，schema 對齊 charter §10.1
# 與 amendment #1 (team-strength group). 純粹給 03a_phase_a_poc.R 做 wiring
# 驗證；任何模型分數均無實質意義。

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
  library(lubridate)
  library(here)
  library(logger)
})

set.seed(42)

# ---- config ----------------------------------------------------------------
config <- list(
  n_games          = 400L,
  start_date       = as.Date("2023-04-01"),
  end_date         = as.Date("2023-09-30"),
  stadiums         = c("臺北大巨蛋", "樂天桃園", "洲際", "台南",
                       "新莊", "澄清湖", "嘉義"),
  teams            = c("中信兄弟", "統一獅", "樂天桃猿",
                       "富邦悍將", "味全龍", "台鋼雄鷹"),
  dome_stadiums    = c("臺北大巨蛋"),
  hfa_logit        = 0.16,           # 主隊勝率 ≈ 0.54 對應 logit
  elo_init         = 1500,
  elo_sigma        = 60,             # 隊伍能力初始離散度
  pythag_exponent  = 1.83,           # Pythagenpat baseball convention
  out_path         = here::here("data", "processed", "synthetic_games.csv")
)

log_info("Generating {config$n_games} synthetic CPBL games...")

# ---- 1. 抽日期 + 場館 + 對戰 ---------------------------------------------
all_dates <- seq.Date(config$start_date, config$end_date, by = "day")

games <- tibble(
  game_idx = seq_len(config$n_games),
  date     = sort(sample(all_dates, config$n_games, replace = TRUE))
) |>
  mutate(
    stadium   = sample(config$stadiums, n(), replace = TRUE),
    home_team = sample(config$teams,    n(), replace = TRUE),
    away_team = sample(config$teams,    n(), replace = TRUE)
  ) |>
  # 確保主客隊不同
  filter(home_team != away_team) |>
  mutate(
    game_id = sprintf(
      "%s-G%02d",
      format(date, "%Y%m%d"),
      seq_len(n())
    ),
    season  = lubridate::year(date),
    scheduled_start_ts = as.POSIXct(
      paste(date, "18:35:00"),
      tz = "Asia/Taipei"
    )
  )

# ---- 2. 抽天氣 -----------------------------------------------------------
games <- games |>
  mutate(
    is_dome     = stadium %in% config$dome_stadiums,
    temperature = round(rnorm(n(), mean = 28, sd = 3), 1),
    humidity    = pmin(100, pmax(30, round(rnorm(n(), 75, 10)))),
    wind_speed  = pmax(0, round(rnorm(n(), 2.5, 1.2), 2)),
    # 巨蛋場景天氣以「最近室外測站」填入，但建模時應該被 is_dome 旗標排除
    station_id        = paste0("CWA-", sprintf("%03d", sample(1:50, n(), TRUE))),
    station_distance_km = round(runif(n(), 0.5, 8), 2),
    obs_lag_min       = sample(0:55, n(), replace = TRUE)
  )

# ---- 3. 假的隊伍能力 (Elo + Pythag + rest_days) ---------------------------
# 給每支隊伍一個「真實」能力值，藉此產生有訊號的勝負結果，POC 才有東西可驗。
true_skill <- tibble(
  team        = config$teams,
  true_rating = rnorm(length(config$teams),
                      mean = config$elo_init,
                      sd   = config$elo_sigma)
)

games <- games |>
  left_join(true_skill, by = c("home_team" = "team")) |>
  rename(home_true = true_rating) |>
  left_join(true_skill, by = c("away_team" = "team")) |>
  rename(away_true = true_rating)

# ---- 4. 模擬得分 + Y -------------------------------------------------------
# 用 logistic model 模擬主隊勝負；rating diff + HFA + 小量天氣 noise
games <- games |>
  mutate(
    rating_diff    = (home_true - away_true) / 400,
    weather_effect = -0.02 * (wind_speed - 2.5),  # 風強微壓低主隊勝率
    logit_p_home   = config$hfa_logit + rating_diff + weather_effect,
    p_home         = 1 / (1 + exp(-logit_p_home)),
    home_score     = rpois(n(), lambda = 4 + 1.5 * p_home),
    away_score     = rpois(n(), lambda = 4 + 1.5 * (1 - p_home))
  ) |>
  # 處理平手 (charter §3.1: drop ties)
  filter(home_score != away_score) |>
  mutate(
    is_home_win   = factor(
      if_else(home_score > away_score, "1", "0"),
      levels = c("0", "1")
    ),
    is_completed  = TRUE,
    is_postponed  = FALSE
  )

# ---- 5. Team-strength columns (charter amendment #1) ---------------------
# 注意: 這裡用「假」的 pre-game Elo / Pythag / rest_days, 真實版本由
# R/elo_pythag.R 算。POC 用快速近似即可，模型還是有訊號可吃。
games <- games |>
  arrange(date) |>
  mutate(
    # 在真實 rating 上加 N(0, 30) jitter 作為 pre-game Elo 估計
    home_elo_pre   = round(home_true + rnorm(n(), 0, 30), 1),
    away_elo_pre   = round(away_true + rnorm(n(), 0, 30), 1),
    # 30-game rolling Pythagenpat 用隨機 placeholder，
    # 真實版本由 R/elo_pythag.R compute_pythagenpat() 算
    home_pythag_30g = round(runif(n(), 0.35, 0.65), 3),
    away_pythag_30g = round(runif(n(), 0.35, 0.65), 3),
    home_rest_days  = pmin(5L, sample(0:7, n(), replace = TRUE)),
    away_rest_days  = pmin(5L, sample(0:7, n(), replace = TRUE))
  )

# ---- 6. 排版輸出 ---------------------------------------------------------
out <- games |>
  transmute(
    game_id, date, scheduled_start_ts, season,
    stadium, home_team, away_team,
    home_score, away_score, is_home_win,
    is_completed, is_postponed,
    # weather
    temperature, humidity, wind_speed, is_dome,
    station_id, station_distance_km, obs_lag_min,
    # team strength (charter amendment #1)
    home_elo_pre, away_elo_pre,
    home_pythag_30g, away_pythag_30g,
    home_rest_days, away_rest_days,
    source_url = "synthetic://smoke-test"
  )

readr::write_csv(out, config$out_path)
log_info("Wrote {nrow(out)} rows to {config$out_path}")

# 提醒: 此 CSV 在 .gitignore (`data/processed/`) 內, 不會被 commit。
# 只有腳本本身 (scripts/00_synthetic_smoke.R) 進 repo。
invisible(out)
