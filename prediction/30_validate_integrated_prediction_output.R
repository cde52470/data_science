#!/usr/bin/env Rscript

# Validate integrated Stage 1 + Stage 2 prediction output.
# Run from the project root:
# Rscript prediction/30_validate_integrated_prediction_output.R

source("prediction/09_build_stage1_frequency_baseline.R")

load_integrated_prediction_output <- function(
  input_path = "outputs/prediction/stage1_stage2_integrated_prediction_output.csv"
) {
  if (!file.exists(input_path)) {
    stop("Integrated prediction output not found: ", input_path)
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

build_final_team_outcome_lookup <- function(stage2_dataset) {
  required_columns <- c(
    "game_id",
    "team",
    "final_team_runs",
    "final_opponent_runs",
    "final_run_diff",
    "team_win"
  )
  assert_required_columns(stage2_dataset, required_columns)

  outcome_lookup <- unique(stage2_dataset[, required_columns])
  outcome_lookup$team_win <- as.logical(outcome_lookup$team_win)
  names(outcome_lookup)[names(outcome_lookup) == "team"] <- "batting_team"

  outcome_lookup
}

attach_final_outcomes_to_integrated_output <- function(integrated_output, outcome_lookup) {
  required_columns <- c(
    "game_id",
    "batting_team",
    "validation_split",
    "inning_phase",
    "integrated_expected_win_probability"
  )
  assert_required_columns(integrated_output, required_columns)

  validation_dataset <- merge(
    integrated_output,
    outcome_lookup,
    by = c("game_id", "batting_team"),
    all.x = TRUE,
    sort = FALSE
  )
  validation_dataset$team_win <- as.logical(validation_dataset$team_win)
  validation_dataset$integrated_predicted_team_win <- (
    validation_dataset$integrated_expected_win_probability >= 0.5
  )

  validation_dataset
}

calculate_integrated_binary_metrics <- function(validation_dataset) {
  do.call(rbind, lapply(
    sort(unique(validation_dataset$validation_split)),
    function(split_name) {
      split_data <- validation_dataset[
        validation_dataset$validation_split == split_name,
      ]
      actual <- split_data$team_win
      predicted <- split_data$integrated_predicted_team_win
      probability <- split_data$integrated_expected_win_probability

      true_positive <- sum(actual & predicted, na.rm = TRUE)
      false_positive <- sum(!actual & predicted, na.rm = TRUE)
      false_negative <- sum(actual & !predicted, na.rm = TRUE)
      true_negative <- sum(!actual & !predicted, na.rm = TRUE)

      precision <- ifelse(
        true_positive + false_positive == 0,
        NA_real_,
        true_positive / (true_positive + false_positive)
      )
      recall <- ifelse(
        true_positive + false_negative == 0,
        NA_real_,
        true_positive / (true_positive + false_negative)
      )
      specificity <- ifelse(
        true_negative + false_positive == 0,
        NA_real_,
        true_negative / (true_negative + false_positive)
      )
      f1_score <- ifelse(
        is.na(precision) | is.na(recall) | precision + recall == 0,
        NA_real_,
        2 * precision * recall / (precision + recall)
      )

      data.frame(
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 4),
        precision = round(precision, 4),
        recall = round(recall, 4),
        specificity = round(specificity, 4),
        f1_score = round(f1_score, 4),
        brier_score = round(mean((probability - as.integer(actual)) ^ 2, na.rm = TRUE), 4),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 4),
        avg_predicted_probability = round(mean(probability, na.rm = TRUE), 4),
        predicted_positive_rate = round(mean(predicted, na.rm = TRUE), 4),
        stringsAsFactors = FALSE
      )
    }
  ))
}

build_integrated_probability_bins <- function(validation_dataset, split_name = "test") {
  split_data <- validation_dataset[
    validation_dataset$validation_split == split_name,
  ]
  split_data$probability_bin <- cut(
    split_data$integrated_expected_win_probability,
    breaks = c(0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 1.000001),
    include.lowest = TRUE,
    right = FALSE,
    labels = c(
      "0.00_to_0.10",
      "0.10_to_0.25",
      "0.25_to_0.40",
      "0.40_to_0.50",
      "0.50_to_0.60",
      "0.60_to_0.75",
      "0.75_to_0.90",
      "0.90_to_1.00"
    )
  )

  bin_summary <- aggregate(
    split_data[, c("integrated_expected_win_probability", "team_win")],
    by = list(probability_bin = split_data$probability_bin),
    FUN = mean
  )
  names(bin_summary) <- c(
    "probability_bin",
    "avg_predicted_probability",
    "actual_win_rate"
  )
  counts <- as.data.frame(table(split_data$probability_bin), stringsAsFactors = FALSE)
  names(counts) <- c("probability_bin", "row_count")

  bin_summary <- merge(bin_summary, counts, by = "probability_bin", all.x = TRUE)
  bin_summary$validation_split <- split_name
  bin_summary$prediction_error <- round(
    bin_summary$avg_predicted_probability - bin_summary$actual_win_rate,
    4
  )
  bin_summary$avg_predicted_probability <- round(
    bin_summary$avg_predicted_probability,
    4
  )
  bin_summary$actual_win_rate <- round(bin_summary$actual_win_rate, 4)

  bin_summary[, c(
    "validation_split",
    "probability_bin",
    "row_count",
    "avg_predicted_probability",
    "actual_win_rate",
    "prediction_error"
  )]
}

build_integrated_inning_phase_metrics <- function(validation_dataset, split_name = "test") {
  split_data <- validation_dataset[
    validation_dataset$validation_split == split_name,
  ]

  do.call(rbind, lapply(sort(unique(split_data$inning_phase)), function(phase_name) {
    phase_data <- split_data[split_data$inning_phase == phase_name, ]

    data.frame(
      validation_split = split_name,
      inning_phase = phase_name,
      row_count = nrow(phase_data),
      accuracy = round(mean(
        phase_data$team_win == phase_data$integrated_predicted_team_win,
        na.rm = TRUE
      ), 4),
      brier_score = round(mean(
        (phase_data$integrated_expected_win_probability - as.integer(phase_data$team_win)) ^ 2,
        na.rm = TRUE
      ), 4),
      avg_predicted_probability = round(mean(
        phase_data$integrated_expected_win_probability,
        na.rm = TRUE
      ), 4),
      actual_win_rate = round(mean(phase_data$team_win, na.rm = TRUE), 4),
      stringsAsFactors = FALSE
    )
  }))
}

build_integrated_decile_summary <- function(validation_dataset, split_name = "test") {
  split_data <- validation_dataset[
    validation_dataset$validation_split == split_name,
  ]
  split_data <- split_data[order(split_data$integrated_expected_win_probability), ]
  split_data$probability_decile <- ceiling(seq_len(nrow(split_data)) / nrow(split_data) * 10)
  split_data$probability_decile <- pmin(split_data$probability_decile, 10)

  decile_summary <- aggregate(
    split_data[, c("integrated_expected_win_probability", "team_win")],
    by = list(probability_decile = split_data$probability_decile),
    FUN = mean
  )
  names(decile_summary) <- c(
    "probability_decile",
    "avg_predicted_probability",
    "actual_win_rate"
  )
  counts <- as.data.frame(table(split_data$probability_decile), stringsAsFactors = FALSE)
  names(counts) <- c("probability_decile", "row_count")
  counts$probability_decile <- as.integer(as.character(counts$probability_decile))

  decile_summary <- merge(
    decile_summary,
    counts,
    by = "probability_decile",
    all.x = TRUE
  )
  decile_summary$validation_split <- split_name
  decile_summary$avg_predicted_probability <- round(
    decile_summary$avg_predicted_probability,
    4
  )
  decile_summary$actual_win_rate <- round(decile_summary$actual_win_rate, 4)

  decile_summary[, c(
    "validation_split",
    "probability_decile",
    "row_count",
    "avg_predicted_probability",
    "actual_win_rate"
  )]
}

build_integrated_validation_recommendation <- function(metrics, decile_summary) {
  test_metrics <- metrics[metrics$validation_split == "test", ]
  bottom_decile <- decile_summary[decile_summary$probability_decile == 1, ]
  top_decile <- decile_summary[decile_summary$probability_decile == 10, ]

  data.frame(
    item = c(
      "test_accuracy",
      "test_brier_score",
      "bottom_decile_actual_win_rate",
      "top_decile_actual_win_rate",
      "decile_win_rate_spread",
      "next_step"
    ),
    value = c(
      test_metrics$accuracy,
      test_metrics$brier_score,
      bottom_decile$actual_win_rate,
      top_decile$actual_win_rate,
      round(top_decile$actual_win_rate - bottom_decile$actual_win_rate, 4),
      "decide whether to upgrade Stage 1 target from momentum_state to combined_state"
    ),
    stringsAsFactors = FALSE
  )
}

save_integrated_validation_outputs <- function(
  validation_dataset,
  metrics,
  probability_bins,
  inning_phase_metrics,
  decile_summary,
  recommendation,
  validation_rows_path = "outputs/prediction/stage1_stage2_integrated_validation_rows.csv",
  metrics_path = "outputs/prediction/stage1_stage2_integrated_validation_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_stage2_integrated_probability_bins.csv",
  inning_phase_metrics_path = "outputs/prediction/stage1_stage2_integrated_inning_phase_metrics.csv",
  decile_summary_path = "outputs/prediction/stage1_stage2_integrated_decile_summary.csv",
  recommendation_path = "outputs/prediction/stage1_stage2_integrated_validation_recommendation.csv"
) {
  output_dir <- dirname(validation_rows_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(validation_dataset, validation_rows_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(metrics, metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(inning_phase_metrics, inning_phase_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(decile_summary, decile_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    validation_rows_path = validation_rows_path,
    metrics_path = metrics_path,
    probability_bins_path = probability_bins_path,
    inning_phase_metrics_path = inning_phase_metrics_path,
    decile_summary_path = decile_summary_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  integrated_output <- load_integrated_prediction_output()
  stage2_dataset <- load_stage2_inning_outcome_dataset()
  outcome_lookup <- build_final_team_outcome_lookup(stage2_dataset)

  validation_dataset <- attach_final_outcomes_to_integrated_output(
    integrated_output,
    outcome_lookup
  )
  metrics <- calculate_integrated_binary_metrics(validation_dataset)
  probability_bins <- build_integrated_probability_bins(validation_dataset)
  inning_phase_metrics <- build_integrated_inning_phase_metrics(validation_dataset)
  decile_summary <- build_integrated_decile_summary(validation_dataset)
  recommendation <- build_integrated_validation_recommendation(
    metrics,
    decile_summary
  )

  output_paths <- save_integrated_validation_outputs(
    validation_dataset,
    metrics,
    probability_bins,
    inning_phase_metrics,
    decile_summary,
    recommendation
  )

  message("Saved integrated validation rows to: ", output_paths$validation_rows_path)
  message("Saved integrated validation metrics to: ", output_paths$metrics_path)
  message("Saved integrated probability bins to: ", output_paths$probability_bins_path)
  message("Saved integrated inning phase metrics to: ", output_paths$inning_phase_metrics_path)
  message("Saved integrated decile summary to: ", output_paths$decile_summary_path)
  message("Saved integrated validation recommendation to: ", output_paths$recommendation_path)
}
