#!/usr/bin/env Rscript

# Build Stage 1 result-state target dataset.
# Run from the project root:
# Rscript prediction/44_build_stage1_result_state_dataset.R

source("prediction/08_build_stage1_model_dataset.R")

load_stage1_inning_scoring_model_dataset <- function(
  input_path = "data/cleaned/stage1_inning_scoring_model_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 inning scoring model dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

label_stage1_result_state <- function(
  runs_from_current_pa_to_inning_end,
  run_expectancy_before,
  bases_before,
  outs_before
) {
  has_clear_threat <- run_expectancy_before >= 0.75 |
    (bases_before >= 2 & outs_before <= 1) |
    (bases_before >= 1 & outs_before == 0)

  ifelse(
    runs_from_current_pa_to_inning_end >= 3,
    "big_inning",
    ifelse(
      runs_from_current_pa_to_inning_end == 2,
      "score_multiple",
      ifelse(
        runs_from_current_pa_to_inning_end == 1,
        "score_once",
        ifelse(has_clear_threat, "wasted_chance", "no_score_stable")
      )
    )
  )
}

label_stage1_result_state_zh <- function(result_state) {
  labels <- c(
    big_inning = "大局形成",
    score_multiple = "多分進帳",
    score_once = "單分進帳",
    wasted_chance = "攻勢浪費",
    no_score_stable = "安靜無得分"
  )
  unname(ifelse(result_state %in% names(labels), labels[result_state], result_state))
}

build_stage1_result_state_dataset <- function(stage1_scoring_dataset) {
  required_columns <- c(
    get_stage1_identifier_columns(),
    get_stage1_input_columns(),
    "runs_from_current_pa_to_inning_end",
    "run_expectancy_before",
    "bases_before",
    "outs_before",
    "will_score_from_current_pa",
    "remaining_inning_run_bucket",
    "target_inning_end_score_state",
    "target_inning_end_momentum_state",
    "target_inning_end_event_signal",
    "target_inning_end_combined_state"
  )
  assert_required_columns(stage1_scoring_dataset, required_columns)

  result_dataset <- stage1_scoring_dataset[, required_columns]
  result_dataset$stage1_result_state <- label_stage1_result_state(
    result_dataset$runs_from_current_pa_to_inning_end,
    result_dataset$run_expectancy_before,
    result_dataset$bases_before,
    result_dataset$outs_before
  )
  result_dataset$stage1_result_state_zh <- label_stage1_result_state_zh(
    result_dataset$stage1_result_state
  )

  result_dataset
}

create_stage1_result_state_distribution <- function(result_dataset) {
  distribution <- as.data.frame(table(
    result_dataset$stage1_result_state,
    result_dataset$stage1_result_state_zh
  ), stringsAsFactors = FALSE)
  names(distribution) <- c("stage1_result_state", "stage1_result_state_zh", "row_count")
  distribution <- distribution[distribution$row_count > 0, ]
  distribution$proportion <- round(distribution$row_count / nrow(result_dataset), 6)
  distribution <- distribution[order(-distribution$row_count), ]
  row.names(distribution) <- NULL

  distribution
}

summarize_result_state_by_player_type <- function(result_dataset) {
  group_columns <- c("batter_primary_type", "pitcher_primary_type")

  summaries <- lapply(group_columns, function(group_column) {
    state_counts <- as.data.frame(table(
      result_dataset[[group_column]],
      result_dataset$stage1_result_state
    ), stringsAsFactors = FALSE)
    names(state_counts) <- c("group_value", "stage1_result_state", "row_count")

    group_totals <- aggregate(
      state_counts$row_count,
      by = list(group_value = state_counts$group_value),
      FUN = sum
    )
    names(group_totals)[2] <- "group_total"

    summary <- merge(state_counts, group_totals, by = "group_value", all.x = TRUE)
    summary$state_share <- round(summary$row_count / summary$group_total, 6)
    summary$group_column <- group_column
    summary <- summary[, c(
      "group_column",
      "group_value",
      "stage1_result_state",
      "row_count",
      "group_total",
      "state_share"
    )]
    summary[summary$row_count > 0, ]
  })

  do.call(rbind, summaries)
}

summarize_result_state_by_base_out <- function(result_dataset) {
  state_counts <- as.data.frame(table(
    result_dataset$current_base_out_state,
    result_dataset$stage1_result_state
  ), stringsAsFactors = FALSE)
  names(state_counts) <- c("current_base_out_state", "stage1_result_state", "row_count")

  base_out_totals <- aggregate(
    state_counts$row_count,
    by = list(current_base_out_state = state_counts$current_base_out_state),
    FUN = sum
  )
  names(base_out_totals)[2] <- "base_out_total"

  summary <- merge(state_counts, base_out_totals, by = "current_base_out_state", all.x = TRUE)
  summary$state_share <- round(summary$row_count / summary$base_out_total, 6)
  summary <- summary[summary$row_count > 0, ]
  summary[order(summary$current_base_out_state, -summary$state_share), ]
}

create_stage1_result_state_feasibility_summary <- function(result_dataset, distribution) {
  data.frame(
    summary_group = c(
      "metadata",
      "metadata",
      "target_distribution",
      "target_distribution",
      "recommendation"
    ),
    summary_item = c(
      "rows",
      "columns",
      "result_state_class_count",
      "largest_class_share",
      "next_step"
    ),
    value = c(
      nrow(result_dataset),
      ncol(result_dataset),
      nrow(distribution),
      distribution$proportion[1],
      "train_stage1_result_state_baseline"
    ),
    stringsAsFactors = FALSE
  )
}

save_stage1_result_state_outputs <- function(
  result_dataset,
  distribution,
  player_type_summary,
  base_out_summary,
  feasibility_summary,
  dataset_path = "data/cleaned/stage1_result_state_model_dataset.csv",
  distribution_path = "outputs/prediction/stage1_result_state_distribution.csv",
  player_type_summary_path = "outputs/prediction/stage1_result_state_by_player_type_summary.csv",
  base_out_summary_path = "outputs/prediction/stage1_result_state_by_base_out_summary.csv",
  feasibility_summary_path = "outputs/prediction/stage1_result_state_feasibility_summary.csv"
) {
  for (output_dir in unique(c(
    dirname(dataset_path),
    dirname(distribution_path),
    dirname(player_type_summary_path),
    dirname(base_out_summary_path),
    dirname(feasibility_summary_path)
  ))) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
  }

  write.csv(result_dataset, dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(distribution, distribution_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(player_type_summary, player_type_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(base_out_summary, base_out_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(feasibility_summary, feasibility_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    dataset_path = dataset_path,
    distribution_path = distribution_path,
    player_type_summary_path = player_type_summary_path,
    base_out_summary_path = base_out_summary_path,
    feasibility_summary_path = feasibility_summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_scoring_dataset <- load_stage1_inning_scoring_model_dataset()
  result_dataset <- build_stage1_result_state_dataset(stage1_scoring_dataset)
  distribution <- create_stage1_result_state_distribution(result_dataset)
  player_type_summary <- summarize_result_state_by_player_type(result_dataset)
  base_out_summary <- summarize_result_state_by_base_out(result_dataset)
  feasibility_summary <- create_stage1_result_state_feasibility_summary(
    result_dataset,
    distribution
  )

  output_paths <- save_stage1_result_state_outputs(
    result_dataset,
    distribution,
    player_type_summary,
    base_out_summary,
    feasibility_summary
  )

  message("Saved Stage 1 result-state dataset to: ", output_paths$dataset_path)
  message("Saved result-state distribution to: ", output_paths$distribution_path)
  message("Saved result-state player-type summary to: ", output_paths$player_type_summary_path)
  message("Saved result-state base-out summary to: ", output_paths$base_out_summary_path)
  message("Saved result-state feasibility summary to: ", output_paths$feasibility_summary_path)
  message("Rows: ", nrow(result_dataset))
  message("Columns: ", ncol(result_dataset))
}
