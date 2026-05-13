# ============================================================================
# File   : scripts/03a_phase_a_poc.R
# Purpose: Phase A POC pipeline — fit m1-m7 on synthetic CPBL data, prove the
#          wiring works end-to-end before Phase B touches real season data.
# Author : Sub-Agent 4 (model-builder)
# Date   : 2026-05-13
# ============================================================================

# 本腳本是 model-builder Phase A 的 entry point. 它 *只* 做 wiring 驗證:
#   1. 讀 synthetic_games.csv (由 scripts/00_synthetic_smoke.R 產出)
#   2. 用 R/elo_pythag.R 重算 team-strength 欄位 (取代 smoke 的 jitter)
#   3. 用 R/build_recipes.R 拿到 m1-m7 七張 recipes
#   4. time-aware split (charter §6.1 + CLAUDE.md §6 rule 5)
#   5. fit m1-m7 (parsnip + glm), m7 多 fit 一個 glmnet 變體
#   6. yardstick 收集 roc_auc / pr_auc / brier_class / accuracy / f1
#   7. 寫出 models/poc/poc_results.rds + Results/figures/poc_model_comparison.csv
#
# 嚴禁在這個 script 裡:
#   - 用 initial_split() (random) — 必須用 initial_time_split()
#   - 假裝 synthetic 分數有商業意義 — 只是 smoke test
#   - 跑 grid search — 留給 Phase B

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)        # pivot_wider in §7 aggregation
  library(purrr)        # map_dfr in §7 aggregation
  library(tibble)
  library(readr)
  library(here)
  library(logger)
  library(jsonlite)     # toJSON for sanity log payload
  library(rsample)
  library(recipes)
  library(parsnip)
  library(workflows)
  library(yardstick)
  library(tune)         # for last_fit-style helpers (not strictly required)
})

set.seed(42)

# ---- config ----------------------------------------------------------------
config <- list(
  in_path        = here::here("data", "processed", "synthetic_games.csv"),
  recipes_path   = here::here("R", "build_recipes.R"),
  elo_path       = here::here("R", "elo_pythag.R"),
  out_rds        = here::here("models", "poc", "poc_results.rds"),
  out_csv        = here::here("Results", "figures",
                              "poc_model_comparison.csv"),
  train_prop     = 0.8,
  positive_class = "1",
  glmnet_penalty = 0.01,
  glmnet_mixture = 0.5     # elastic-net, mid-way between L1 / L2
)

logger::log_threshold(logger::INFO)
log_info("=== Phase A POC start ===")
log_info("Working dir: {here::here()}")

# ---- 0. source helpers ----------------------------------------------------
source(config$elo_path,     local = FALSE)
source(config$recipes_path, local = FALSE)

# ---- 1. load synthetic data ------------------------------------------------
if (!file.exists(config$in_path)) {
  stop(
    "synthetic_games.csv not found at ", config$in_path,
    "\nRun: source(here::here('scripts/00_synthetic_smoke.R'))",
    " first."
  )
}

raw <- readr::read_csv(
  config$in_path,
  show_col_types = FALSE
) |>
  dplyr::mutate(
    date         = as.Date(date),
    stadium      = as.factor(stadium),
    home_team    = as.factor(home_team),
    away_team    = as.factor(away_team),
    is_home_win  = factor(as.character(is_home_win),
                          levels = c("0", "1"))
  )

log_info("Loaded {nrow(raw)} rows; class balance:")
print(table(raw$is_home_win, useNA = "ifany"))

# ---- 2. recompute team-strength via R/elo_pythag.R -------------------------
# 注意: synthetic CSV 已含 *_pre 欄位 (smoke jitter 版本); 為了證明 elo_pythag.R
# 真的能跑, 我們先把這些欄位捨棄, 再用真正的函式重算一次。
core <- raw |>
  dplyr::select(-dplyr::any_of(c(
    "home_elo_pre", "away_elo_pre",
    "home_pythag_30g", "away_pythag_30g",
    "home_rest_days",  "away_rest_days"
  )))

enriched <- core |>
  augment_team_strength()      # 來自 R/elo_pythag.R

# 加 team-strength diff columns (給 m2 / m5 / m6 / m7 用)
enriched <- enriched |>
  add_team_strength_diffs()    # 來自 R/build_recipes.R

# 模型 frame (POC 只保留必要欄位 + outcome)
model_frame <- enriched |>
  dplyr::filter(!is.na(is_home_win)) |>
  dplyr::select(
    is_home_win, date,
    elo_diff, pythag_diff, rest_diff,
    stadium,
    temperature, humidity, wind_speed,
    is_dome
  ) |>
  dplyr::arrange(date)

log_info("Model frame: {nrow(model_frame)} rows x {ncol(model_frame)} cols")

# ---- 3. time-aware split (CLAUDE.md §6 rule 5) -----------------------------
split   <- rsample::initial_time_split(model_frame, prop = config$train_prop)
train_df <- rsample::training(split)
test_df  <- rsample::testing(split)
log_info("Train: {nrow(train_df)} rows | Test: {nrow(test_df)} rows")

# ---- 4. recipes ------------------------------------------------------------
all_recipes <- build_all_recipes(train_df)
stopifnot(identical(names(all_recipes),
                    c("m1", "m2", "m3", "m4", "m5", "m6", "m7")))

# ---- 5. model specs --------------------------------------------------------
spec_glm <- parsnip::logistic_reg() |>
  parsnip::set_engine("glm") |>
  parsnip::set_mode("classification")

spec_glmnet <- parsnip::logistic_reg(
  penalty = config$glmnet_penalty,
  mixture = config$glmnet_mixture
) |>
  parsnip::set_engine("glmnet") |>
  parsnip::set_mode("classification")

# ---- 6. fit + evaluate -----------------------------------------------------
# 共用評分函式: 給定 fitted workflow + test_df, 回傳一列 metrics tibble
score_workflow <- function(model_id, engine_id, fit_obj, test_df) {
  # 預測機率 + class
  preds <- dplyr::bind_cols(
    test_df |> dplyr::select(is_home_win),
    predict(fit_obj, new_data = test_df, type = "prob"),
    predict(fit_obj, new_data = test_df, type = "class")
  )

  # 確保 positive class
  metric_multi <- yardstick::metric_set(
    yardstick::roc_auc,
    yardstick::pr_auc,
    yardstick::brier_class,
    yardstick::accuracy,
    yardstick::f_meas
  )

  scored <- metric_multi(
    preds,
    truth     = is_home_win,
    estimate  = .pred_class,
    .pred_1,
    event_level = "second"   # positive = "1" (second factor level)
  )

  scored |>
    dplyr::mutate(model = model_id, engine = engine_id) |>
    dplyr::select(model, engine, .metric, .estimate)
}

results <- list()

for (m_id in names(all_recipes)) {
  log_info("Fitting {m_id} (glm)...")
  wf <- workflows::workflow() |>
    workflows::add_recipe(all_recipes[[m_id]]) |>
    workflows::add_model(spec_glm)

  fit_obj <- tryCatch(
    parsnip::fit(wf, data = train_df),
    error = function(e) {
      log_warn("{m_id} glm fit failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (!is.null(fit_obj)) {
    results[[paste0(m_id, "_glm")]] <- list(
      fit = fit_obj,
      scores = score_workflow(m_id, "glm", fit_obj, test_df)
    )
  }
}

# 額外: m7 也用 glmnet 跑一份 (charter §6 table)
log_info("Fitting m7 (glmnet, elastic-net)...")
wf7_net <- workflows::workflow() |>
  workflows::add_recipe(all_recipes[["m7"]]) |>
  workflows::add_model(spec_glmnet)

fit_m7_net <- tryCatch(
  parsnip::fit(wf7_net, data = train_df),
  error = function(e) {
    log_warn("m7 glmnet fit failed: {conditionMessage(e)}")
    NULL
  }
)
if (!is.null(fit_m7_net)) {
  results[["m7_glmnet"]] <- list(
    fit = fit_m7_net,
    scores = score_workflow("m7", "glmnet", fit_m7_net, test_df)
  )
}

# ---- 7. aggregate + persist ------------------------------------------------
scores_long <- purrr::map_dfr(results, "scores")
log_info("=== POC metric table ===")
print(scores_long)

# wide form for human eyeballing
scores_wide <- scores_long |>
  tidyr::pivot_wider(
    names_from  = .metric,
    values_from = .estimate
  ) |>
  dplyr::arrange(dplyr::desc(roc_auc))

log_info("=== POC ranking (by ROC-AUC, descending) ===")
print(scores_wide)

# ---- 8. POC sanity checks (advisory only; synthetic data) -----------------
# 注意: synthetic data 不能驗證模型「對 / 不對」, 只能驗證 pipeline「跑 / 不跑」。
# 但仍做幾個 wiring sanity:
sanity <- list(
  all_seven_glms_fit = sum(grepl("_glm$", names(results))) == 7,
  no_nan_roc_auc     = !any(is.na(scores_wide$roc_auc)),
  m7_better_than_m1  = {
    a <- scores_wide$roc_auc[scores_wide$model == "m7" &
                              scores_wide$engine == "glm"]
    b <- scores_wide$roc_auc[scores_wide$model == "m1" &
                              scores_wide$engine == "glm"]
    if (length(a) == 1 && length(b) == 1) a >= b - 0.05 else FALSE
  }
)
log_info("Sanity: {jsonlite::toJSON(sanity, auto_unbox = TRUE)}")

# ---- 9. write artefacts ----------------------------------------------------
dir.create(dirname(config$out_rds), showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(config$out_csv), showWarnings = FALSE, recursive = TRUE)

saveRDS(
  list(
    results    = results,
    scores     = scores_long,
    scores_wide = scores_wide,
    sanity     = sanity,
    config     = config,
    trained_at = Sys.time()
  ),
  file = config$out_rds
)
log_info("Wrote {config$out_rds}")

readr::write_csv(scores_wide, config$out_csv)
log_info("Wrote {config$out_csv}")

log_info("=== Phase A POC done ===")

# session info gets dumped by scripts/00_session_info.R as a separate step.
invisible(scores_wide)
