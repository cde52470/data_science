#!/usr/bin/env Rscript

# Analyze Stage 1 v1 prediction patterns.
# Run from the project root:
# Rscript prediction/21_analyze_stage1_v1_prediction_patterns.R

source("prediction/09_build_stage1_frequency_baseline.R")

load_stage1_v1_prediction_output <- function(
  input_path = "outputs/prediction/stage1_v1_prediction_output.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 v1 prediction output not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

prepare_pattern_dataset <- function(prediction_output) {
  required_columns <- c(
    "validation_split",
    "stage1_target_momentum_state",
    "stage1_v1_predicted_state",
    "stage1_v1_predicted_probability",
    "is_correct_prediction",
    "before_score_state",
    "before_momentum_state",
    "before_event_signal",
    "current_base_out_state",
    "outs_before",
    "bases_before",
    "score_diff_before",
    "run_expectancy_before",
    "batter_primary_type",
    "pitcher_primary_type"
  )
  assert_required_columns(prediction_output, required_columns)

  prediction_output$is_correct_prediction <- as.logical(
    prediction_output$is_correct_prediction
  )
  prediction_output$stage1_v1_predicted_probability <- as.numeric(
    prediction_output$stage1_v1_predicted_probability
  )
  prediction_output$outs_before <- as.numeric(prediction_output$outs_before)
  prediction_output$bases_before <- as.numeric(prediction_output$bases_before)
  prediction_output$score_diff_before <- as.numeric(prediction_output$score_diff_before)
  prediction_output$run_expectancy_before <- as.numeric(
    prediction_output$run_expectancy_before
  )
  prediction_output$batter_pitcher_type_context <- paste(
    prediction_output$batter_primary_type,
    prediction_output$pitcher_primary_type,
    sep = "_vs_"
  )
  prediction_output$base_out_player_context <- paste(
    prediction_output$current_base_out_state,
    prediction_output$batter_primary_type,
    prediction_output$pitcher_primary_type,
    sep = "__"
  )

  prediction_output
}

summarize_context_patterns <- function(
  prediction_output,
  context_columns,
  context_name,
  split_name = "test",
  minimum_context_rows = 20
) {
  split_data <- prediction_output[prediction_output$validation_split == split_name, ]
  group_columns <- c(context_columns, "stage1_v1_predicted_state")

  group_counts <- aggregate(
    rep(1, nrow(split_data)),
    by = split_data[, group_columns, drop = FALSE],
    FUN = sum
  )
  names(group_counts)[ncol(group_counts)] <- "prediction_count"

  group_metrics <- aggregate(
    split_data[, c("stage1_v1_predicted_probability", "is_correct_prediction")],
    by = split_data[, group_columns, drop = FALSE],
    FUN = mean
  )
  names(group_metrics)[
    names(group_metrics) == "stage1_v1_predicted_probability"
  ] <- "avg_predicted_probability"
  names(group_metrics)[
    names(group_metrics) == "is_correct_prediction"
  ] <- "accuracy"

  context_totals <- aggregate(
    rep(1, nrow(split_data)),
    by = split_data[, context_columns, drop = FALSE],
    FUN = sum
  )
  names(context_totals)[ncol(context_totals)] <- "context_total"

  context_summary <- merge(
    group_counts,
    group_metrics,
    by = group_columns,
    all.x = TRUE,
    sort = FALSE
  )
  context_summary <- merge(
    context_summary,
    context_totals,
    by = context_columns,
    all.x = TRUE,
    sort = FALSE
  )

  context_summary <- context_summary[
    context_summary$context_total >= minimum_context_rows,
  ]
  context_summary$context_name <- context_name
  context_summary$validation_split <- split_name
  context_summary$context_columns <- paste(context_columns, collapse = " + ")
  context_summary$context_label <- apply(
    context_summary[, context_columns, drop = FALSE],
    1,
    paste,
    collapse = " | "
  )
  context_summary$predicted_share_in_context <- round(
    context_summary$prediction_count / context_summary$context_total,
    4
  )
  context_summary$avg_predicted_probability <- round(
    context_summary$avg_predicted_probability,
    4
  )
  context_summary$accuracy <- round(context_summary$accuracy, 4)

  output_columns <- c(
    "validation_split",
    "context_name",
    "context_columns",
    "context_label",
    "stage1_v1_predicted_state",
    "prediction_count",
    "context_total",
    "predicted_share_in_context",
    "avg_predicted_probability",
    "accuracy"
  )

  context_summary <- context_summary[, output_columns]
  context_summary[order(
    context_summary$context_name,
    context_summary$stage1_v1_predicted_state,
    -context_summary$predicted_share_in_context,
    -context_summary$prediction_count
  ), ]
}

build_all_context_pattern_summaries <- function(prediction_output) {
  context_specs <- list(
    list("base_out_state", c("current_base_out_state"), 20),
    list("score_state", c("before_score_state"), 20),
    list("momentum_state", c("before_momentum_state"), 20),
    list("event_signal", c("before_event_signal"), 20),
    list("batter_pitcher_type", c("batter_pitcher_type_context"), 20),
    list("base_out_player_context", c("base_out_player_context"), 20)
  )

  do.call(rbind, lapply(context_specs, function(spec) {
    summarize_context_patterns(
      prediction_output = prediction_output,
      context_columns = spec[[2]],
      context_name = spec[[1]],
      minimum_context_rows = spec[[3]]
    )
  }))
}

build_predicted_state_profiles <- function(prediction_output, split_name = "test") {
  split_data <- prediction_output[prediction_output$validation_split == split_name, ]

  profile <- aggregate(
    split_data[, c(
      "stage1_v1_predicted_probability",
      "is_correct_prediction",
      "run_expectancy_before",
      "score_diff_before",
      "outs_before",
      "bases_before"
    )],
    by = list(predicted_state = split_data$stage1_v1_predicted_state),
    FUN = mean
  )
  names(profile) <- c(
    "predicted_state",
    "avg_predicted_probability",
    "accuracy",
    "avg_run_expectancy_before",
    "avg_score_diff_before",
    "avg_outs_before",
    "avg_bases_before"
  )

  counts <- as.data.frame(table(
    split_data$stage1_v1_predicted_state
  ), stringsAsFactors = FALSE)
  names(counts) <- c("predicted_state", "prediction_count")

  profile <- merge(profile, counts, by = "predicted_state", all.x = TRUE)
  profile$validation_split <- split_name
  profile$prediction_share <- round(profile$prediction_count / nrow(split_data), 4)

  numeric_columns <- c(
    "avg_predicted_probability",
    "accuracy",
    "avg_run_expectancy_before",
    "avg_score_diff_before",
    "avg_outs_before",
    "avg_bases_before"
  )
  for (column_name in numeric_columns) {
    profile[[column_name]] <- round(profile[[column_name]], 4)
  }

  profile <- profile[, c(
    "validation_split",
    "predicted_state",
    "prediction_count",
    "prediction_share",
    "avg_predicted_probability",
    "accuracy",
    "avg_run_expectancy_before",
    "avg_score_diff_before",
    "avg_outs_before",
    "avg_bases_before"
  )]

  profile[order(-profile$prediction_count), ]
}

build_high_confidence_summary <- function(prediction_output, split_name = "test") {
  split_data <- prediction_output[prediction_output$validation_split == split_name, ]
  split_data$confidence_bin <- cut(
    split_data$stage1_v1_predicted_probability,
    breaks = c(0, 0.4, 0.5, 0.6, 0.7, 1.0),
    include.lowest = TRUE,
    right = FALSE,
    labels = c("0.00_to_0.40", "0.40_to_0.50", "0.50_to_0.60", "0.60_to_0.70", "0.70_to_1.00")
  )

  group_columns <- c("confidence_bin", "stage1_v1_predicted_state")
  summary <- aggregate(
    split_data[, c("stage1_v1_predicted_probability", "is_correct_prediction")],
    by = split_data[, group_columns, drop = FALSE],
    FUN = mean
  )
  names(summary)[
    names(summary) == "stage1_v1_predicted_probability"
  ] <- "avg_predicted_probability"
  names(summary)[names(summary) == "is_correct_prediction"] <- "accuracy"

  counts <- aggregate(
    rep(1, nrow(split_data)),
    by = split_data[, group_columns, drop = FALSE],
    FUN = sum
  )
  names(counts)[ncol(counts)] <- "prediction_count"

  summary <- merge(summary, counts, by = group_columns, all.x = TRUE)
  summary$validation_split <- split_name
  summary$prediction_share <- round(summary$prediction_count / nrow(split_data), 4)
  summary$avg_predicted_probability <- round(summary$avg_predicted_probability, 4)
  summary$accuracy <- round(summary$accuracy, 4)

  summary <- summary[, c(
    "validation_split",
    "confidence_bin",
    "stage1_v1_predicted_state",
    "prediction_count",
    "prediction_share",
    "avg_predicted_probability",
    "accuracy"
  )]

  summary[order(summary$confidence_bin, -summary$prediction_count), ]
}

save_stage1_v1_pattern_outputs <- function(
  context_patterns,
  state_profiles,
  high_confidence_summary,
  context_patterns_path = "outputs/prediction/stage1_v1_context_pattern_summary.csv",
  state_profiles_path = "outputs/prediction/stage1_v1_predicted_state_profiles.csv",
  high_confidence_path = "outputs/prediction/stage1_v1_high_confidence_summary.csv"
) {
  output_dir <- dirname(context_patterns_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(context_patterns, context_patterns_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(state_profiles, state_profiles_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(high_confidence_summary, high_confidence_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    context_patterns_path = context_patterns_path,
    state_profiles_path = state_profiles_path,
    high_confidence_path = high_confidence_path
  )
}

if (sys.nframe() == 0) {
  prediction_output <- load_stage1_v1_prediction_output()
  pattern_dataset <- prepare_pattern_dataset(prediction_output)

  context_patterns <- build_all_context_pattern_summaries(pattern_dataset)
  state_profiles <- build_predicted_state_profiles(pattern_dataset)
  high_confidence_summary <- build_high_confidence_summary(pattern_dataset)

  output_paths <- save_stage1_v1_pattern_outputs(
    context_patterns,
    state_profiles,
    high_confidence_summary
  )

  message("Saved context pattern summary to: ", output_paths$context_patterns_path)
  message("Saved predicted state profiles to: ", output_paths$state_profiles_path)
  message("Saved high confidence summary to: ", output_paths$high_confidence_path)
}
