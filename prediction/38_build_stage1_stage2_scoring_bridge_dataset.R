#!/usr/bin/env Rscript

# Build bridge dataset from Stage 1 scoring chance to Stage 2 inning outcome.
# Run from the project root:
# Rscript prediction/38_build_stage1_stage2_scoring_bridge_dataset.R

load_stage1_scoring_prediction_output <- function(
  input_path = "outputs/prediction/stage1_scoring_prediction_output.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 scoring prediction output not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_stage2_inning_outcome_dataset <- function(
  input_path = "data/cleaned/stage2_inning_outcome_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 2 inning outcome dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

assert_required_columns <- function(dataset, required_columns) {
  missing_columns <- setdiff(required_columns, names(dataset))

  if (length(missing_columns) > 0) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }

  invisible(TRUE)
}

prepare_stage2_bridge_columns <- function(stage2_dataset) {
  required_columns <- c(
    "game_id",
    "team",
    "inning",
    "inning_phase",
    "runs_this_inning",
    "cumulative_runs",
    "opponent_cumulative_runs",
    "run_diff_now",
    "score_state",
    "momentum_state",
    "event_signal",
    "combined_state",
    "next_inning_scored",
    "remaining_team_runs_after_current_inning",
    "remaining_opponent_runs_after_current_inning",
    "remaining_run_diff_after_current_inning",
    "team_scores_again_after_current_inning",
    "final_team_runs",
    "final_opponent_runs",
    "final_run_diff",
    "team_win"
  )
  assert_required_columns(stage2_dataset, required_columns)

  bridge_columns <- stage2_dataset[, required_columns]
  names(bridge_columns) <- c(
    "game_id",
    "batting_team",
    "inning",
    "stage2_inning_phase",
    "stage2_runs_this_inning",
    "stage2_cumulative_runs",
    "stage2_opponent_cumulative_runs",
    "stage2_run_diff_now",
    "stage2_score_state",
    "stage2_momentum_state",
    "stage2_event_signal",
    "stage2_combined_state",
    "stage2_next_inning_scored",
    "stage2_remaining_team_runs_after_current_inning",
    "stage2_remaining_opponent_runs_after_current_inning",
    "stage2_remaining_run_diff_after_current_inning",
    "stage2_team_scores_again_after_current_inning",
    "stage2_final_team_runs",
    "stage2_final_opponent_runs",
    "stage2_final_run_diff",
    "stage2_team_win"
  )

  bridge_columns
}

build_stage1_stage2_scoring_bridge_dataset <- function(
  stage1_output,
  stage2_dataset
) {
  stage1_required_columns <- c(
    "game_id",
    "season",
    "date",
    "game_date",
    "validation_split",
    "stadium",
    "inning",
    "half_inning",
    "batting_team",
    "fielding_team",
    "is_home_batting",
    "pa_order",
    "pa_round",
    "batter_name",
    "pitcher_name",
    "current_base_out_state",
    "outs_before",
    "bases_before",
    "score_diff_before",
    "run_expectancy_before",
    "batter_primary_type",
    "pitcher_primary_type",
    "runs_from_current_pa_to_inning_end",
    "will_score_from_current_pa",
    "stage1_scoring_probability",
    "stage1_scoring_chance_state",
    "stage1_scoring_chance_state_zh",
    "target_inning_end_score_state",
    "target_inning_end_momentum_state",
    "target_inning_end_event_signal",
    "target_inning_end_combined_state"
  )
  assert_required_columns(stage1_output, stage1_required_columns)

  stage2_bridge <- prepare_stage2_bridge_columns(stage2_dataset)

  bridge_dataset <- merge(
    stage1_output[, stage1_required_columns],
    stage2_bridge,
    by = c("game_id", "inning", "batting_team"),
    all.x = TRUE,
    sort = FALSE
  )

  bridge_dataset$has_stage2_match <- !is.na(bridge_dataset$stage2_combined_state)

  bridge_dataset[order(
    bridge_dataset$game_id,
    bridge_dataset$inning,
    bridge_dataset$half_inning,
    bridge_dataset$pa_order
  ), ]
}

summarize_bridge_by_scoring_chance <- function(bridge_dataset) {
  required_columns <- c(
    "stage1_scoring_chance_state",
    "stage1_scoring_probability",
    "will_score_from_current_pa",
    "runs_from_current_pa_to_inning_end",
    "stage2_runs_this_inning",
    "stage2_team_win",
    "stage2_remaining_run_diff_after_current_inning"
  )
  assert_required_columns(bridge_dataset, required_columns)

  aggregate(
    cbind(
      row_count = rep(1, nrow(bridge_dataset)),
      mean_stage1_scoring_probability = bridge_dataset$stage1_scoring_probability,
      actual_will_score_rate = bridge_dataset$will_score_from_current_pa,
      mean_runs_from_current_pa = bridge_dataset$runs_from_current_pa_to_inning_end,
      mean_stage2_runs_this_inning = bridge_dataset$stage2_runs_this_inning,
      team_win_rate = as.integer(bridge_dataset$stage2_team_win),
      mean_remaining_run_diff_after_current_inning =
        bridge_dataset$stage2_remaining_run_diff_after_current_inning
    ),
    by = list(scoring_chance_state = bridge_dataset$stage1_scoring_chance_state),
    FUN = function(values) {
      if (all(values == 1)) {
        length(values)
      } else {
        round(mean(values, na.rm = TRUE), 6)
      }
    }
  )
}

summarize_bridge_state_distribution <- function(
  bridge_dataset,
  state_column,
  minimum_rows = 1
) {
  required_columns <- c("stage1_scoring_chance_state", state_column)
  assert_required_columns(bridge_dataset, required_columns)

  distribution <- as.data.frame(table(
    bridge_dataset$stage1_scoring_chance_state,
    bridge_dataset[[state_column]]
  ), stringsAsFactors = FALSE)
  names(distribution) <- c("scoring_chance_state", "state_value", "row_count")

  state_totals <- aggregate(
    distribution$row_count,
    by = list(scoring_chance_state = distribution$scoring_chance_state),
    FUN = sum
  )
  names(state_totals)[2] <- "state_total"

  distribution <- distribution[distribution$row_count >= minimum_rows, ]

  distribution <- merge(
    distribution,
    state_totals,
    by = "scoring_chance_state",
    all.x = TRUE,
    sort = FALSE
  )
  distribution$state_column <- state_column
  distribution$state_share <- round(distribution$row_count / distribution$state_total, 6)

  distribution <- distribution[, c(
    "state_column",
    "scoring_chance_state",
    "state_value",
    "row_count",
    "state_total",
    "state_share"
  )]

  distribution[order(
    distribution$state_column,
    distribution$scoring_chance_state,
    -distribution$state_share,
    distribution$state_value
  ), ]
}

summarize_bridge_by_chance_and_inning_phase <- function(bridge_dataset) {
  required_columns <- c(
    "stage1_scoring_chance_state",
    "stage2_inning_phase",
    "stage1_scoring_probability",
    "will_score_from_current_pa",
    "stage2_team_win"
  )
  assert_required_columns(bridge_dataset, required_columns)

  aggregate(
    cbind(
      row_count = rep(1, nrow(bridge_dataset)),
      mean_stage1_scoring_probability = bridge_dataset$stage1_scoring_probability,
      actual_will_score_rate = bridge_dataset$will_score_from_current_pa,
      team_win_rate = as.integer(bridge_dataset$stage2_team_win)
    ),
    by = list(
      scoring_chance_state = bridge_dataset$stage1_scoring_chance_state,
      inning_phase = bridge_dataset$stage2_inning_phase
    ),
    FUN = function(values) {
      if (all(values == 1)) {
        length(values)
      } else {
        round(mean(values, na.rm = TRUE), 6)
      }
    }
  )
}

create_bridge_summary <- function(bridge_dataset) {
  data.frame(
    summary_group = "metadata",
    summary_item = c(
      "rows",
      "columns",
      "stage2_match_rate",
      "missing_stage2_rows"
    ),
    value = c(
      nrow(bridge_dataset),
      ncol(bridge_dataset),
      round(mean(bridge_dataset$has_stage2_match), 6),
      sum(!bridge_dataset$has_stage2_match)
    ),
    stringsAsFactors = FALSE
  )
}

save_stage1_stage2_scoring_bridge_outputs <- function(
  bridge_dataset,
  bridge_summary,
  scoring_chance_summary,
  combined_state_distribution,
  momentum_state_distribution,
  phase_summary,
  dataset_path = "data/cleaned/stage1_stage2_scoring_bridge_dataset.csv",
  summary_path = "outputs/prediction/stage1_stage2_scoring_bridge_summary.csv",
  scoring_chance_summary_path = "outputs/prediction/stage1_stage2_scoring_bridge_by_chance_summary.csv",
  combined_state_distribution_path = "outputs/prediction/stage1_stage2_scoring_bridge_combined_state_distribution.csv",
  momentum_state_distribution_path = "outputs/prediction/stage1_stage2_scoring_bridge_momentum_state_distribution.csv",
  phase_summary_path = "outputs/prediction/stage1_stage2_scoring_bridge_chance_phase_summary.csv"
) {
  for (output_dir in unique(c(
    dirname(dataset_path),
    dirname(summary_path),
    dirname(scoring_chance_summary_path),
    dirname(combined_state_distribution_path),
    dirname(momentum_state_distribution_path),
    dirname(phase_summary_path)
  ))) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
  }

  write.csv(bridge_dataset, dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(bridge_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(scoring_chance_summary, scoring_chance_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(combined_state_distribution, combined_state_distribution_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(momentum_state_distribution, momentum_state_distribution_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(phase_summary, phase_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    dataset_path = dataset_path,
    summary_path = summary_path,
    scoring_chance_summary_path = scoring_chance_summary_path,
    combined_state_distribution_path = combined_state_distribution_path,
    momentum_state_distribution_path = momentum_state_distribution_path,
    phase_summary_path = phase_summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_output <- load_stage1_scoring_prediction_output()
  stage2_dataset <- load_stage2_inning_outcome_dataset()

  bridge_dataset <- build_stage1_stage2_scoring_bridge_dataset(
    stage1_output,
    stage2_dataset
  )
  bridge_summary <- create_bridge_summary(bridge_dataset)
  scoring_chance_summary <- summarize_bridge_by_scoring_chance(bridge_dataset)
  combined_state_distribution <- summarize_bridge_state_distribution(
    bridge_dataset,
    "stage2_combined_state",
    minimum_rows = 10
  )
  momentum_state_distribution <- summarize_bridge_state_distribution(
    bridge_dataset,
    "stage2_momentum_state",
    minimum_rows = 10
  )
  phase_summary <- summarize_bridge_by_chance_and_inning_phase(bridge_dataset)

  output_paths <- save_stage1_stage2_scoring_bridge_outputs(
    bridge_dataset,
    bridge_summary,
    scoring_chance_summary,
    combined_state_distribution,
    momentum_state_distribution,
    phase_summary
  )

  message("Saved Stage 1/Stage 2 scoring bridge dataset to: ", output_paths$dataset_path)
  message("Saved bridge summary to: ", output_paths$summary_path)
  message("Saved bridge by chance summary to: ", output_paths$scoring_chance_summary_path)
  message("Saved bridge combined-state distribution to: ", output_paths$combined_state_distribution_path)
  message("Saved bridge momentum-state distribution to: ", output_paths$momentum_state_distribution_path)
  message("Saved bridge chance-phase summary to: ", output_paths$phase_summary_path)
  message("Rows: ", nrow(bridge_dataset))
  message("Columns: ", ncol(bridge_dataset))
}
