# ============================================================================
# File   : R/build_recipes.R
# Purpose: tidymodels `recipe()` objects for m1 – m7 progressive ablation.
#          Matches charter amendment #2 (team-strength is m2, not stadium).
# Author : Sub-Agent 4 (model-builder)
# Date   : 2026-05-13
# ============================================================================

# m1 = ~ 1                              (HFA-only intercept)
# m2 = team-strength only
#       elo_diff, pythag_diff, rest_diff (engineered from home/away pair)
# m3 = stadium only                     (factor -> step_dummy)
# m4 = weather only                     (temperature, humidity, wind_speed)
# m5 = team + stadium
# m6 = team + weather
# m7 = team + stadium + weather + (stadium x wind_speed interaction)
#
# 設計筆記:
# - team-strength 我們改成 *差值* (home - away), 因為 logistic regression
#   下單獨用 home_elo / away_elo 會吃到絕對 rating 的水準, 信號比 diff 髒。
# - stadium 在所有含它的 recipe 都是 step_dummy(one_hot = FALSE), 7 levels
#   產生 6 dummies。
# - 因 stadium 與 home_team 在 6 / 7 球場上幾乎完全共線 (charter amendment
#   #4), 我們刻意不把 home_team 進主模型。
# - 巨蛋場 (is_dome == TRUE) 的 weather 變數理論上不該進 m4/m6/m7;
#   POC 階段先讓它進、用 is_dome 旗標標記; Phase B 會在 recipe 中加
#   step_mutate_at() 把 dome 場的 weather 設成全季中位數。

suppressPackageStartupMessages({
  library(dplyr)
  library(recipes)
})

# ---------------------------------------------------------------------------
# helper: derive *_diff cols from home/away pairs (called BEFORE recipe)
# ---------------------------------------------------------------------------
# 我們不把這個塞進 recipe 因為:
#   (a) recipe step_mutate 在 logistic_reg + glm 下效能 ok, 但程式可讀性差;
#   (b) Phase B 改 glmnet/xgboost 時, *_diff 可作為 ranger / xgb 直接使用
#       的純數值特徵, 不需 recipe 重複定義。
add_team_strength_diffs <- function(df) {
  df |>
    mutate(
      elo_diff    = home_elo_pre   - away_elo_pre,
      pythag_diff = home_pythag_30g - away_pythag_30g,
      rest_diff   = home_rest_days  - away_rest_days
    )
}

# ---------------------------------------------------------------------------
# m1 — intercept only (HFA baseline)
# ---------------------------------------------------------------------------
build_recipe_m1 <- function(train_df) {
  # 純截距模型: recipe 只保留 outcome, 移除一切 predictors。
  # 注意: 部分 parsnip / glm 版本對 "完全沒有 predictors" 的 recipe 會抱怨
  # design matrix 為空; 因此 03a_phase_a_poc.R 對 m1 的 sanity-check 邏輯
  # 應該容忍這個 fit 失敗 (我們已用 tryCatch 包住)。
  # 真正的 m1 機率 = 訓練集 P(is_home_win = "1") 即可。
  recipes::recipe(is_home_win ~ ., data = train_df) |>
    recipes::step_rm(recipes::all_predictors())
}

# ---------------------------------------------------------------------------
# m2 — team-strength only
# ---------------------------------------------------------------------------
build_recipe_m2 <- function(train_df) {
  recipes::recipe(
    is_home_win ~ elo_diff + pythag_diff + rest_diff,
    data = train_df
  ) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

# ---------------------------------------------------------------------------
# m3 — stadium only
# ---------------------------------------------------------------------------
build_recipe_m3 <- function(train_df) {
  # 注意: 呼叫端 (03a_phase_a_poc.R) 已將 stadium 轉成 factor;
  # 因此 step_string2factor() 不需要 (且不同版本 recipes 對 already-factor
  # 行為不一致, 移除以避免 surprise). step_dummy() 對 factor 直接吃。
  recipes::recipe(is_home_win ~ stadium, data = train_df) |>
    recipes::step_dummy(stadium, one_hot = FALSE) |>
    recipes::step_zv(recipes::all_predictors())
}

# ---------------------------------------------------------------------------
# m4 — weather only
# ---------------------------------------------------------------------------
build_recipe_m4 <- function(train_df) {
  recipes::recipe(
    is_home_win ~ temperature + humidity + wind_speed,
    data = train_df
  ) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

# ---------------------------------------------------------------------------
# m5 — team + stadium
# ---------------------------------------------------------------------------
build_recipe_m5 <- function(train_df) {
  recipes::recipe(
    is_home_win ~ elo_diff + pythag_diff + rest_diff + stadium,
    data = train_df
  ) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_dummy(stadium, one_hot = FALSE) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

# ---------------------------------------------------------------------------
# m6 — team + weather
# ---------------------------------------------------------------------------
build_recipe_m6 <- function(train_df) {
  recipes::recipe(
    is_home_win ~ elo_diff + pythag_diff + rest_diff +
      temperature + humidity + wind_speed,
    data = train_df
  ) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

# ---------------------------------------------------------------------------
# m7 — full (team + stadium + weather + stadium x wind_speed interaction)
# ---------------------------------------------------------------------------
build_recipe_m7 <- function(train_df) {
  recipes::recipe(
    is_home_win ~ elo_diff + pythag_diff + rest_diff +
      stadium + temperature + humidity + wind_speed,
    data = train_df
  ) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_dummy(stadium, one_hot = FALSE) |>
    # stadium x wind_speed 交互項 (charter amendment #2):
    # 在 step_dummy 之後, stadium 已被 one-hot 為 stadium_xxx 系列欄位,
    # 因此 starts_with("stadium_") 即可抓到。
    recipes::step_interact(
      terms = ~ wind_speed:starts_with("stadium_")
    ) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

# ---------------------------------------------------------------------------
# bundler: return named list of all seven recipes
# ---------------------------------------------------------------------------
build_all_recipes <- function(train_df) {
  list(
    m1 = build_recipe_m1(train_df),
    m2 = build_recipe_m2(train_df),
    m3 = build_recipe_m3(train_df),
    m4 = build_recipe_m4(train_df),
    m5 = build_recipe_m5(train_df),
    m6 = build_recipe_m6(train_df),
    m7 = build_recipe_m7(train_df)
  )
}
