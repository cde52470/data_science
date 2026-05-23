#!/usr/bin/env Rscript

# Tune Stage 1 inning-scoring probability thresholds.
# Run from the project root:
# Rscript prediction/35_tune_stage1_inning_scoring_threshold.R

source("prediction/34_train_stage1_inning_scoring_baseline.R")

load_stage1_scoring_logistic_predictions <- function(
  input_path = "outputs/prediction/stage1_inning_scoring_logistic_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 inning-scoring logistic predictions not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_stage1_scoring_frequency_predictions <- function(
  input_path = "outputs/prediction/stage1_inning_scoring_frequency_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 inning-scoring frequency predictions not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_stage1_scoring_threshold_candidates <- function() {
  c(0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50)
}

evaluate_one_scoring_threshold <- function(
  prediction_dataset,
  model_name,
  probability_column,
  threshold
) {
  threshold_dataset <- prediction_dataset
  predicted_column <- paste0("predicted_will_score_at_", gsub("\\.", "_", threshold))
  threshold_dataset[[predicted_column]] <- as.integer(
    threshold_dataset[[probability_column]] >= threshold
  )

  metrics <- calculate_scoring_binary_metrics(
    threshold_dataset,
    model_name = model_name,
    probability_column = probability_column,
    predicted_column = predicted_column,
    threshold = threshold
  )

  metrics
}

evaluate_scoring_thresholds <- function(
  prediction_dataset,
  model_name,
  probability_column,
  thresholds = get_stage1_scoring_threshold_candidates()
) {
  do.call(rbind, lapply(thresholds, function(threshold) {
    evaluate_one_scoring_threshold(
      prediction_dataset = prediction_dataset,
      model_name = model_name,
      probability_column = probability_column,
      threshold = threshold
    )
  }))
}

select_stage1_scoring_threshold_recommendation <- function(threshold_metrics) {
  test_metrics <- threshold_metrics[
    threshold_metrics$validation_split == "test",
  ]

  logistic_metrics <- test_metrics[
    test_metrics$model_name == "logistic_regression",
  ]

  logistic_metrics$balanced_score <- round(
    ifelse(
      is.na(logistic_metrics$precision) | is.na(logistic_metrics$recall),
      NA_real_,
      sqrt(logistic_metrics$precision * logistic_metrics$recall)
    ),
    4
  )

  recommended <- logistic_metrics[order(
    -logistic_metrics$f1_score,
    -logistic_metrics$balanced_score,
    -logistic_metrics$recall,
    logistic_metrics$threshold
  ), ][1, ]
  recommended$decision_reason <- paste(
    "logistic_regression_selected",
    "maximize_test_f1_then_precision_recall_balance",
    "threshold_for_binary_high_scoring_chance_flag",
    sep = "__"
  )

  recommended
}

label_scoring_chance_state <- function(
  scoring_probability,
  low_threshold = 0.20,
  high_threshold = 0.35
) {
  ifelse(
    scoring_probability < low_threshold,
    "low_scoring_chance",
    ifelse(
      scoring_probability < high_threshold,
      "medium_scoring_chance",
      "high_scoring_chance"
    )
  )
}

build_stage1_scoring_chance_state_output <- function(
  logistic_predictions,
  low_threshold = 0.20,
  high_threshold = 0.35
) {
  required_columns <- c(
    "game_id",
    "date",
    "inning",
    "half_inning",
    "batting_team",
    "fielding_team",
    "pa_order",
    "batter_name",
    "pitcher_name",
    "current_base_out_state",
    "before_score_state",
    "before_momentum_state",
    "score_diff_before",
    "run_expectancy_before",
    "will_score_from_current_pa",
    "logistic_scoring_probability",
    "validation_split"
  )
  assert_required_columns(logistic_predictions, required_columns)

  state_output <- logistic_predictions[, required_columns]
  state_output$scoring_chance_state <- label_scoring_chance_state(
    state_output$logistic_scoring_probability,
    low_threshold = low_threshold,
    high_threshold = high_threshold
  )
  state_output$scoring_chance_state_zh <- ifelse(
    state_output$scoring_chance_state == "low_scoring_chance",
    "低得分機會",
    ifelse(
      state_output$scoring_chance_state == "medium_scoring_chance",
      "普通得分機會",
      "高得分機會"
    )
  )

  state_output
}

summarize_scoring_chance_state <- function(state_output) {
  summary_values <- aggregate(
    cbind(
      actual_scoring_rate = state_output$will_score_from_current_pa,
      mean_predicted_probability = state_output$logistic_scoring_probability
    ),
    by = list(
      validation_split = state_output$validation_split,
      scoring_chance_state = state_output$scoring_chance_state
    ),
    FUN = mean
  )
  summary_values$actual_scoring_rate <- round(summary_values$actual_scoring_rate, 6)
  summary_values$mean_predicted_probability <- round(
    summary_values$mean_predicted_probability,
    6
  )

  row_counts <- as.data.frame(table(
    state_output$validation_split,
    state_output$scoring_chance_state
  ), stringsAsFactors = FALSE)
  names(row_counts) <- c("validation_split", "scoring_chance_state", "row_count")
  row_counts <- row_counts[row_counts$row_count > 0, ]

  state_summary <- merge(
    row_counts,
    summary_values,
    by = c("validation_split", "scoring_chance_state"),
    all.x = TRUE,
    sort = FALSE
  )

  state_summary[order(
    state_summary$validation_split,
    state_summary$scoring_chance_state
  ), ]
}

save_stage1_scoring_threshold_outputs <- function(
  threshold_metrics,
  recommendation,
  scoring_chance_output,
  scoring_chance_summary,
  threshold_metrics_path = "outputs/prediction/stage1_inning_scoring_threshold_tuning_metrics.csv",
  recommendation_path = "outputs/prediction/stage1_inning_scoring_threshold_recommendation.csv",
  scoring_chance_output_path = "outputs/prediction/stage1_inning_scoring_chance_state_output.csv",
  scoring_chance_summary_path = "outputs/prediction/stage1_inning_scoring_chance_state_summary.csv"
) {
  output_dir <- dirname(threshold_metrics_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(threshold_metrics, threshold_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(scoring_chance_output, scoring_chance_output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(scoring_chance_summary, scoring_chance_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    threshold_metrics_path = threshold_metrics_path,
    recommendation_path = recommendation_path,
    scoring_chance_output_path = scoring_chance_output_path,
    scoring_chance_summary_path = scoring_chance_summary_path
  )
}

if (sys.nframe() == 0) {
  logistic_predictions <- load_stage1_scoring_logistic_predictions()
  frequency_predictions <- load_stage1_scoring_frequency_predictions()

  threshold_metrics <- rbind(
    evaluate_scoring_thresholds(
      logistic_predictions,
      model_name = "logistic_regression",
      probability_column = "logistic_scoring_probability"
    ),
    evaluate_scoring_thresholds(
      frequency_predictions,
      model_name = "context_frequency",
      probability_column = "frequency_scoring_probability"
    )
  )

  recommendation <- select_stage1_scoring_threshold_recommendation(
    threshold_metrics
  )

  scoring_chance_output <- build_stage1_scoring_chance_state_output(
    logistic_predictions,
    low_threshold = 0.20,
    high_threshold = 0.35
  )
  scoring_chance_summary <- summarize_scoring_chance_state(scoring_chance_output)

  output_paths <- save_stage1_scoring_threshold_outputs(
    threshold_metrics,
    recommendation,
    scoring_chance_output,
    scoring_chance_summary
  )

  message("Saved Stage 1 scoring threshold metrics to: ", output_paths$threshold_metrics_path)
  message("Saved Stage 1 scoring threshold recommendation to: ", output_paths$recommendation_path)
  message("Saved Stage 1 scoring chance state output to: ", output_paths$scoring_chance_output_path)
  message("Saved Stage 1 scoring chance state summary to: ", output_paths$scoring_chance_summary_path)
}
