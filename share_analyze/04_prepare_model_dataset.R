#!/usr/bin/env Rscript

# Prepare a descriptive modeling dataset for CPBL 2024 win/loss analysis.
# This dataset uses post-game performance features, so it is for explanation,
# not for true pregame prediction.

load_team_game_for_modeling <- function(
  path = "data/cleaned/team_game_features.csv"
) {
  if (!file.exists(path)) {
    stop("Team-game feature file not found: ", path)
  }

  read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
}

select_model_features <- function(team_game_df, dataset_type = "descriptive") {
  if (dataset_type != "descriptive") {
    stop("Only dataset_type = 'descriptive' is currently supported.")
  }

  feature_columns <- c(
    "win",
    "is_home",
    "runs_scored",
    "runs_allowed",
    "run_diff",
    "early_runs",
    "middle_runs",
    "late_runs",
    "scored_first",
    "led_after_3",
    "led_after_6",
    "AB",
    "H",
    "BB",
    "SO",
    "double",
    "triple",
    "HR",
    "extra_base_hits",
    "power_score",
    "run_per_hit",
    "offense_pressure_score",
    "innings_pitched",
    "hits_allowed",
    "bb_allowed",
    "hr_allowed",
    "so_pitched",
    "whip_like",
    "strikeout_walk_ratio",
    "run_prevention_score"
  )

  missing_columns <- setdiff(feature_columns, names(team_game_df))
  if (length(missing_columns) > 0) {
    stop("Missing model feature columns: ", paste(missing_columns, collapse = ", "))
  }

  team_game_df[, feature_columns]
}

encode_model_dataset <- function(model_df) {
  model_df$win <- factor(
    ifelse(model_df$win, "win", "loss"),
    levels = c("loss", "win")
  )

  model_df$is_home <- factor(
    ifelse(model_df$is_home, "home", "away"),
    levels = c("away", "home")
  )

  logical_columns <- names(model_df)[sapply(model_df, is.logical)]
  for (column in logical_columns) {
    model_df[[column]] <- factor(
      ifelse(model_df[[column]], "yes", "no"),
      levels = c("no", "yes")
    )
  }

  model_df
}

save_model_dataset <- function(
  model_df,
  output_path = "data/cleaned/model_dataset_win.csv"
) {
  output_dir <- dirname(output_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(model_df, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  output_path
}

if (sys.nframe() == 0) {
  team_game <- load_team_game_for_modeling()
  model_df <- select_model_features(team_game, dataset_type = "descriptive")
  model_df <- encode_model_dataset(model_df)
  output_path <- save_model_dataset(model_df)

  message("Saved descriptive model dataset to: ", output_path)
  message("Rows: ", nrow(model_df))
  message("Columns: ", ncol(model_df))
}
