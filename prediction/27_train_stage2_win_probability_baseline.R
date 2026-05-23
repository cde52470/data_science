#!/usr/bin/env Rscript

# Train Stage 2 win probability baseline models.
# Run from the project root:
# Rscript prediction/27_train_stage2_win_probability_baseline.R

source("prediction/26_validate_stage2_state_outcome_signal.R")

create_stage2_chronological_split <- function(
  stage2_dataset,
  train_proportion = 0.8
) {
  assert_required_columns(stage2_dataset, c("date", "game_id"))

  stage2_dataset$game_date <- as.Date(substr(stage2_dataset$date, 1, 10))

  if (any(is.na(stage2_dataset$game_date))) {
    stop("Unable to parse at least one Stage 2 game date.")
  }

  unique_dates <- sort(unique(stage2_dataset$game_date))
  split_index <- floor(length(unique_dates) * train_proportion)
  split_index <- max(1, min(split_index, length(unique_dates) - 1))
  train_dates <- unique_dates[seq_len(split_index)]

  stage2_dataset$validation_split <- ifelse(
    stage2_dataset$game_date %in% train_dates,
    "train",
    "test"
  )

  list(
    dataset = stage2_dataset,
    train_start_date = min(train_dates),
    train_end_date = max(train_dates),
    test_start_date = min(unique_dates[!(unique_dates %in% train_dates)]),
    test_end_date = max(unique_dates[!(unique_dates %in% train_dates)]),
    train_date_count = length(train_dates),
    test_date_count = length(unique_dates) - length(train_dates)
  )
}

prepare_stage2_win_model_dataset <- function(stage2_dataset) {
  required_columns <- c(
    "team_win",
    "validation_split",
    "score_state",
    "momentum_state",
    "event_signal",
    "combined_state",
    "inning_phase",
    "inning",
    "is_home",
    "run_diff_now"
  )
  assert_required_columns(stage2_dataset, required_columns)

  model_dataset <- stage2_dataset
  model_dataset$team_win <- as.logical(model_dataset$team_win)
  model_dataset$team_win_numeric <- as.integer(model_dataset$team_win)
  model_dataset$inning <- as.integer(model_dataset$inning)
  model_dataset$is_home <- as.factor(model_dataset$is_home)
  model_dataset$run_diff_now <- as.numeric(model_dataset$run_diff_now)

  categorical_columns <- c(
    "score_state",
    "momentum_state",
    "event_signal",
    "combined_state",
    "inning_phase"
  )
  for (column_name in categorical_columns) {
    model_dataset[[column_name]] <- factor(model_dataset[[column_name]])
  }

  model_dataset
}

calculate_binary_metrics <- function(prediction_dataset, probability_column, predicted_column) {
  do.call(rbind, lapply(
    sort(unique(prediction_dataset$validation_split)),
    function(split_name) {
      split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]
      actual <- split_data$team_win
      predicted <- split_data[[predicted_column]]
      probability <- split_data[[probability_column]]

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
      brier_score <- mean((probability - as.integer(actual)) ^ 2, na.rm = TRUE)

      data.frame(
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 4),
        precision = round(precision, 4),
        recall = round(recall, 4),
        specificity = round(specificity, 4),
        f1_score = round(f1_score, 4),
        brier_score = round(brier_score, 4),
        positive_rate = round(mean(actual, na.rm = TRUE), 4),
        predicted_positive_rate = round(mean(predicted, na.rm = TRUE), 4),
        stringsAsFactors = FALSE
      )
    }
  ))
}

build_majority_win_baseline <- function(split_dataset) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  majority_prediction <- mean(train_data$team_win) >= 0.5
  majority_probability <- mean(train_data$team_win)

  predictions <- split_dataset
  predictions$majority_predicted_probability <- majority_probability
  predictions$majority_predicted_team_win <- majority_prediction

  metrics <- calculate_binary_metrics(
    predictions,
    probability_column = "majority_predicted_probability",
    predicted_column = "majority_predicted_team_win"
  )
  metrics$model_name <- "majority_baseline"
  metrics
}

build_combined_state_frequency_table <- function(train_data) {
  group_summary <- aggregate(
    train_data$team_win_numeric,
    by = list(combined_state = train_data$combined_state),
    FUN = mean
  )
  names(group_summary)[2] <- "combined_state_win_probability"

  group_counts <- as.data.frame(table(train_data$combined_state), stringsAsFactors = FALSE)
  names(group_counts) <- c("combined_state", "combined_state_train_rows")

  merge(group_summary, group_counts, by = "combined_state", all.x = TRUE, sort = FALSE)
}

apply_combined_state_frequency_baseline <- function(split_dataset, frequency_table) {
  global_train_win_rate <- mean(
    split_dataset$team_win[split_dataset$validation_split == "train"],
    na.rm = TRUE
  )

  predictions <- merge(
    split_dataset,
    frequency_table,
    by = "combined_state",
    all.x = TRUE,
    sort = FALSE
  )
  predictions$frequency_fallback_used <- is.na(
    predictions$combined_state_win_probability
  )
  predictions$combined_state_win_probability[
    predictions$frequency_fallback_used
  ] <- global_train_win_rate
  predictions$combined_state_train_rows[
    is.na(predictions$combined_state_train_rows)
  ] <- 0
  predictions$frequency_predicted_team_win <- (
    predictions$combined_state_win_probability >= 0.5
  )

  predictions
}

build_frequency_win_baseline <- function(split_dataset) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  frequency_table <- build_combined_state_frequency_table(train_data)
  predictions <- apply_combined_state_frequency_baseline(split_dataset, frequency_table)

  metrics <- calculate_binary_metrics(
    predictions,
    probability_column = "combined_state_win_probability",
    predicted_column = "frequency_predicted_team_win"
  )
  metrics$model_name <- "combined_state_frequency"

  list(
    frequency_table = frequency_table,
    predictions = predictions,
    metrics = metrics
  )
}

train_stage2_logistic_model <- function(train_data) {
  glm(
    team_win ~ score_state + momentum_state + event_signal +
      inning_phase + inning + is_home + run_diff_now,
    data = train_data,
    family = binomial()
  )
}

build_logistic_win_baseline <- function(split_dataset) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  logistic_model <- train_stage2_logistic_model(train_data)

  predictions <- split_dataset
  predictions$logistic_predicted_probability <- as.numeric(predict(
    logistic_model,
    newdata = predictions,
    type = "response"
  ))
  predictions$logistic_predicted_team_win <- (
    predictions$logistic_predicted_probability >= 0.5
  )

  metrics <- calculate_binary_metrics(
    predictions,
    probability_column = "logistic_predicted_probability",
    predicted_column = "logistic_predicted_team_win"
  )
  metrics$model_name <- "logistic_regression"

  list(
    model = logistic_model,
    predictions = predictions,
    metrics = metrics
  )
}

build_stage2_win_model_comparison <- function(metric_tables) {
  comparison <- do.call(rbind, metric_tables)
  comparison <- comparison[, c(
    "model_name",
    "validation_split",
    "row_count",
    "accuracy",
    "precision",
    "recall",
    "specificity",
    "f1_score",
    "brier_score",
    "positive_rate",
    "predicted_positive_rate"
  )]

  comparison[order(
    comparison$validation_split,
    -comparison$accuracy,
    comparison$brier_score
  ), ]
}

build_stage2_win_recommendation <- function(model_comparison) {
  test_rows <- model_comparison[model_comparison$validation_split == "test", ]
  best_accuracy <- test_rows[order(-test_rows$accuracy, test_rows$brier_score), ][1, ]
  best_brier <- test_rows[order(test_rows$brier_score, -test_rows$accuracy), ][1, ]

  data.frame(
    item = c(
      "best_test_accuracy_model",
      "best_test_brier_model",
      "stage2_v1_default_model",
      "stage2_v1_reference_model",
      "next_step"
    ),
    value = c(
      best_accuracy$model_name,
      best_brier$model_name,
      best_accuracy$model_name,
      "logistic_regression",
      "validate Stage 2 win probability by inning_phase and probability bins"
    ),
    stringsAsFactors = FALSE
  )
}

save_stage2_win_baseline_outputs <- function(
  model_comparison,
  frequency_table,
  frequency_predictions,
  logistic_predictions,
  recommendation,
  comparison_path = "outputs/prediction/stage2_win_baseline_model_comparison.csv",
  frequency_table_path = "outputs/prediction/stage2_combined_state_win_frequency_table.csv",
  frequency_predictions_path = "outputs/prediction/stage2_win_frequency_predictions.csv",
  logistic_predictions_path = "outputs/prediction/stage2_win_logistic_predictions.csv",
  recommendation_path = "outputs/prediction/stage2_win_baseline_recommendation.csv"
) {
  output_dir <- dirname(comparison_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(model_comparison, comparison_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(frequency_table, frequency_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(frequency_predictions, frequency_predictions_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(logistic_predictions, logistic_predictions_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    comparison_path = comparison_path,
    frequency_table_path = frequency_table_path,
    frequency_predictions_path = frequency_predictions_path,
    logistic_predictions_path = logistic_predictions_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  stage2_dataset <- load_stage2_inning_outcome_dataset()
  stage2_dataset <- prepare_stage2_signal_dataset(stage2_dataset)
  split_info <- create_stage2_chronological_split(stage2_dataset)
  split_dataset <- prepare_stage2_win_model_dataset(split_info$dataset)

  majority_metrics <- build_majority_win_baseline(split_dataset)
  frequency_result <- build_frequency_win_baseline(split_dataset)
  logistic_result <- build_logistic_win_baseline(split_dataset)

  model_comparison <- build_stage2_win_model_comparison(list(
    majority_metrics,
    frequency_result$metrics,
    logistic_result$metrics
  ))
  recommendation <- build_stage2_win_recommendation(model_comparison)

  output_paths <- save_stage2_win_baseline_outputs(
    model_comparison = model_comparison,
    frequency_table = frequency_result$frequency_table,
    frequency_predictions = frequency_result$predictions,
    logistic_predictions = logistic_result$predictions,
    recommendation = recommendation
  )

  message("Saved Stage 2 win baseline comparison to: ", output_paths$comparison_path)
  message("Saved Stage 2 combined state frequency table to: ", output_paths$frequency_table_path)
  message("Saved Stage 2 frequency predictions to: ", output_paths$frequency_predictions_path)
  message("Saved Stage 2 logistic predictions to: ", output_paths$logistic_predictions_path)
  message("Saved Stage 2 win baseline recommendation to: ", output_paths$recommendation_path)
}
