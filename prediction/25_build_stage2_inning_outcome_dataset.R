#!/usr/bin/env Rscript

# Build Stage 2 inning outcome dataset.
# Run from the project root:
# Rscript prediction/25_build_stage2_inning_outcome_dataset.R

source("prediction/09_build_stage1_frequency_baseline.R")

load_team_inning_state_labeled <- function(
  input_path = "data/cleaned/team_inning_state_labeled.csv"
) {
  if (!file.exists(input_path)) {
    stop("Team inning state labeled file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

prepare_stage2_base_dataset <- function(team_inning_state) {
  required_columns <- c(
    "game_id",
    "season",
    "date",
    "stadium",
    "team",
    "opponent",
    "inning",
    "is_home",
    "home_away_label",
    "runs_this_inning",
    "opponent_runs_this_inning",
    "cumulative_runs",
    "opponent_cumulative_runs",
    "run_diff_now",
    "score_state",
    "momentum_state",
    "event_signal",
    "combined_state",
    "state_label",
    "inning_phase"
  )
  assert_required_columns(team_inning_state, required_columns)

  base_dataset <- team_inning_state
  base_dataset$inning <- as.integer(base_dataset$inning)
  base_dataset$runs_this_inning <- as.integer(base_dataset$runs_this_inning)
  base_dataset$opponent_runs_this_inning <- as.integer(
    base_dataset$opponent_runs_this_inning
  )
  base_dataset$cumulative_runs <- as.integer(base_dataset$cumulative_runs)
  base_dataset$opponent_cumulative_runs <- as.integer(
    base_dataset$opponent_cumulative_runs
  )
  base_dataset$run_diff_now <- as.integer(base_dataset$run_diff_now)

  base_dataset[order(
    base_dataset$game_id,
    base_dataset$team,
    base_dataset$inning
  ), ]
}

add_final_game_outcomes <- function(stage2_dataset) {
  final_scores <- aggregate(
    stage2_dataset[, c("cumulative_runs", "opponent_cumulative_runs", "inning")],
    by = stage2_dataset[, c("game_id", "team")],
    FUN = max
  )
  names(final_scores) <- c(
    "game_id",
    "team",
    "final_team_runs",
    "final_opponent_runs",
    "team_final_inning"
  )
  final_scores$final_run_diff <- (
    final_scores$final_team_runs - final_scores$final_opponent_runs
  )
  final_scores$team_win <- final_scores$final_run_diff > 0
  final_scores$team_loss <- final_scores$final_run_diff < 0
  final_scores$team_tie <- final_scores$final_run_diff == 0

  merge(
    stage2_dataset,
    final_scores,
    by = c("game_id", "team"),
    all.x = TRUE,
    sort = FALSE
  )
}

add_future_scoring_outcomes <- function(stage2_dataset) {
  stage2_dataset$next_inning <- stage2_dataset$inning + 1

  next_inning_lookup <- stage2_dataset[, c(
    "game_id",
    "team",
    "inning",
    "runs_this_inning",
    "opponent_runs_this_inning",
    "score_state",
    "momentum_state"
  )]
  names(next_inning_lookup) <- c(
    "game_id",
    "team",
    "next_inning",
    "next_inning_team_runs",
    "next_inning_opponent_runs",
    "next_inning_score_state",
    "next_inning_momentum_state"
  )

  stage2_dataset <- merge(
    stage2_dataset,
    next_inning_lookup,
    by = c("game_id", "team", "next_inning"),
    all.x = TRUE,
    sort = FALSE
  )

  stage2_dataset$has_next_inning <- !is.na(stage2_dataset$next_inning_team_runs)
  stage2_dataset$next_inning_team_runs[
    is.na(stage2_dataset$next_inning_team_runs)
  ] <- 0
  stage2_dataset$next_inning_opponent_runs[
    is.na(stage2_dataset$next_inning_opponent_runs)
  ] <- 0

  stage2_dataset$next_inning_scored <- (
    stage2_dataset$has_next_inning &
      stage2_dataset$next_inning_team_runs > 0
  )
  stage2_dataset$next_inning_allowed <- (
    stage2_dataset$has_next_inning &
      stage2_dataset$next_inning_opponent_runs > 0
  )
  stage2_dataset$next_inning_run_diff <- (
    stage2_dataset$next_inning_team_runs -
      stage2_dataset$next_inning_opponent_runs
  )

  stage2_dataset$remaining_team_runs_after_current_inning <- (
    stage2_dataset$final_team_runs - stage2_dataset$cumulative_runs
  )
  stage2_dataset$remaining_opponent_runs_after_current_inning <- (
    stage2_dataset$final_opponent_runs - stage2_dataset$opponent_cumulative_runs
  )
  stage2_dataset$remaining_run_diff_after_current_inning <- (
    stage2_dataset$remaining_team_runs_after_current_inning -
      stage2_dataset$remaining_opponent_runs_after_current_inning
  )
  stage2_dataset$team_scores_again_after_current_inning <- (
    stage2_dataset$remaining_team_runs_after_current_inning > 0
  )
  stage2_dataset$opponent_scores_again_after_current_inning <- (
    stage2_dataset$remaining_opponent_runs_after_current_inning > 0
  )

  stage2_dataset
}

select_stage2_output_columns <- function(stage2_dataset) {
  output_columns <- c(
    "game_id",
    "season",
    "date",
    "stadium",
    "team",
    "opponent",
    "inning",
    "is_home",
    "home_away_label",
    "inning_phase",
    "runs_this_inning",
    "opponent_runs_this_inning",
    "cumulative_runs",
    "opponent_cumulative_runs",
    "run_diff_now",
    "score_state",
    "momentum_state",
    "event_signal",
    "combined_state",
    "state_label",
    "next_inning",
    "has_next_inning",
    "next_inning_team_runs",
    "next_inning_opponent_runs",
    "next_inning_run_diff",
    "next_inning_scored",
    "next_inning_allowed",
    "next_inning_score_state",
    "next_inning_momentum_state",
    "remaining_team_runs_after_current_inning",
    "remaining_opponent_runs_after_current_inning",
    "remaining_run_diff_after_current_inning",
    "team_scores_again_after_current_inning",
    "opponent_scores_again_after_current_inning",
    "final_team_runs",
    "final_opponent_runs",
    "final_run_diff",
    "team_win",
    "team_loss",
    "team_tie"
  )

  stage2_dataset[, output_columns]
}

build_stage2_inning_outcome_dataset <- function(team_inning_state) {
  stage2_dataset <- prepare_stage2_base_dataset(team_inning_state)
  stage2_dataset <- add_final_game_outcomes(stage2_dataset)
  stage2_dataset <- add_future_scoring_outcomes(stage2_dataset)
  stage2_dataset <- select_stage2_output_columns(stage2_dataset)

  stage2_dataset[order(
    stage2_dataset$game_id,
    stage2_dataset$team,
    stage2_dataset$inning
  ), ]
}

build_stage2_outcome_summary <- function(stage2_dataset) {
  rows_summary <- data.frame(
    summary_group = "rows",
    summary_item = c("team_inning_rows", "rows_with_next_inning"),
    count = c(
      nrow(stage2_dataset),
      sum(stage2_dataset$has_next_inning)
    ),
    proportion = c(
      1,
      round(mean(stage2_dataset$has_next_inning), 4)
    ),
    stringsAsFactors = FALSE
  )

  outcome_summary <- data.frame(
    summary_group = "outcomes",
    summary_item = c(
      "next_inning_scored_rate",
      "next_inning_allowed_rate",
      "team_scores_again_rate",
      "opponent_scores_again_rate",
      "team_win_rate"
    ),
    count = c(
      sum(stage2_dataset$next_inning_scored, na.rm = TRUE),
      sum(stage2_dataset$next_inning_allowed, na.rm = TRUE),
      sum(stage2_dataset$team_scores_again_after_current_inning, na.rm = TRUE),
      sum(stage2_dataset$opponent_scores_again_after_current_inning, na.rm = TRUE),
      sum(stage2_dataset$team_win, na.rm = TRUE)
    ),
    proportion = c(
      round(mean(stage2_dataset$next_inning_scored, na.rm = TRUE), 4),
      round(mean(stage2_dataset$next_inning_allowed, na.rm = TRUE), 4),
      round(mean(stage2_dataset$team_scores_again_after_current_inning, na.rm = TRUE), 4),
      round(mean(stage2_dataset$opponent_scores_again_after_current_inning, na.rm = TRUE), 4),
      round(mean(stage2_dataset$team_win, na.rm = TRUE), 4)
    ),
    stringsAsFactors = FALSE
  )

  rbind(rows_summary, outcome_summary)
}

build_stage2_state_outcome_summary <- function(stage2_dataset) {
  aggregate_columns <- c(
    "next_inning_scored",
    "next_inning_allowed",
    "team_scores_again_after_current_inning",
    "opponent_scores_again_after_current_inning",
    "team_win",
    "remaining_team_runs_after_current_inning",
    "remaining_run_diff_after_current_inning"
  )

  state_summary <- aggregate(
    stage2_dataset[, aggregate_columns],
    by = list(momentum_state = stage2_dataset$momentum_state),
    FUN = mean
  )

  state_counts <- as.data.frame(table(
    stage2_dataset$momentum_state
  ), stringsAsFactors = FALSE)
  names(state_counts) <- c("momentum_state", "row_count")

  state_summary <- merge(
    state_summary,
    state_counts,
    by = "momentum_state",
    all.x = TRUE,
    sort = FALSE
  )

  numeric_columns <- setdiff(names(state_summary), c("momentum_state", "row_count"))
  for (column_name in numeric_columns) {
    state_summary[[column_name]] <- round(state_summary[[column_name]], 4)
  }

  state_summary <- state_summary[, c(
    "momentum_state",
    "row_count",
    aggregate_columns
  )]
  state_summary[order(-state_summary$row_count), ]
}

save_stage2_outcome_outputs <- function(
  stage2_dataset,
  outcome_summary,
  state_outcome_summary,
  dataset_path = "data/cleaned/stage2_inning_outcome_dataset.csv",
  outcome_summary_path = "outputs/prediction/stage2_inning_outcome_summary.csv",
  state_outcome_summary_path = "outputs/prediction/stage2_state_outcome_summary.csv"
) {
  dataset_dir <- dirname(dataset_path)
  output_dir <- dirname(outcome_summary_path)

  if (!dir.exists(dataset_dir)) {
    dir.create(dataset_dir, recursive = TRUE)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(stage2_dataset, dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(outcome_summary, outcome_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(state_outcome_summary, state_outcome_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    dataset_path = dataset_path,
    outcome_summary_path = outcome_summary_path,
    state_outcome_summary_path = state_outcome_summary_path
  )
}

if (sys.nframe() == 0) {
  team_inning_state <- load_team_inning_state_labeled()
  stage2_dataset <- build_stage2_inning_outcome_dataset(team_inning_state)
  outcome_summary <- build_stage2_outcome_summary(stage2_dataset)
  state_outcome_summary <- build_stage2_state_outcome_summary(stage2_dataset)

  output_paths <- save_stage2_outcome_outputs(
    stage2_dataset,
    outcome_summary,
    state_outcome_summary
  )

  message("Saved Stage 2 inning outcome dataset to: ", output_paths$dataset_path)
  message("Saved Stage 2 outcome summary to: ", output_paths$outcome_summary_path)
  message("Saved Stage 2 state outcome summary to: ", output_paths$state_outcome_summary_path)
}
