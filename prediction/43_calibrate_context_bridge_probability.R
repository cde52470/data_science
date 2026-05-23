#!/usr/bin/env Rscript

# Calibrate team-inning context bridge win probability.
# Run from the project root:
# Rscript prediction/43_calibrate_context_bridge_probability.R

load_context_bridge_team_inning_dataset <- function(
  input_path = "data/cleaned/stage1_scoring_stage2_win_context_bridge_team_inning_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Context bridge team-inning dataset not found: ", input_path)
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

assign_context_bridge_calibration_bin <- function(probabilities) {
  cut(
    probabilities,
    breaks = seq(0, 1, by = 0.1),
    include.lowest = TRUE
  )
}

build_context_bridge_calibration_table <- function(
  team_inning_dataset,
  probability_column = "mean_context_bridge_win_probability"
) {
  required_columns <- c(probability_column, "stage2_team_win", "validation_split")
  assert_required_columns(team_inning_dataset, required_columns)

  train_data <- team_inning_dataset[
    team_inning_dataset$validation_split == "train",
  ]
  train_data$calibration_bin <- assign_context_bridge_calibration_bin(
    train_data[[probability_column]]
  )

  actual_rate <- aggregate(
    as.integer(train_data$stage2_team_win),
    by = list(calibration_bin = train_data$calibration_bin),
    FUN = mean
  )
  names(actual_rate)[2] <- "calibrated_win_probability"

  bin_count <- aggregate(
    as.integer(train_data$stage2_team_win),
    by = list(calibration_bin = train_data$calibration_bin),
    FUN = length
  )
  names(bin_count)[2] <- "calibration_rows"

  raw_mean <- aggregate(
    train_data[[probability_column]],
    by = list(calibration_bin = train_data$calibration_bin),
    FUN = mean
  )
  names(raw_mean)[2] <- "mean_raw_win_probability"

  calibration_table <- merge(actual_rate, bin_count, by = "calibration_bin", all = TRUE)
  calibration_table <- merge(calibration_table, raw_mean, by = "calibration_bin", all = TRUE)
  calibration_table$probability_column <- probability_column
  calibration_table$calibrated_win_probability <- round(
    calibration_table$calibrated_win_probability,
    6
  )
  calibration_table$mean_raw_win_probability <- round(
    calibration_table$mean_raw_win_probability,
    6
  )

  calibration_table[, c(
    "probability_column",
    "calibration_bin",
    "calibration_rows",
    "mean_raw_win_probability",
    "calibrated_win_probability"
  )]
}

apply_context_bridge_calibration <- function(
  team_inning_dataset,
  calibration_table,
  probability_column = "mean_context_bridge_win_probability"
) {
  calibrated_dataset <- team_inning_dataset
  calibrated_dataset$calibration_bin <- assign_context_bridge_calibration_bin(
    calibrated_dataset[[probability_column]]
  )

  calibrated_dataset <- merge(
    calibrated_dataset,
    calibration_table[, c(
      "calibration_bin",
      "calibrated_win_probability",
      "calibration_rows"
    )],
    by = "calibration_bin",
    all.x = TRUE,
    sort = FALSE
  )

  missing_calibration <- is.na(calibrated_dataset$calibrated_win_probability)
  calibrated_dataset$calibrated_win_probability[missing_calibration] <-
    calibrated_dataset[[probability_column]][missing_calibration]
  calibrated_dataset$calibration_rows[missing_calibration] <- 0

  calibrated_dataset$raw_win_probability <- calibrated_dataset[[probability_column]]
  calibrated_dataset$raw_predicted_team_win <- calibrated_dataset$raw_win_probability >= 0.5
  calibrated_dataset$calibrated_predicted_team_win <-
    calibrated_dataset$calibrated_win_probability >= 0.5

  calibrated_dataset
}

calculate_context_bridge_calibration_metrics <- function(calibrated_dataset) {
  do.call(rbind, lapply(
    sort(unique(calibrated_dataset$validation_split)),
    function(split_name) {
      split_data <- calibrated_dataset[
        calibrated_dataset$validation_split == split_name,
      ]
      actual <- as.logical(split_data$stage2_team_win)

      data.frame(
        validation_split = split_name,
        row_count = nrow(split_data),
        raw_accuracy = round(
          mean(actual == split_data$raw_predicted_team_win, na.rm = TRUE),
          6
        ),
        calibrated_accuracy = round(
          mean(actual == split_data$calibrated_predicted_team_win, na.rm = TRUE),
          6
        ),
        raw_brier_score = round(mean(
          (split_data$raw_win_probability - as.integer(actual)) ^ 2,
          na.rm = TRUE
        ), 6),
        calibrated_brier_score = round(mean(
          (split_data$calibrated_win_probability - as.integer(actual)) ^ 2,
          na.rm = TRUE
        ), 6),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
        mean_raw_probability = round(mean(split_data$raw_win_probability, na.rm = TRUE), 6),
        mean_calibrated_probability = round(
          mean(split_data$calibrated_win_probability, na.rm = TRUE),
          6
        ),
        stringsAsFactors = FALSE
      )
    }
  ))
}

create_context_bridge_calibrated_bins <- function(calibrated_dataset) {
  do.call(rbind, lapply(
    split(calibrated_dataset, list(
      calibrated_dataset$validation_split,
      calibrated_dataset$calibration_bin
    ), drop = TRUE),
    function(bin_data) {
      data.frame(
        validation_split = bin_data$validation_split[1],
        calibration_bin = as.character(bin_data$calibration_bin[1]),
        row_count = nrow(bin_data),
        mean_raw_probability = round(mean(bin_data$raw_win_probability, na.rm = TRUE), 6),
        mean_calibrated_probability = round(
          mean(bin_data$calibrated_win_probability, na.rm = TRUE),
          6
        ),
        actual_win_rate = round(mean(as.logical(bin_data$stage2_team_win), na.rm = TRUE), 6),
        stringsAsFactors = FALSE
      )
    }
  ))
}

create_context_bridge_calibration_recommendation <- function(metrics) {
  test_metrics <- metrics[metrics$validation_split == "test", ]

  decision <- ifelse(
    test_metrics$calibrated_brier_score < test_metrics$raw_brier_score,
    "use_calibrated_mean_context_bridge_probability",
    "keep_raw_mean_context_bridge_probability_for_now"
  )

  data.frame(
    check_item = c(
      "test_raw_brier",
      "test_calibrated_brier",
      "test_raw_accuracy",
      "test_calibrated_accuracy",
      "recommendation"
    ),
    value = c(
      test_metrics$raw_brier_score,
      test_metrics$calibrated_brier_score,
      test_metrics$raw_accuracy,
      test_metrics$calibrated_accuracy,
      decision
    ),
    stringsAsFactors = FALSE
  )
}

save_context_bridge_calibration_outputs <- function(
  calibrated_dataset,
  calibration_table,
  metrics,
  probability_bins,
  recommendation,
  calibrated_dataset_path = "data/cleaned/stage1_scoring_stage2_win_context_bridge_team_inning_calibrated.csv",
  calibration_table_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_calibration_table.csv",
  metrics_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_calibration_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_calibrated_bins.csv",
  recommendation_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_calibration_recommendation.csv"
) {
  for (output_dir in unique(c(
    dirname(calibrated_dataset_path),
    dirname(calibration_table_path),
    dirname(metrics_path),
    dirname(probability_bins_path),
    dirname(recommendation_path)
  ))) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
  }

  write.csv(calibrated_dataset, calibrated_dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(calibration_table, calibration_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(metrics, metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    calibrated_dataset_path = calibrated_dataset_path,
    calibration_table_path = calibration_table_path,
    metrics_path = metrics_path,
    probability_bins_path = probability_bins_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  team_inning_dataset <- load_context_bridge_team_inning_dataset()
  probability_column <- "mean_context_bridge_win_probability"

  calibration_table <- build_context_bridge_calibration_table(
    team_inning_dataset,
    probability_column = probability_column
  )
  calibrated_dataset <- apply_context_bridge_calibration(
    team_inning_dataset,
    calibration_table,
    probability_column = probability_column
  )
  metrics <- calculate_context_bridge_calibration_metrics(calibrated_dataset)
  probability_bins <- create_context_bridge_calibrated_bins(calibrated_dataset)
  recommendation <- create_context_bridge_calibration_recommendation(metrics)

  output_paths <- save_context_bridge_calibration_outputs(
    calibrated_dataset,
    calibration_table,
    metrics,
    probability_bins,
    recommendation
  )

  message("Saved calibrated context bridge dataset to: ", output_paths$calibrated_dataset_path)
  message("Saved context bridge calibration table to: ", output_paths$calibration_table_path)
  message("Saved context bridge calibration metrics to: ", output_paths$metrics_path)
  message("Saved context bridge calibrated bins to: ", output_paths$probability_bins_path)
  message("Saved context bridge calibration recommendation to: ", output_paths$recommendation_path)
  message("Rows: ", nrow(calibrated_dataset))
  message("Columns: ", ncol(calibrated_dataset))
}
