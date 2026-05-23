#!/usr/bin/env Rscript

# Build Stage 1 v2 combined_state target model dataset.
# Run from the project root:
# Rscript prediction/31_build_stage1_combined_state_model_dataset.R

source("prediction/08_build_stage1_model_dataset.R")

get_stage1_combined_target_columns <- function() {
  c(
    "target_inning_end_score_state",
    "target_inning_end_momentum_state",
    "target_inning_end_event_signal",
    "target_inning_end_combined_state"
  )
}

build_stage1_combined_state_model_dataset <- function(stage1_player_context_dataset) {
  identifier_columns <- get_stage1_identifier_columns()
  input_columns <- get_stage1_input_columns()
  target_columns <- get_stage1_combined_target_columns()
  selected_columns <- c(identifier_columns, input_columns, target_columns)

  assert_required_columns(stage1_player_context_dataset, selected_columns)

  combined_dataset <- stage1_player_context_dataset[, selected_columns]

  names(combined_dataset)[
    names(combined_dataset) == "target_inning_end_score_state"
  ] <- "stage1_target_score_state"
  names(combined_dataset)[
    names(combined_dataset) == "target_inning_end_momentum_state"
  ] <- "stage1_target_momentum_state"
  names(combined_dataset)[
    names(combined_dataset) == "target_inning_end_event_signal"
  ] <- "stage1_target_event_signal"
  names(combined_dataset)[
    names(combined_dataset) == "target_inning_end_combined_state"
  ] <- "stage1_target_combined_state"

  combined_dataset
}

create_combined_state_distribution <- function(combined_dataset) {
  target_counts <- as.data.frame(table(
    combined_dataset$stage1_target_combined_state
  ), stringsAsFactors = FALSE)
  names(target_counts) <- c("stage1_target_combined_state", "row_count")
  target_counts$proportion <- round(target_counts$row_count / nrow(combined_dataset), 4)

  target_counts <- target_counts[order(-target_counts$row_count), ]
  target_counts$cumulative_proportion <- round(cumsum(target_counts$proportion), 4)
  target_counts$rare_state_under_50_rows <- target_counts$row_count < 50
  target_counts$rare_state_under_100_rows <- target_counts$row_count < 100

  target_counts
}

create_combined_state_feasibility_summary <- function(combined_dataset, distribution) {
  row_count <- nrow(combined_dataset)
  class_count <- nrow(distribution)
  classes_under_50 <- sum(distribution$row_count < 50)
  classes_under_100 <- sum(distribution$row_count < 100)
  rows_under_50 <- sum(distribution$row_count[distribution$row_count < 50])
  rows_under_100 <- sum(distribution$row_count[distribution$row_count < 100])

  data.frame(
    summary_group = c(
      "metadata",
      "metadata",
      "class_distribution",
      "class_distribution",
      "rare_state",
      "rare_state",
      "rare_state",
      "rare_state",
      "top_class",
      "top_class",
      "recommendation"
    ),
    summary_item = c(
      "rows",
      "columns",
      "combined_state_class_count",
      "median_rows_per_class",
      "classes_under_50_rows",
      "classes_under_100_rows",
      "rows_in_classes_under_50",
      "rows_in_classes_under_100",
      "largest_class",
      "largest_class_share",
      "feasibility_decision"
    ),
    value = c(
      row_count,
      ncol(combined_dataset),
      class_count,
      median(distribution$row_count),
      classes_under_50,
      classes_under_100,
      rows_under_50,
      rows_under_100,
      distribution$stage1_target_combined_state[1],
      distribution$proportion[1],
      ifelse(
        classes_under_50 / class_count > 0.5,
        "combined_state_is_sparse_consider_grouping_or_component_models",
        "combined_state_direct_model_is_feasible_for_baseline"
      )
    ),
    proportion = c(
      NA,
      NA,
      NA,
      NA,
      round(classes_under_50 / class_count, 4),
      round(classes_under_100 / class_count, 4),
      round(rows_under_50 / row_count, 4),
      round(rows_under_100 / row_count, 4),
      NA,
      distribution$proportion[1],
      NA
    ),
    stringsAsFactors = FALSE
  )
}

save_stage1_combined_state_outputs <- function(
  combined_dataset,
  distribution,
  feasibility_summary,
  dataset_path = "data/cleaned/stage1_combined_state_model_dataset.csv",
  distribution_path = "outputs/prediction/stage1_combined_state_target_distribution.csv",
  feasibility_summary_path = "outputs/prediction/stage1_combined_state_feasibility_summary.csv"
) {
  dataset_dir <- dirname(dataset_path)
  output_dir <- dirname(distribution_path)

  if (!dir.exists(dataset_dir)) {
    dir.create(dataset_dir, recursive = TRUE)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(combined_dataset, dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(distribution, distribution_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(feasibility_summary, feasibility_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    dataset_path = dataset_path,
    distribution_path = distribution_path,
    feasibility_summary_path = feasibility_summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_player_context_dataset <- load_stage1_player_context_dataset()

  combined_dataset <- build_stage1_combined_state_model_dataset(
    stage1_player_context_dataset
  )
  distribution <- create_combined_state_distribution(combined_dataset)
  feasibility_summary <- create_combined_state_feasibility_summary(
    combined_dataset,
    distribution
  )

  output_paths <- save_stage1_combined_state_outputs(
    combined_dataset,
    distribution,
    feasibility_summary
  )

  message("Saved Stage 1 combined-state model dataset to: ", output_paths$dataset_path)
  message("Saved Stage 1 combined-state target distribution to: ", output_paths$distribution_path)
  message("Saved Stage 1 combined-state feasibility summary to: ", output_paths$feasibility_summary_path)
  message("Rows: ", nrow(combined_dataset))
  message("Combined state classes: ", nrow(distribution))
}
