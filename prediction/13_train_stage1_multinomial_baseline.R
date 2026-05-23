#!/usr/bin/env Rscript

# Train a Stage 1 multinomial logistic regression baseline.
# Run from the project root:
# Rscript prediction/13_train_stage1_multinomial_baseline.R

source("prediction/11_validate_stage1_frequency_baseline.R")
source("prediction/12_evaluate_stage1_frequency_baseline_details.R")

if (!requireNamespace("nnet", quietly = TRUE)) {
  stop("Required R package not installed: nnet")
}

get_multinomial_feature_columns <- function() {
  c(
    "before_score_state",
    "before_momentum_state",
    "before_event_signal",
    "current_base_out_state",
    "inning",
    "half_inning",
    "is_home_batting",
    "outs_before",
    "bases_before",
    "base_occupancy_before",
    "score_diff_before",
    "batting_score_before",
    "fielding_score_before",
    "run_expectancy_before",
    "batter_primary_type",
    "batter_sample_size_tier",
    "batter_contact_score",
    "batter_power_score",
    "batter_discipline_score",
    "batter_risk_score",
    "batter_run_value_score",
    "pitcher_primary_type",
    "pitcher_sample_size_tier",
    "pitcher_strikeout_score",
    "pitcher_control_score",
    "pitcher_suppression_score",
    "pitcher_power_risk_score",
    "pitcher_run_prevention_score"
  )
}

prepare_multinomial_dataset <- function(stage1_model_dataset) {
  feature_columns <- get_multinomial_feature_columns()
  required_columns <- c(
    "stage1_target_momentum_state",
    "validation_split",
    "game_date",
    feature_columns
  )
  assert_required_columns(stage1_model_dataset, required_columns)

  categorical_columns <- c(
    "before_score_state",
    "before_momentum_state",
    "before_event_signal",
    "current_base_out_state",
    "half_inning",
    "is_home_batting",
    "base_occupancy_before",
    "batter_primary_type",
    "batter_sample_size_tier",
    "pitcher_primary_type",
    "pitcher_sample_size_tier"
  )

  prepared_dataset <- stage1_model_dataset
  prepared_dataset$stage1_target_momentum_state <- factor(
    prepared_dataset$stage1_target_momentum_state
  )

  for (column_name in categorical_columns) {
    prepared_dataset[[column_name]] <- factor(prepared_dataset[[column_name]])
  }

  prepared_dataset
}

train_multinomial_model <- function(train_dataset) {
  feature_columns <- get_multinomial_feature_columns()
  formula_text <- paste(
    "stage1_target_momentum_state ~",
    paste(feature_columns, collapse = " + ")
  )

  nnet::multinom(
    formula = as.formula(formula_text),
    data = train_dataset,
    trace = FALSE,
    MaxNWts = 20000,
    maxit = 300
  )
}

predict_multinomial_baseline <- function(model, prediction_dataset) {
  probability_matrix <- predict(model, newdata = prediction_dataset, type = "probs")

  if (is.null(dim(probability_matrix))) {
    probability_matrix <- matrix(
      probability_matrix,
      ncol = length(probability_matrix)
    )
  }

  probability_matrix <- as.matrix(probability_matrix)
  predicted_index <- max.col(probability_matrix, ties.method = "first")

  prediction_dataset$stage1_target_momentum_state <- as.character(
    prediction_dataset$stage1_target_momentum_state
  )
  prediction_dataset$predicted_momentum_state <- colnames(probability_matrix)[predicted_index]
  prediction_dataset$predicted_probability <- probability_matrix[
    cbind(seq_len(nrow(probability_matrix)), predicted_index)
  ]
  prediction_dataset$is_correct_prediction <- (
    prediction_dataset$predicted_momentum_state ==
      as.character(prediction_dataset$stage1_target_momentum_state)
  )

  prediction_dataset
}

create_multinomial_summary <- function(prediction_dataset) {
  split_counts <- as.data.frame(table(
    prediction_dataset$validation_split
  ), stringsAsFactors = FALSE)
  names(split_counts) <- c("summary_item", "count")
  split_counts$summary_group <- "split_rows"
  split_counts$proportion <- round(split_counts$count / nrow(prediction_dataset), 4)
  split_counts <- split_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  split_accuracy <- do.call(rbind, lapply(
    sort(unique(prediction_dataset$validation_split)),
    function(split_name) {
      split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]

      data.frame(
        summary_group = "accuracy",
        summary_item = paste0(split_name, "_accuracy"),
        count = sum(split_data$is_correct_prediction, na.rm = TRUE),
        proportion = round(mean(split_data$is_correct_prediction, na.rm = TRUE), 4),
        stringsAsFactors = FALSE
      )
    }
  ))

  predicted_distribution <- as.data.frame(table(
    prediction_dataset$validation_split,
    prediction_dataset$predicted_momentum_state
  ), stringsAsFactors = FALSE)
  names(predicted_distribution) <- c(
    "validation_split",
    "predicted_momentum_state",
    "count"
  )
  predicted_distribution$summary_group <- "predicted_distribution"
  predicted_distribution$summary_item <- paste(
    predicted_distribution$validation_split,
    predicted_distribution$predicted_momentum_state,
    sep = "__"
  )
  predicted_distribution$proportion <- NA_real_

  for (split_name in unique(predicted_distribution$validation_split)) {
    split_total <- sum(prediction_dataset$validation_split == split_name)
    predicted_distribution$proportion[
      predicted_distribution$validation_split == split_name
    ] <- round(
      predicted_distribution$count[predicted_distribution$validation_split == split_name] / split_total,
      4
    )
  }

  predicted_distribution <- predicted_distribution[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  rbind(split_counts, split_accuracy, predicted_distribution)
}

create_model_comparison <- function(multinomial_predictions) {
  frequency_comparison <- read.csv(
    "outputs/prediction/stage1_frequency_baseline_majority_baseline_comparison.csv",
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )

  multinomial_comparison <- calculate_majority_baseline_comparison(multinomial_predictions)

  comparison <- merge(
    frequency_comparison[, c(
      "validation_split",
      "majority_accuracy",
      "frequency_accuracy"
    )],
    multinomial_comparison[, c(
      "validation_split",
      "frequency_accuracy"
    )],
    by = "validation_split",
    all = TRUE,
    suffixes = c("_frequency", "_multinomial")
  )

  names(comparison) <- c(
    "validation_split",
    "majority_accuracy",
    "frequency_accuracy",
    "multinomial_accuracy"
  )

  comparison$frequency_lift_vs_majority <- round(
    comparison$frequency_accuracy - comparison$majority_accuracy,
    4
  )
  comparison$multinomial_lift_vs_majority <- round(
    comparison$multinomial_accuracy - comparison$majority_accuracy,
    4
  )
  comparison$multinomial_lift_vs_frequency <- round(
    comparison$multinomial_accuracy - comparison$frequency_accuracy,
    4
  )

  comparison
}

save_multinomial_outputs <- function(
  prediction_dataset,
  summary,
  class_metrics,
  probability_bins,
  model_comparison,
  prediction_path = "outputs/prediction/stage1_multinomial_baseline_predictions.csv",
  summary_path = "outputs/prediction/stage1_multinomial_baseline_summary.csv",
  class_metrics_path = "outputs/prediction/stage1_multinomial_baseline_class_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_multinomial_baseline_probability_bins.csv",
  model_comparison_path = "outputs/prediction/stage1_model_baseline_comparison.csv"
) {
  output_dir <- dirname(prediction_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_dataset, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(model_comparison, model_comparison_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    summary_path = summary_path,
    class_metrics_path = class_metrics_path,
    probability_bins_path = probability_bins_path,
    model_comparison_path = model_comparison_path
  )
}

if (sys.nframe() == 0) {
  stage1_model_dataset <- load_stage1_model_dataset()
  split_info <- create_chronological_split(stage1_model_dataset)
  split_dataset <- prepare_multinomial_dataset(split_info$dataset)

  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]
  model <- train_multinomial_model(train_dataset)

  prediction_dataset <- predict_multinomial_baseline(model, split_dataset)
  summary <- create_multinomial_summary(prediction_dataset)
  class_metrics <- calculate_class_metrics(prediction_dataset)
  probability_bins <- calculate_probability_bins(prediction_dataset)
  model_comparison <- create_model_comparison(prediction_dataset)

  output_paths <- save_multinomial_outputs(
    prediction_dataset,
    summary,
    class_metrics,
    probability_bins,
    model_comparison
  )

  test_comparison <- model_comparison[model_comparison$validation_split == "test", ]

  message("Saved multinomial predictions to: ", output_paths$prediction_path)
  message("Saved multinomial summary to: ", output_paths$summary_path)
  message("Saved multinomial class metrics to: ", output_paths$class_metrics_path)
  message("Saved multinomial probability bins to: ", output_paths$probability_bins_path)
  message("Saved model baseline comparison to: ", output_paths$model_comparison_path)
  message("Test frequency accuracy: ", test_comparison$frequency_accuracy)
  message("Test multinomial accuracy: ", test_comparison$multinomial_accuracy)
  message("Test multinomial lift vs frequency: ", test_comparison$multinomial_lift_vs_frequency)
}
