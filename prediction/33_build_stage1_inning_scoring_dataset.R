#!/usr/bin/env Rscript

# Build Stage 1 inning-scoring and PA-result target dataset.
# Run from the project root:
# Rscript prediction/33_build_stage1_inning_scoring_dataset.R

source("prediction/08_build_stage1_model_dataset.R")

get_stage1_inning_scoring_target_source_columns <- function() {
  c(
    "runs_scored_on_pa",
    "is_scoring_pa",
    "is_hit",
    "is_extra_base_hit",
    "is_walk",
    "is_home_run",
    "delta_run_expectancy",
    "run_value_label",
    "target_inning_end_score_state",
    "target_inning_end_momentum_state",
    "target_inning_end_event_signal",
    "target_inning_end_combined_state"
  )
}

bucket_remaining_inning_runs <- function(runs_from_current_pa_to_inning_end) {
  ifelse(
    runs_from_current_pa_to_inning_end <= 0,
    "0_runs",
    ifelse(
      runs_from_current_pa_to_inning_end == 1,
      "1_run",
      ifelse(
        runs_from_current_pa_to_inning_end == 2,
        "2_runs",
        "3_plus_runs"
      )
    )
  )
}

label_inning_scoring_state <- function(
  runs_from_current_pa_to_inning_end,
  run_expectancy_before
) {
  ifelse(
    runs_from_current_pa_to_inning_end >= 3,
    "big_inning_realized",
    ifelse(
      runs_from_current_pa_to_inning_end >= 1,
      "scoring_realized",
      ifelse(
        run_expectancy_before >= 1,
        "threat_no_score",
        "quiet_no_score"
      )
    )
  )
}

add_stage1_inning_scoring_targets <- function(stage1_player_context_dataset) {
  required_columns <- c(
    get_stage1_identifier_columns(),
    get_stage1_input_columns(),
    get_stage1_inning_scoring_target_source_columns()
  )
  assert_required_columns(stage1_player_context_dataset, required_columns)

  sorted_dataset <- stage1_player_context_dataset[order(
    stage1_player_context_dataset$game_id,
    stage1_player_context_dataset$inning,
    stage1_player_context_dataset$half_inning,
    stage1_player_context_dataset$batting_team,
    stage1_player_context_dataset$pa_order
  ), ]

  half_inning_key <- paste(
    sorted_dataset$game_id,
    sorted_dataset$inning,
    sorted_dataset$half_inning,
    sorted_dataset$batting_team,
    sep = "||"
  )

  sorted_dataset$runs_from_current_pa_to_inning_end <- NA_real_
  sorted_dataset$runs_after_current_pa_to_inning_end <- NA_real_
  half_inning_groups <- split(seq_len(nrow(sorted_dataset)), half_inning_key)

  for (row_indices in half_inning_groups) {
    group_runs <- sorted_dataset$runs_scored_on_pa[row_indices]
    runs_from_current <- rev(cumsum(rev(group_runs)))
    sorted_dataset$runs_from_current_pa_to_inning_end[row_indices] <- runs_from_current
    sorted_dataset$runs_after_current_pa_to_inning_end[row_indices] <- runs_from_current - group_runs
  }

  sorted_dataset$will_score_from_current_pa <- as.integer(
    sorted_dataset$runs_from_current_pa_to_inning_end > 0
  )
  sorted_dataset$will_score_after_current_pa <- as.integer(
    sorted_dataset$runs_after_current_pa_to_inning_end > 0
  )
  sorted_dataset$current_pa_scores <- as.integer(sorted_dataset$runs_scored_on_pa > 0)
  sorted_dataset$pa_hit <- as.integer(sorted_dataset$is_hit == 1)
  sorted_dataset$pa_extra_base_hit <- as.integer(sorted_dataset$is_extra_base_hit == 1)
  sorted_dataset$pa_home_run <- as.integer(sorted_dataset$is_home_run == 1)
  sorted_dataset$pa_hit_or_walk <- as.integer(
    sorted_dataset$is_hit == 1 | sorted_dataset$is_walk == 1
  )
  sorted_dataset$pa_positive_run_value <- as.integer(
    sorted_dataset$run_value_label %in% c("positive", "strong_positive")
  )
  sorted_dataset$pa_strong_positive_run_value <- as.integer(
    sorted_dataset$run_value_label == "strong_positive"
  )
  sorted_dataset$remaining_inning_run_bucket <- bucket_remaining_inning_runs(
    sorted_dataset$runs_from_current_pa_to_inning_end
  )
  sorted_dataset$stage1_inning_scoring_state <- label_inning_scoring_state(
    sorted_dataset$runs_from_current_pa_to_inning_end,
    sorted_dataset$run_expectancy_before
  )

  sorted_dataset
}

build_stage1_inning_scoring_model_dataset <- function(stage1_player_context_dataset) {
  targeted_dataset <- add_stage1_inning_scoring_targets(stage1_player_context_dataset)

  identifier_columns <- get_stage1_identifier_columns()
  input_columns <- get_stage1_input_columns()
  diagnostic_columns <- c(
    "runs_scored_on_pa",
    "delta_run_expectancy",
    "run_value_label"
  )
  target_columns <- c(
    "runs_from_current_pa_to_inning_end",
    "runs_after_current_pa_to_inning_end",
    "will_score_from_current_pa",
    "will_score_after_current_pa",
    "current_pa_scores",
    "pa_hit",
    "pa_extra_base_hit",
    "pa_home_run",
    "pa_hit_or_walk",
    "pa_positive_run_value",
    "pa_strong_positive_run_value",
    "remaining_inning_run_bucket",
    "stage1_inning_scoring_state",
    "target_inning_end_score_state",
    "target_inning_end_momentum_state",
    "target_inning_end_event_signal",
    "target_inning_end_combined_state"
  )
  selected_columns <- c(
    identifier_columns,
    input_columns,
    diagnostic_columns,
    target_columns
  )

  assert_required_columns(targeted_dataset, selected_columns)

  model_dataset <- targeted_dataset[, selected_columns]
  row.names(model_dataset) <- NULL

  model_dataset
}

create_stage1_inning_scoring_target_summary <- function(model_dataset) {
  binary_target_columns <- c(
    "will_score_from_current_pa",
    "will_score_after_current_pa",
    "current_pa_scores",
    "pa_hit",
    "pa_extra_base_hit",
    "pa_home_run",
    "pa_hit_or_walk",
    "pa_positive_run_value",
    "pa_strong_positive_run_value"
  )

  binary_summary <- data.frame(
    summary_group = "binary_target_rate",
    summary_item = binary_target_columns,
    row_count = nrow(model_dataset),
    value = round(sapply(model_dataset[, binary_target_columns], mean), 6),
    stringsAsFactors = FALSE
  )

  run_summary <- data.frame(
    summary_group = "remaining_runs",
    summary_item = c(
      "mean_runs_from_current_pa",
      "median_runs_from_current_pa",
      "mean_runs_after_current_pa",
      "max_runs_from_current_pa"
    ),
    row_count = nrow(model_dataset),
    value = c(
      round(mean(model_dataset$runs_from_current_pa_to_inning_end), 6),
      round(median(model_dataset$runs_from_current_pa_to_inning_end), 6),
      round(mean(model_dataset$runs_after_current_pa_to_inning_end), 6),
      max(model_dataset$runs_from_current_pa_to_inning_end)
    ),
    stringsAsFactors = FALSE
  )

  scoring_state_counts <- as.data.frame(table(
    model_dataset$stage1_inning_scoring_state
  ), stringsAsFactors = FALSE)
  names(scoring_state_counts) <- c("summary_item", "row_count")
  scoring_state_counts$summary_group <- "stage1_inning_scoring_state"
  scoring_state_counts$value <- round(scoring_state_counts$row_count / nrow(model_dataset), 6)
  scoring_state_counts <- scoring_state_counts[, c(
    "summary_group",
    "summary_item",
    "row_count",
    "value"
  )]

  run_bucket_counts <- as.data.frame(table(
    model_dataset$remaining_inning_run_bucket
  ), stringsAsFactors = FALSE)
  names(run_bucket_counts) <- c("summary_item", "row_count")
  run_bucket_counts$summary_group <- "remaining_inning_run_bucket"
  run_bucket_counts$value <- round(run_bucket_counts$row_count / nrow(model_dataset), 6)
  run_bucket_counts <- run_bucket_counts[, c(
    "summary_group",
    "summary_item",
    "row_count",
    "value"
  )]

  metadata <- data.frame(
    summary_group = "metadata",
    summary_item = c("rows", "columns"),
    row_count = c(nrow(model_dataset), ncol(model_dataset)),
    value = NA_real_,
    stringsAsFactors = FALSE
  )

  rbind(
    metadata,
    binary_summary,
    run_summary,
    scoring_state_counts,
    run_bucket_counts
  )
}

create_stage1_inning_scoring_by_base_out_summary <- function(model_dataset) {
  rate_columns <- c(
    "will_score_from_current_pa",
    "pa_hit",
    "pa_hit_or_walk",
    "pa_positive_run_value",
    "runs_from_current_pa_to_inning_end"
  )

  rate_summary <- aggregate(
    model_dataset[, rate_columns],
    by = list(current_base_out_state = model_dataset$current_base_out_state),
    FUN = mean
  )
  rate_summary[, rate_columns] <- round(rate_summary[, rate_columns], 6)

  row_counts <- as.data.frame(table(
    model_dataset$current_base_out_state
  ), stringsAsFactors = FALSE)
  names(row_counts) <- c("current_base_out_state", "row_count")

  base_out_summary <- merge(
    row_counts,
    rate_summary,
    by = "current_base_out_state",
    all.x = TRUE,
    sort = FALSE
  )

  base_out_summary[order(-base_out_summary$row_count), ]
}

create_stage1_pa_result_target_summary <- function(model_dataset) {
  result_targets <- c(
    "pa_hit",
    "pa_extra_base_hit",
    "pa_home_run",
    "pa_hit_or_walk",
    "pa_positive_run_value",
    "pa_strong_positive_run_value"
  )

  by_batter_type <- aggregate(
    model_dataset[, result_targets],
    by = list(batter_primary_type = model_dataset$batter_primary_type),
    FUN = mean
  )
  by_batter_type[, result_targets] <- round(by_batter_type[, result_targets], 6)
  by_batter_type$row_count <- as.integer(table(model_dataset$batter_primary_type)[
    by_batter_type$batter_primary_type
  ])

  by_batter_type <- by_batter_type[order(-by_batter_type$row_count), c(
    "batter_primary_type",
    "row_count",
    result_targets
  )]

  by_batter_type
}

save_stage1_inning_scoring_outputs <- function(
  model_dataset,
  target_summary,
  base_out_summary,
  pa_result_summary,
  dataset_path = "data/cleaned/stage1_inning_scoring_model_dataset.csv",
  target_summary_path = "outputs/prediction/stage1_inning_scoring_target_summary.csv",
  base_out_summary_path = "outputs/prediction/stage1_inning_scoring_by_base_out_summary.csv",
  pa_result_summary_path = "outputs/prediction/stage1_pa_result_target_summary.csv"
) {
  for (output_dir in unique(c(
    dirname(dataset_path),
    dirname(target_summary_path),
    dirname(base_out_summary_path),
    dirname(pa_result_summary_path)
  ))) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
  }

  write.csv(model_dataset, dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(target_summary, target_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(base_out_summary, base_out_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(pa_result_summary, pa_result_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    dataset_path = dataset_path,
    target_summary_path = target_summary_path,
    base_out_summary_path = base_out_summary_path,
    pa_result_summary_path = pa_result_summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_player_context_dataset <- load_stage1_player_context_dataset()

  model_dataset <- build_stage1_inning_scoring_model_dataset(
    stage1_player_context_dataset
  )
  target_summary <- create_stage1_inning_scoring_target_summary(model_dataset)
  base_out_summary <- create_stage1_inning_scoring_by_base_out_summary(model_dataset)
  pa_result_summary <- create_stage1_pa_result_target_summary(model_dataset)

  output_paths <- save_stage1_inning_scoring_outputs(
    model_dataset,
    target_summary,
    base_out_summary,
    pa_result_summary
  )

  message("Saved Stage 1 inning-scoring model dataset to: ", output_paths$dataset_path)
  message("Saved Stage 1 inning-scoring target summary to: ", output_paths$target_summary_path)
  message("Saved Stage 1 inning-scoring by base-out summary to: ", output_paths$base_out_summary_path)
  message("Saved Stage 1 PA result target summary to: ", output_paths$pa_result_summary_path)
  message("Rows: ", nrow(model_dataset))
  message("Columns: ", ncol(model_dataset))
}
