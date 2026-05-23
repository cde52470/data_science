#!/usr/bin/env Rscript

# Validate Stage 2 win probability details for the frequency baseline.
# Run from the project root:
# Rscript prediction/28_validate_stage2_win_probability_details.R

source("prediction/27_train_stage2_win_probability_baseline.R")

load_stage2_frequency_predictions <- function(
  input_path = "outputs/prediction/stage2_win_frequency_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 2 frequency predictions not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

prepare_stage2_frequency_validation_dataset <- function(predictions) {
  required_columns <- c(
    "validation_split",
    "team_win",
    "combined_state_win_probability",
    "frequency_predicted_team_win",
    "combined_state_train_rows",
    "inning_phase",
    "score_state",
    "momentum_state",
    "combined_state"
  )
  assert_required_columns(predictions, required_columns)

  predictions$team_win <- as.logical(predictions$team_win)
  predictions$frequency_predicted_team_win <- as.logical(
    predictions$frequency_predicted_team_win
  )
  predictions$combined_state_win_probability <- as.numeric(
    predictions$combined_state_win_probability
  )
  predictions$combined_state_train_rows <- as.integer(
    predictions$combined_state_train_rows
  )

  predictions
}

build_stage2_probability_bins <- function(predictions, split_name = "test") {
  split_data <- predictions[predictions$validation_split == split_name, ]
  split_data$probability_bin <- cut(
    split_data$combined_state_win_probability,
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
    split_data[, c("combined_state_win_probability", "team_win")],
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

build_stage2_inning_phase_metrics <- function(predictions, split_name = "test") {
  split_data <- predictions[predictions$validation_split == split_name, ]

  do.call(rbind, lapply(sort(unique(split_data$inning_phase)), function(phase_name) {
    phase_data <- split_data[split_data$inning_phase == phase_name, ]

    data.frame(
      validation_split = split_name,
      inning_phase = phase_name,
      row_count = nrow(phase_data),
      accuracy = round(mean(
        phase_data$team_win == phase_data$frequency_predicted_team_win,
        na.rm = TRUE
      ), 4),
      brier_score = round(mean(
        (phase_data$combined_state_win_probability - as.integer(phase_data$team_win)) ^ 2,
        na.rm = TRUE
      ), 4),
      avg_predicted_probability = round(mean(
        phase_data$combined_state_win_probability,
        na.rm = TRUE
      ), 4),
      actual_win_rate = round(mean(phase_data$team_win, na.rm = TRUE), 4),
      stringsAsFactors = FALSE
    )
  }))
}

build_stage2_sample_size_bins <- function(predictions, split_name = "test") {
  split_data <- predictions[predictions$validation_split == split_name, ]
  split_data$sample_size_bin <- cut(
    split_data$combined_state_train_rows,
    breaks = c(-1, 0, 10, 30, 100, Inf),
    right = TRUE,
    labels = c(
      "0_train_rows",
      "1_to_10_train_rows",
      "11_to_30_train_rows",
      "31_to_100_train_rows",
      "101_plus_train_rows"
    )
  )

  do.call(rbind, lapply(sort(unique(split_data$sample_size_bin)), function(bin_name) {
    bin_data <- split_data[split_data$sample_size_bin == bin_name, ]

    data.frame(
      validation_split = split_name,
      sample_size_bin = as.character(bin_name),
      row_count = nrow(bin_data),
      accuracy = round(mean(
        bin_data$team_win == bin_data$frequency_predicted_team_win,
        na.rm = TRUE
      ), 4),
      brier_score = round(mean(
        (bin_data$combined_state_win_probability - as.integer(bin_data$team_win)) ^ 2,
        na.rm = TRUE
      ), 4),
      avg_predicted_probability = round(mean(
        bin_data$combined_state_win_probability,
        na.rm = TRUE
      ), 4),
      actual_win_rate = round(mean(bin_data$team_win, na.rm = TRUE), 4),
      median_train_rows = round(median(bin_data$combined_state_train_rows), 0),
      stringsAsFactors = FALSE
    )
  }))
}

build_stage2_top_state_diagnostics <- function(predictions, split_name = "test") {
  split_data <- predictions[predictions$validation_split == split_name, ]

  state_summary <- aggregate(
    split_data[, c("combined_state_win_probability", "team_win")],
    by = list(combined_state = split_data$combined_state),
    FUN = mean
  )
  names(state_summary) <- c(
    "combined_state",
    "avg_predicted_probability",
    "actual_win_rate"
  )
  counts <- aggregate(
    split_data$team_win,
    by = list(combined_state = split_data$combined_state),
    FUN = length
  )
  names(counts)[2] <- "test_row_count"

  train_rows <- aggregate(
    split_data$combined_state_train_rows,
    by = list(combined_state = split_data$combined_state),
    FUN = max
  )
  names(train_rows)[2] <- "combined_state_train_rows"

  state_summary <- merge(state_summary, counts, by = "combined_state", all.x = TRUE)
  state_summary <- merge(state_summary, train_rows, by = "combined_state", all.x = TRUE)
  state_summary$absolute_error <- abs(
    state_summary$avg_predicted_probability - state_summary$actual_win_rate
  )
  state_summary <- state_summary[state_summary$test_row_count >= 10, ]

  state_summary$validation_split <- split_name
  numeric_columns <- c(
    "avg_predicted_probability",
    "actual_win_rate",
    "absolute_error"
  )
  for (column_name in numeric_columns) {
    state_summary[[column_name]] <- round(state_summary[[column_name]], 4)
  }

  state_summary <- state_summary[, c(
    "validation_split",
    "combined_state",
    "test_row_count",
    "combined_state_train_rows",
    "avg_predicted_probability",
    "actual_win_rate",
    "absolute_error"
  )]
  state_summary[order(-state_summary$absolute_error, -state_summary$test_row_count), ]
}

build_stage2_detail_recommendation <- function(probability_bins, sample_size_bins) {
  high_confidence_bins <- probability_bins[
    probability_bins$probability_bin %in% c("0.00_to_0.10", "0.90_to_1.00"),
  ]
  low_sample_bins <- sample_size_bins[
    sample_size_bins$sample_size_bin %in% c("1_to_10_train_rows", "11_to_30_train_rows"),
  ]

  data.frame(
    item = c(
      "probability_bin_check",
      "sample_size_check",
      "stage2_v1_default_model",
      "next_step"
    ),
    value = c(
      paste0(
        "high confidence bins max absolute error = ",
        round(max(abs(high_confidence_bins$prediction_error), na.rm = TRUE), 4)
      ),
      paste0(
        "low sample bins rows = ",
        sum(low_sample_bins$row_count, na.rm = TRUE)
      ),
      "combined_state_frequency",
      "build Stage 1 + Stage 2 integrated prediction output"
    ),
    stringsAsFactors = FALSE
  )
}

save_stage2_win_detail_outputs <- function(
  probability_bins,
  inning_phase_metrics,
  sample_size_bins,
  top_state_diagnostics,
  detail_recommendation,
  probability_bins_path = "outputs/prediction/stage2_win_frequency_probability_bins.csv",
  inning_phase_metrics_path = "outputs/prediction/stage2_win_frequency_inning_phase_metrics.csv",
  sample_size_bins_path = "outputs/prediction/stage2_win_frequency_sample_size_bins.csv",
  top_state_diagnostics_path = "outputs/prediction/stage2_win_frequency_top_state_diagnostics.csv",
  detail_recommendation_path = "outputs/prediction/stage2_win_frequency_detail_recommendation.csv"
) {
  output_dir <- dirname(probability_bins_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(inning_phase_metrics, inning_phase_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(sample_size_bins, sample_size_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(top_state_diagnostics, top_state_diagnostics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(detail_recommendation, detail_recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    probability_bins_path = probability_bins_path,
    inning_phase_metrics_path = inning_phase_metrics_path,
    sample_size_bins_path = sample_size_bins_path,
    top_state_diagnostics_path = top_state_diagnostics_path,
    detail_recommendation_path = detail_recommendation_path
  )
}

if (sys.nframe() == 0) {
  frequency_predictions <- load_stage2_frequency_predictions()
  validation_dataset <- prepare_stage2_frequency_validation_dataset(
    frequency_predictions
  )

  probability_bins <- build_stage2_probability_bins(validation_dataset)
  inning_phase_metrics <- build_stage2_inning_phase_metrics(validation_dataset)
  sample_size_bins <- build_stage2_sample_size_bins(validation_dataset)
  top_state_diagnostics <- build_stage2_top_state_diagnostics(validation_dataset)
  detail_recommendation <- build_stage2_detail_recommendation(
    probability_bins,
    sample_size_bins
  )

  output_paths <- save_stage2_win_detail_outputs(
    probability_bins,
    inning_phase_metrics,
    sample_size_bins,
    top_state_diagnostics,
    detail_recommendation
  )

  message("Saved Stage 2 probability bins to: ", output_paths$probability_bins_path)
  message("Saved Stage 2 inning phase metrics to: ", output_paths$inning_phase_metrics_path)
  message("Saved Stage 2 sample size bins to: ", output_paths$sample_size_bins_path)
  message("Saved Stage 2 top state diagnostics to: ", output_paths$top_state_diagnostics_path)
  message("Saved Stage 2 detail recommendation to: ", output_paths$detail_recommendation_path)
}
