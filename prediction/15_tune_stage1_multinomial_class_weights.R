#!/usr/bin/env Rscript

# Tune Stage 1 multinomial baseline with class/sample weights.
# Run from the project root:
# Rscript prediction/15_tune_stage1_multinomial_class_weights.R

source("prediction/13_train_stage1_multinomial_baseline.R")

get_weight_power_grid <- function() {
  c(0, 0.5, 0.75, 1.0)
}

format_weight_variant <- function(weight_power) {
  paste0("class_weight_power_", gsub("\\.", "_", sprintf("%.2f", weight_power)))
}

calculate_sample_weights <- function(train_dataset, weight_power) {
  target_counts <- table(train_dataset$stage1_target_momentum_state)
  target_proportions <- target_counts / sum(target_counts)

  class_weights <- (1 / target_proportions) ^ weight_power
  sample_weights <- as.numeric(class_weights[
    as.character(train_dataset$stage1_target_momentum_state)
  ])

  sample_weights / mean(sample_weights)
}

train_weighted_multinomial_model <- function(train_dataset, sample_weights) {
  feature_columns <- get_multinomial_feature_columns()
  formula_text <- paste(
    "stage1_target_momentum_state ~",
    paste(feature_columns, collapse = " + ")
  )

  nnet::multinom(
    formula = as.formula(formula_text),
    data = train_dataset,
    weights = sample_weights,
    trace = FALSE,
    MaxNWts = 20000,
    maxit = 300
  )
}

summarize_variant <- function(prediction_dataset, variant_name, weight_power) {
  class_metrics <- calculate_class_metrics(prediction_dataset)
  test_predictions <- prediction_dataset[
    prediction_dataset$validation_split == "test",
  ]
  test_class_metrics <- class_metrics[
    class_metrics$validation_split == "test",
  ]

  data.frame(
    variant_name = variant_name,
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

run_one_weight_variant <- function(split_dataset, weight_power) {
  variant_name <- format_weight_variant(weight_power)
  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]
  sample_weights <- calculate_sample_weights(train_dataset, weight_power)

  model <- train_weighted_multinomial_model(train_dataset, sample_weights)
  prediction_dataset <- predict_multinomial_baseline(model, split_dataset)
  prediction_dataset$weight_variant <- variant_name
  prediction_dataset$weight_power <- weight_power

  class_metrics <- calculate_class_metrics(prediction_dataset)
  class_metrics$weight_variant <- variant_name
  class_metrics$weight_power <- weight_power

  probability_bins <- calculate_probability_bins(prediction_dataset)
  probability_bins$weight_variant <- variant_name
  probability_bins$weight_power <- weight_power

  variant_summary <- summarize_variant(prediction_dataset, variant_name, weight_power)

  list(
    predictions = prediction_dataset,
    class_metrics = class_metrics,
    probability_bins = probability_bins,
    summary = variant_summary
  )
}

select_recommended_variant <- function(tuning_summary) {
  baseline <- tuning_summary[tuning_summary$weight_power == 0, ]
  candidates <- tuning_summary[tuning_summary$weight_power > 0, ]

  candidates$accuracy_drop_vs_baseline <- round(
    candidates$test_accuracy - baseline$test_accuracy,
    4
  )
  candidates$macro_f1_lift_vs_baseline <- round(
    candidates$test_macro_f1 - baseline$test_macro_f1,
    4
  )
  candidates$non_neutral_recall_average <- round(rowMeans(candidates[, c(
    "negative_recall",
    "positive_recall",
    "scoring_pressure_recall",
    "under_pressure_recall"
  )]), 4)

  viable <- candidates[candidates$accuracy_drop_vs_baseline >= -0.02, ]

  if (nrow(viable) == 0) {
    viable <- candidates
  }

  viable <- viable[order(
    -viable$test_macro_f1,
    -viable$non_neutral_recall_average,
    -viable$test_accuracy
  ), ]

  viable[1, ]
}

save_weight_tuning_outputs <- function(
  tuning_summary,
  class_metrics,
  probability_bins,
  recommended_variant,
  summary_path = "outputs/prediction/stage1_multinomial_class_weight_tuning_summary.csv",
  class_metrics_path = "outputs/prediction/stage1_multinomial_class_weight_tuning_class_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_multinomial_class_weight_tuning_probability_bins.csv",
  recommendation_path = "outputs/prediction/stage1_multinomial_class_weight_tuning_recommendation.csv"
) {
  output_dir <- dirname(summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(tuning_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommended_variant, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    summary_path = summary_path,
    class_metrics_path = class_metrics_path,
    probability_bins_path = probability_bins_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  stage1_model_dataset <- load_stage1_model_dataset()
  split_info <- create_chronological_split(stage1_model_dataset)
  split_dataset <- prepare_multinomial_dataset(split_info$dataset)

  tuning_results <- lapply(get_weight_power_grid(), function(weight_power) {
    run_one_weight_variant(split_dataset, weight_power)
  })

  tuning_summary <- do.call(rbind, lapply(tuning_results, function(result) {
    result$summary
  }))
  class_metrics <- do.call(rbind, lapply(tuning_results, function(result) {
    result$class_metrics
  }))
  probability_bins <- do.call(rbind, lapply(tuning_results, function(result) {
    result$probability_bins
  }))

  recommended_variant <- select_recommended_variant(tuning_summary)

  output_paths <- save_weight_tuning_outputs(
    tuning_summary,
    class_metrics,
    probability_bins,
    recommended_variant
  )

  message("Saved class weight tuning summary to: ", output_paths$summary_path)
  message("Saved class weight tuning class metrics to: ", output_paths$class_metrics_path)
  message("Saved class weight tuning probability bins to: ", output_paths$probability_bins_path)
  message("Saved class weight tuning recommendation to: ", output_paths$recommendation_path)
  message("Recommended variant: ", recommended_variant$variant_name)
  message("Recommended test accuracy: ", recommended_variant$test_accuracy)
  message("Recommended test macro F1: ", recommended_variant$test_macro_f1)
}
