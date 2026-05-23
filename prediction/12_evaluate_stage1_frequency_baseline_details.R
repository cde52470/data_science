#!/usr/bin/env Rscript

# Evaluate Stage 1 frequency baseline in more detail.
# Run from the project root:
# Rscript prediction/12_evaluate_stage1_frequency_baseline_details.R

load_time_split_predictions <- function(
  input_path = "outputs/prediction/stage1_frequency_baseline_time_split_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 time split predictions not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

assert_required_columns <- function(dataset, required_columns) {
  missing_columns <- setdiff(required_columns, names(dataset))

  if (length(missing_columns) > 0) {
    stop(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }

  invisible(TRUE)
}

calculate_class_metrics_for_split <- function(prediction_dataset, split_name) {
  split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]
  classes <- sort(unique(c(
    split_data$stage1_target_momentum_state,
    split_data$predicted_momentum_state
  )))

  do.call(rbind, lapply(classes, function(class_name) {
    true_positive <- sum(
      split_data$stage1_target_momentum_state == class_name &
        split_data$predicted_momentum_state == class_name
    )
    false_positive <- sum(
      split_data$stage1_target_momentum_state != class_name &
        split_data$predicted_momentum_state == class_name
    )
    false_negative <- sum(
      split_data$stage1_target_momentum_state == class_name &
        split_data$predicted_momentum_state != class_name
    )
    true_negative <- sum(
      split_data$stage1_target_momentum_state != class_name &
        split_data$predicted_momentum_state != class_name
    )

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
    f1_score <- ifelse(
      is.na(precision) | is.na(recall) | precision + recall == 0,
      NA_real_,
      2 * precision * recall / (precision + recall)
    )

    data.frame(
      validation_split = split_name,
      class = class_name,
      support = sum(split_data$stage1_target_momentum_state == class_name),
      predicted_count = sum(split_data$predicted_momentum_state == class_name),
      true_positive = true_positive,
      false_positive = false_positive,
      false_negative = false_negative,
      true_negative = true_negative,
      precision = round(precision, 4),
      recall = round(recall, 4),
      f1_score = round(f1_score, 4),
      stringsAsFactors = FALSE
    )
  }))
}

calculate_class_metrics <- function(prediction_dataset) {
  assert_required_columns(prediction_dataset, c(
    "validation_split",
    "stage1_target_momentum_state",
    "predicted_momentum_state"
  ))

  split_names <- sort(unique(prediction_dataset$validation_split))

  class_metrics <- do.call(rbind, lapply(split_names, function(split_name) {
    calculate_class_metrics_for_split(prediction_dataset, split_name)
  }))

  row.names(class_metrics) <- NULL
  class_metrics
}

calculate_majority_baseline_comparison <- function(prediction_dataset) {
  split_names <- sort(unique(prediction_dataset$validation_split))

  comparison <- do.call(rbind, lapply(split_names, function(split_name) {
    split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]

    target_counts <- sort(table(split_data$stage1_target_momentum_state), decreasing = TRUE)
    majority_class <- names(target_counts)[1]
    majority_accuracy <- as.numeric(target_counts[1]) / nrow(split_data)
    frequency_accuracy <- mean(split_data$is_correct_prediction, na.rm = TRUE)

    data.frame(
      validation_split = split_name,
      majority_class = majority_class,
      rows = nrow(split_data),
      majority_correct = as.numeric(target_counts[1]),
      majority_accuracy = round(majority_accuracy, 4),
      frequency_correct = sum(split_data$is_correct_prediction, na.rm = TRUE),
      frequency_accuracy = round(frequency_accuracy, 4),
      accuracy_lift = round(frequency_accuracy - majority_accuracy, 4),
      relative_lift = round(
        (frequency_accuracy - majority_accuracy) / majority_accuracy,
        4
      ),
      stringsAsFactors = FALSE
    )
  }))

  row.names(comparison) <- NULL
  comparison
}

assign_probability_bin <- function(probabilities) {
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

calculate_probability_bins <- function(prediction_dataset) {
  assert_required_columns(prediction_dataset, c(
    "validation_split",
    "predicted_probability",
    "is_correct_prediction"
  ))

  prediction_dataset$probability_bin <- assign_probability_bin(
    prediction_dataset$predicted_probability
  )

  split_bin_counts <- aggregate(
    prediction_dataset$is_correct_prediction,
    by = prediction_dataset[, c("validation_split", "probability_bin")],
    FUN = function(values) {
      sum(values, na.rm = TRUE)
    }
  )
  names(split_bin_counts)[ncol(split_bin_counts)] <- "correct_count"

  split_bin_totals <- aggregate(
    rep(1, nrow(prediction_dataset)),
    by = prediction_dataset[, c("validation_split", "probability_bin")],
    FUN = sum
  )
  names(split_bin_totals)[ncol(split_bin_totals)] <- "total_count"

  probability_bins <- merge(
    split_bin_counts,
    split_bin_totals,
    by = c("validation_split", "probability_bin"),
    all.x = TRUE,
    sort = FALSE
  )

  probability_bins$accuracy <- round(
    probability_bins$correct_count / probability_bins$total_count,
    4
  )

  probability_bin_means <- aggregate(
    prediction_dataset$predicted_probability,
    by = prediction_dataset[, c("validation_split", "probability_bin")],
    FUN = mean
  )
  names(probability_bin_means)[ncol(probability_bin_means)] <- "mean_predicted_probability"

  probability_bins <- merge(
    probability_bins,
    probability_bin_means,
    by = c("validation_split", "probability_bin"),
    all.x = TRUE,
    sort = FALSE
  )

  probability_bins$mean_predicted_probability <- round(
    probability_bins$mean_predicted_probability,
    4
  )

  probability_bins <- probability_bins[order(
    probability_bins$validation_split,
    probability_bins$probability_bin
  ), ]

  row.names(probability_bins) <- NULL
  probability_bins
}

calculate_confusion_matrix_rate <- function(prediction_dataset) {
  confusion_matrix <- as.data.frame(table(
    prediction_dataset$validation_split,
    prediction_dataset$stage1_target_momentum_state,
    prediction_dataset$predicted_momentum_state
  ), stringsAsFactors = FALSE)

  names(confusion_matrix) <- c(
    "validation_split",
    "actual_momentum_state",
    "predicted_momentum_state",
    "count"
  )

  actual_totals <- aggregate(
    confusion_matrix$count,
    by = confusion_matrix[, c("validation_split", "actual_momentum_state")],
    FUN = sum
  )
  names(actual_totals)[ncol(actual_totals)] <- "actual_total"

  confusion_matrix <- merge(
    confusion_matrix,
    actual_totals,
    by = c("validation_split", "actual_momentum_state"),
    all.x = TRUE,
    sort = FALSE
  )

  confusion_matrix$rate_within_actual <- round(
    confusion_matrix$count / confusion_matrix$actual_total,
    4
  )
  confusion_matrix <- confusion_matrix[confusion_matrix$count > 0, ]

  confusion_matrix <- confusion_matrix[order(
    confusion_matrix$validation_split,
    confusion_matrix$actual_momentum_state,
    -confusion_matrix$count
  ), ]

  row.names(confusion_matrix) <- NULL
  confusion_matrix
}

save_detailed_evaluation_outputs <- function(
  class_metrics,
  majority_baseline_comparison,
  probability_bins,
  confusion_matrix_rate,
  class_metrics_path = "outputs/prediction/stage1_frequency_baseline_class_metrics.csv",
  majority_comparison_path = "outputs/prediction/stage1_frequency_baseline_majority_baseline_comparison.csv",
  probability_bins_path = "outputs/prediction/stage1_frequency_baseline_probability_bins.csv",
  confusion_matrix_rate_path = "outputs/prediction/stage1_frequency_baseline_confusion_matrix_rate.csv"
) {
  output_dir <- dirname(class_metrics_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(majority_baseline_comparison, majority_comparison_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(confusion_matrix_rate, confusion_matrix_rate_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    class_metrics_path = class_metrics_path,
    majority_comparison_path = majority_comparison_path,
    probability_bins_path = probability_bins_path,
    confusion_matrix_rate_path = confusion_matrix_rate_path
  )
}

if (sys.nframe() == 0) {
  prediction_dataset <- load_time_split_predictions()

  class_metrics <- calculate_class_metrics(prediction_dataset)
  majority_baseline_comparison <- calculate_majority_baseline_comparison(prediction_dataset)
  probability_bins <- calculate_probability_bins(prediction_dataset)
  confusion_matrix_rate <- calculate_confusion_matrix_rate(prediction_dataset)

  output_paths <- save_detailed_evaluation_outputs(
    class_metrics,
    majority_baseline_comparison,
    probability_bins,
    confusion_matrix_rate
  )

  test_comparison <- majority_baseline_comparison[
    majority_baseline_comparison$validation_split == "test",
  ]

  message("Saved class metrics to: ", output_paths$class_metrics_path)
  message("Saved majority baseline comparison to: ", output_paths$majority_comparison_path)
  message("Saved probability bins to: ", output_paths$probability_bins_path)
  message("Saved confusion matrix rates to: ", output_paths$confusion_matrix_rate_path)
  message("Test majority accuracy: ", test_comparison$majority_accuracy)
  message("Test frequency accuracy: ", test_comparison$frequency_accuracy)
  message("Test accuracy lift: ", test_comparison$accuracy_lift)
}
