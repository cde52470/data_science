#!/usr/bin/env Rscript

# Train Stage 1 tree-based baselines with random forest.
# Run from the project root:
# Rscript prediction/18_train_stage1_tree_baseline.R

source("prediction/13_train_stage1_multinomial_baseline.R")
source("prediction/15_tune_stage1_multinomial_class_weights.R")

if (!requireNamespace("randomForest", quietly = TRUE)) {
  stop("Required R package not installed: randomForest")
}

get_tree_feature_columns <- function() {
  get_multinomial_feature_columns()
}

prepare_tree_dataset <- function(stage1_model_dataset) {
  feature_columns <- get_tree_feature_columns()
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

get_tree_variant_specs <- function() {
  list(
    list(
      variant_name = "random_forest_unweighted",
      weight_power = 0,
      ntree = 300
    ),
    list(
      variant_name = "random_forest_class_weight_1_00",
      weight_power = 1,
      ntree = 300
    )
  )
}

calculate_class_weights <- function(train_dataset, weight_power) {
  if (weight_power == 0) {
    return(NULL)
  }

  target_counts <- table(train_dataset$stage1_target_momentum_state)
  target_proportions <- target_counts / sum(target_counts)
  class_weights <- (1 / target_proportions) ^ weight_power
  class_weights <- class_weights / mean(class_weights)
  class_weights
}

train_random_forest_model <- function(train_dataset, spec) {
  feature_columns <- get_tree_feature_columns()
  formula_text <- paste(
    "stage1_target_momentum_state ~",
    paste(feature_columns, collapse = " + ")
  )

  class_weights <- calculate_class_weights(train_dataset, spec$weight_power)

  randomForest::randomForest(
    formula = as.formula(formula_text),
    data = train_dataset,
    ntree = spec$ntree,
    classwt = class_weights,
    importance = TRUE
  )
}

predict_tree_baseline <- function(model, prediction_dataset) {
  probability_matrix <- predict(model, newdata = prediction_dataset, type = "prob")
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
      prediction_dataset$stage1_target_momentum_state
  )

  prediction_dataset
}

summarize_tree_variant <- function(prediction_dataset, variant_name, weight_power) {
  class_metrics <- calculate_class_metrics(prediction_dataset)
  test_predictions <- prediction_dataset[
    prediction_dataset$validation_split == "test",
  ]
  test_class_metrics <- class_metrics[
    class_metrics$validation_split == "test",
  ]

  data.frame(
    variant_name = variant_name,
    model_family = "random_forest",
    weight_power = weight_power,
    test_accuracy = round(mean(test_predictions$is_correct_prediction), 4),
    test_macro_recall = round(mean(test_class_metrics$recall, na.rm = TRUE), 4),
    test_macro_f1 = round(mean(test_class_metrics$f1_score, na.rm = TRUE), 4),
    negative_recall = test_class_metrics$recall[
      test_class_metrics$class == "negative_momentum"
    ],
    positive_recall = test_class_metrics$recall[
      test_class_metrics$class == "positive_momentum"
    ],
    scoring_pressure_recall = test_class_metrics$recall[
      test_class_metrics$class == "scoring_pressure"
    ],
    under_pressure_recall = test_class_metrics$recall[
      test_class_metrics$class == "under_pressure"
    ],
    neutral_recall = test_class_metrics$recall[
      test_class_metrics$class == "neutral_momentum"
    ],
    stringsAsFactors = FALSE
  )
}

run_one_tree_variant <- function(split_dataset, spec) {
  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]
  model <- train_random_forest_model(train_dataset, spec)
  prediction_dataset <- predict_tree_baseline(model, split_dataset)
  prediction_dataset$tree_variant <- spec$variant_name
  prediction_dataset$weight_power <- spec$weight_power

  class_metrics <- calculate_class_metrics(prediction_dataset)
  class_metrics$tree_variant <- spec$variant_name
  class_metrics$weight_power <- spec$weight_power

  probability_bins <- calculate_probability_bins(prediction_dataset)
  probability_bins$tree_variant <- spec$variant_name
  probability_bins$weight_power <- spec$weight_power

  summary <- summarize_tree_variant(
    prediction_dataset,
    spec$variant_name,
    spec$weight_power
  )

  list(
    predictions = prediction_dataset,
    class_metrics = class_metrics,
    probability_bins = probability_bins,
    summary = summary
  )
}

select_tree_recommendation <- function(tree_summary) {
  tree_summary$non_neutral_recall_average <- round(rowMeans(tree_summary[, c(
    "negative_recall",
    "positive_recall",
    "scoring_pressure_recall",
    "under_pressure_recall"
  )]), 4)

  tree_summary <- tree_summary[order(
    -tree_summary$test_macro_f1,
    -tree_summary$non_neutral_recall_average,
    -tree_summary$test_accuracy
  ), ]

  tree_summary[1, ]
}

save_tree_baseline_outputs <- function(
  tree_summary,
  class_metrics,
  probability_bins,
  recommendation,
  summary_path = "outputs/prediction/stage1_tree_baseline_summary.csv",
  class_metrics_path = "outputs/prediction/stage1_tree_baseline_class_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_tree_baseline_probability_bins.csv",
  recommendation_path = "outputs/prediction/stage1_tree_baseline_recommendation.csv"
) {
  output_dir <- dirname(summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(tree_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    summary_path = summary_path,
    class_metrics_path = class_metrics_path,
    probability_bins_path = probability_bins_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  set.seed(20260522)

  stage1_model_dataset <- load_stage1_model_dataset()
  split_info <- create_chronological_split(stage1_model_dataset)
  split_dataset <- prepare_tree_dataset(split_info$dataset)

  tree_results <- lapply(get_tree_variant_specs(), function(spec) {
    run_one_tree_variant(split_dataset, spec)
  })

  tree_summary <- do.call(rbind, lapply(tree_results, function(result) {
    result$summary
  }))
  class_metrics <- do.call(rbind, lapply(tree_results, function(result) {
    result$class_metrics
  }))
  probability_bins <- do.call(rbind, lapply(tree_results, function(result) {
    result$probability_bins
  }))
  recommendation <- select_tree_recommendation(tree_summary)

  output_paths <- save_tree_baseline_outputs(
    tree_summary,
    class_metrics,
    probability_bins,
    recommendation
  )

  message("Saved tree baseline summary to: ", output_paths$summary_path)
  message("Saved tree baseline class metrics to: ", output_paths$class_metrics_path)
  message("Saved tree baseline probability bins to: ", output_paths$probability_bins_path)
  message("Saved tree baseline recommendation to: ", output_paths$recommendation_path)
  message("Recommended tree variant: ", recommendation$variant_name)
  message("Recommended test accuracy: ", recommendation$test_accuracy)
  message("Recommended test macro F1: ", recommendation$test_macro_f1)
}
