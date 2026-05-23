#!/usr/bin/env Rscript

# Compare Stage 1 majority, frequency, and multinomial baselines.
# Run from the project root:
# Rscript prediction/14_compare_stage1_baselines.R

load_csv <- function(input_path) {
  if (!file.exists(input_path)) {
    stop("Input file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_baseline_inputs <- function() {
  list(
    overall = load_csv("outputs/prediction/stage1_model_baseline_comparison.csv"),
    frequency_class = load_csv("outputs/prediction/stage1_frequency_baseline_class_metrics.csv"),
    multinomial_class = load_csv("outputs/prediction/stage1_multinomial_baseline_class_metrics.csv"),
    frequency_probability = load_csv("outputs/prediction/stage1_frequency_baseline_probability_bins.csv"),
    multinomial_probability = load_csv("outputs/prediction/stage1_multinomial_baseline_probability_bins.csv")
  )
}

build_class_metric_comparison <- function(frequency_class, multinomial_class) {
  frequency_keep <- frequency_class[, c(
    "validation_split",
    "class",
    "support",
    "precision",
    "recall",
    "f1_score"
  )]
  names(frequency_keep) <- c(
    "validation_split",
    "class",
    "support",
    "frequency_precision",
    "frequency_recall",
    "frequency_f1"
  )

  multinomial_keep <- multinomial_class[, c(
    "validation_split",
    "class",
    "precision",
    "recall",
    "f1_score"
  )]
  names(multinomial_keep) <- c(
    "validation_split",
    "class",
    "multinomial_precision",
    "multinomial_recall",
    "multinomial_f1"
  )

  comparison <- merge(
    frequency_keep,
    multinomial_keep,
    by = c("validation_split", "class"),
    all = TRUE,
    sort = FALSE
  )

  comparison$precision_change <- round(
    comparison$multinomial_precision - comparison$frequency_precision,
    4
  )
  comparison$recall_change <- round(
    comparison$multinomial_recall - comparison$frequency_recall,
    4
  )
  comparison$f1_change <- round(
    comparison$multinomial_f1 - comparison$frequency_f1,
    4
  )

  comparison[order(comparison$validation_split, comparison$class), ]
}

build_probability_bin_comparison <- function(frequency_probability, multinomial_probability) {
  frequency_keep <- frequency_probability[, c(
    "validation_split",
    "probability_bin",
    "total_count",
    "accuracy",
    "mean_predicted_probability"
  )]
  names(frequency_keep) <- c(
    "validation_split",
    "probability_bin",
    "frequency_total_count",
    "frequency_accuracy",
    "frequency_mean_predicted_probability"
  )

  multinomial_keep <- multinomial_probability[, c(
    "validation_split",
    "probability_bin",
    "total_count",
    "accuracy",
    "mean_predicted_probability"
  )]
  names(multinomial_keep) <- c(
    "validation_split",
    "probability_bin",
    "multinomial_total_count",
    "multinomial_accuracy",
    "multinomial_mean_predicted_probability"
  )

  comparison <- merge(
    frequency_keep,
    multinomial_keep,
    by = c("validation_split", "probability_bin"),
    all = TRUE,
    sort = FALSE
  )

  comparison$accuracy_change <- round(
    comparison$multinomial_accuracy - comparison$frequency_accuracy,
    4
  )
  comparison$mean_probability_change <- round(
    comparison$multinomial_mean_predicted_probability -
      comparison$frequency_mean_predicted_probability,
    4
  )

  comparison[order(comparison$validation_split, comparison$probability_bin), ]
}

build_baseline_recommendation <- function(overall, class_comparison) {
  test_overall <- overall[overall$validation_split == "test", ]
  test_classes <- class_comparison[class_comparison$validation_split == "test", ]

  scoring_pressure <- test_classes[test_classes$class == "scoring_pressure", ]
  under_pressure <- test_classes[test_classes$class == "under_pressure", ]
  negative_momentum <- test_classes[test_classes$class == "negative_momentum", ]
  positive_momentum <- test_classes[test_classes$class == "positive_momentum", ]

  data.frame(
    item = c(
      "overall_accuracy_winner",
      "important_pressure_signal",
      "weaker_recall_classes",
      "recommended_next_direction"
    ),
    value = c(
      ifelse(
        test_overall$multinomial_accuracy > test_overall$frequency_accuracy,
        "multinomial_baseline",
        "frequency_baseline"
      ),
      paste0(
        "scoring_pressure recall change = ",
        round(scoring_pressure$recall_change * 100, 2),
        " pp; under_pressure recall change = ",
        round(under_pressure$recall_change * 100, 2),
        " pp"
      ),
      paste0(
        "negative_momentum recall change = ",
        round(negative_momentum$recall_change * 100, 2),
        " pp; positive_momentum recall change = ",
        round(positive_momentum$recall_change * 100, 2),
        " pp"
      ),
      "try class weighting or tree-based model after documenting this comparison"
    ),
    stringsAsFactors = FALSE
  )
}

save_baseline_comparison_outputs <- function(
  overall,
  class_comparison,
  probability_comparison,
  recommendation,
  overall_path = "outputs/prediction/stage1_baseline_overall_comparison.csv",
  class_path = "outputs/prediction/stage1_baseline_class_metric_comparison.csv",
  probability_path = "outputs/prediction/stage1_baseline_probability_bin_comparison.csv",
  recommendation_path = "outputs/prediction/stage1_baseline_recommendation.csv"
) {
  output_dir <- dirname(overall_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(overall, overall_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_comparison, class_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_comparison, probability_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    overall_path = overall_path,
    class_path = class_path,
    probability_path = probability_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  inputs <- load_baseline_inputs()

  class_comparison <- build_class_metric_comparison(
    inputs$frequency_class,
    inputs$multinomial_class
  )
  probability_comparison <- build_probability_bin_comparison(
    inputs$frequency_probability,
    inputs$multinomial_probability
  )
  recommendation <- build_baseline_recommendation(
    inputs$overall,
    class_comparison
  )

  output_paths <- save_baseline_comparison_outputs(
    inputs$overall,
    class_comparison,
    probability_comparison,
    recommendation
  )

  test_overall <- inputs$overall[inputs$overall$validation_split == "test", ]

  message("Saved overall comparison to: ", output_paths$overall_path)
  message("Saved class metric comparison to: ", output_paths$class_path)
  message("Saved probability bin comparison to: ", output_paths$probability_path)
  message("Saved recommendation to: ", output_paths$recommendation_path)
  message("Test majority accuracy: ", test_overall$majority_accuracy)
  message("Test frequency accuracy: ", test_overall$frequency_accuracy)
  message("Test multinomial accuracy: ", test_overall$multinomial_accuracy)
}
