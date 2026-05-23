#!/usr/bin/env Rscript

# Calibrate the confidence score of the selected Stage 1 weighted multinomial model.
# Run from the project root:
# Rscript prediction/17_calibrate_stage1_weighted_multinomial.R

source("prediction/15_tune_stage1_multinomial_class_weights.R")

create_chronological_three_way_split <- function(
  stage1_model_dataset,
  model_train_proportion = 0.7,
  calibration_proportion = 0.1
) {
  stage1_model_dataset$game_date <- parse_game_date(stage1_model_dataset$date)

  if (any(is.na(stage1_model_dataset$game_date))) {
    stop("Unable to parse at least one game date.")
  }

  unique_dates <- sort(unique(stage1_model_dataset$game_date))
  model_train_end <- floor(length(unique_dates) * model_train_proportion)
  calibration_end <- floor(length(unique_dates) * (
    model_train_proportion + calibration_proportion
  ))

  model_train_end <- max(1, min(model_train_end, length(unique_dates) - 2))
  calibration_end <- max(model_train_end + 1, min(calibration_end, length(unique_dates) - 1))

  model_train_dates <- unique_dates[seq_len(model_train_end)]
  calibration_dates <- unique_dates[(model_train_end + 1):calibration_end]

  stage1_model_dataset$calibration_split <- ifelse(
    stage1_model_dataset$game_date %in% model_train_dates,
    "model_train",
    ifelse(
      stage1_model_dataset$game_date %in% calibration_dates,
      "calibration",
      "test"
    )
  )

  stage1_model_dataset
}

assign_calibration_bin <- function(probabilities) {
  cut(
    probabilities,
    breaks = c(0, 0.3, 0.4, 0.5, 0.6, 0.7, 1),
    labels = c(
      "0.00-0.30",
      "0.30-0.40",
      "0.40-0.50",
      "0.50-0.60",
      "0.60-0.70",
      "0.70-1.00"
    ),
    include.lowest = TRUE,
    right = FALSE
  )
}

build_confidence_calibration_table <- function(calibration_predictions) {
  calibration_predictions$probability_bin <- assign_calibration_bin(
    calibration_predictions$predicted_probability
  )

  bin_accuracy <- aggregate(
    calibration_predictions$is_correct_prediction,
    by = calibration_predictions[, "probability_bin", drop = FALSE],
    FUN = mean
  )
  names(bin_accuracy)[ncol(bin_accuracy)] <- "calibrated_probability"

  bin_counts <- aggregate(
    rep(1, nrow(calibration_predictions)),
    by = calibration_predictions[, "probability_bin", drop = FALSE],
    FUN = sum
  )
  names(bin_counts)[ncol(bin_counts)] <- "calibration_count"

  bin_means <- aggregate(
    calibration_predictions$predicted_probability,
    by = calibration_predictions[, "probability_bin", drop = FALSE],
    FUN = mean
  )
  names(bin_means)[ncol(bin_means)] <- "mean_raw_probability"

  calibration_table <- merge(
    bin_accuracy,
    bin_counts,
    by = "probability_bin",
    all = TRUE
  )
  calibration_table <- merge(
    calibration_table,
    bin_means,
    by = "probability_bin",
    all = TRUE
  )

  calibration_table$calibrated_probability <- round(
    calibration_table$calibrated_probability,
    4
  )
  calibration_table$mean_raw_probability <- round(
    calibration_table$mean_raw_probability,
    4
  )

  calibration_table
}

apply_confidence_calibration <- function(prediction_dataset, calibration_table) {
  prediction_dataset$probability_bin <- assign_calibration_bin(
    prediction_dataset$predicted_probability
  )

  calibrated <- merge(
    prediction_dataset,
    calibration_table[, c("probability_bin", "calibrated_probability")],
    by = "probability_bin",
    all.x = TRUE,
    sort = FALSE
  )

  calibrated$calibrated_probability[is.na(calibrated$calibrated_probability)] <-
    calibrated$predicted_probability[is.na(calibrated$calibrated_probability)]

  calibrated[order(calibrated$row_id), ]
}

calculate_brier_score <- function(probability_values, correctness_values) {
  round(mean((probability_values - as.numeric(correctness_values)) ^ 2), 4)
}

create_calibration_evaluation <- function(calibrated_predictions) {
  split_names <- sort(unique(calibrated_predictions$calibration_split))

  do.call(rbind, lapply(split_names, function(split_name) {
    split_data <- calibrated_predictions[
      calibrated_predictions$calibration_split == split_name,
    ]

    data.frame(
      calibration_split = split_name,
      rows = nrow(split_data),
      accuracy = round(mean(split_data$is_correct_prediction), 4),
      raw_brier_score = calculate_brier_score(
        split_data$predicted_probability,
        split_data$is_correct_prediction
      ),
      calibrated_brier_score = calculate_brier_score(
        split_data$calibrated_probability,
        split_data$is_correct_prediction
      ),
      mean_raw_probability = round(mean(split_data$predicted_probability), 4),
      mean_calibrated_probability = round(mean(split_data$calibrated_probability), 4),
      stringsAsFactors = FALSE
    )
  }))
}

create_calibrated_probability_bins <- function(calibrated_predictions) {
  test_data <- calibrated_predictions[calibrated_predictions$calibration_split == "test", ]

  raw_bins <- aggregate(
    test_data$is_correct_prediction,
    by = test_data[, "probability_bin", drop = FALSE],
    FUN = mean
  )
  names(raw_bins)[ncol(raw_bins)] <- "actual_accuracy"

  raw_counts <- aggregate(
    rep(1, nrow(test_data)),
    by = test_data[, "probability_bin", drop = FALSE],
    FUN = sum
  )
  names(raw_counts)[ncol(raw_counts)] <- "test_count"

  raw_means <- aggregate(
    cbind(
      raw_probability = test_data$predicted_probability,
      calibrated_probability = test_data$calibrated_probability
    ),
    by = test_data[, "probability_bin", drop = FALSE],
    FUN = mean
  )

  bin_summary <- merge(raw_bins, raw_counts, by = "probability_bin", all = TRUE)
  bin_summary <- merge(bin_summary, raw_means, by = "probability_bin", all = TRUE)

  bin_summary$actual_accuracy <- round(bin_summary$actual_accuracy, 4)
  bin_summary$raw_probability <- round(bin_summary$raw_probability, 4)
  bin_summary$calibrated_probability <- round(bin_summary$calibrated_probability, 4)

  bin_summary[order(bin_summary$probability_bin), ]
}

save_calibration_outputs <- function(
  calibrated_predictions,
  calibration_table,
  calibration_evaluation,
  calibrated_probability_bins,
  prediction_path = "outputs/prediction/stage1_weighted_multinomial_calibrated_predictions.csv",
  calibration_table_path = "outputs/prediction/stage1_weighted_multinomial_calibration_table.csv",
  evaluation_path = "outputs/prediction/stage1_weighted_multinomial_calibration_evaluation.csv",
  probability_bins_path = "outputs/prediction/stage1_weighted_multinomial_calibrated_probability_bins.csv"
) {
  output_dir <- dirname(prediction_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(calibrated_predictions, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(calibration_table, calibration_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(calibration_evaluation, evaluation_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(calibrated_probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    calibration_table_path = calibration_table_path,
    evaluation_path = evaluation_path,
    probability_bins_path = probability_bins_path
  )
}

if (sys.nframe() == 0) {
  stage1_model_dataset <- load_stage1_model_dataset()
  split_dataset <- create_chronological_three_way_split(stage1_model_dataset)
  split_dataset$validation_split <- split_dataset$calibration_split
  split_dataset <- prepare_multinomial_dataset(split_dataset)

  model_train_dataset <- split_dataset[
    split_dataset$calibration_split == "model_train",
  ]
  sample_weights <- calculate_sample_weights(model_train_dataset, weight_power = 1)
  model <- train_weighted_multinomial_model(model_train_dataset, sample_weights)

  prediction_dataset <- predict_multinomial_baseline(model, split_dataset)
  prediction_dataset$row_id <- seq_len(nrow(prediction_dataset))

  calibration_predictions <- prediction_dataset[
    prediction_dataset$calibration_split == "calibration",
  ]
  calibration_table <- build_confidence_calibration_table(calibration_predictions)
  calibrated_predictions <- apply_confidence_calibration(
    prediction_dataset,
    calibration_table
  )

  calibration_evaluation <- create_calibration_evaluation(calibrated_predictions)
  calibrated_probability_bins <- create_calibrated_probability_bins(calibrated_predictions)

  output_paths <- save_calibration_outputs(
    calibrated_predictions,
    calibration_table,
    calibration_evaluation,
    calibrated_probability_bins
  )

  test_evaluation <- calibration_evaluation[
    calibration_evaluation$calibration_split == "test",
  ]

  message("Saved calibrated predictions to: ", output_paths$prediction_path)
  message("Saved calibration table to: ", output_paths$calibration_table_path)
  message("Saved calibration evaluation to: ", output_paths$evaluation_path)
  message("Saved calibrated probability bins to: ", output_paths$probability_bins_path)
  message("Test raw Brier score: ", test_evaluation$raw_brier_score)
  message("Test calibrated Brier score: ", test_evaluation$calibrated_brier_score)
}
