#!/usr/bin/env Rscript

# Compare Stage 1 tuned model candidates.
# Run from the project root:
# Rscript prediction/16_compare_stage1_tuned_models.R

load_csv <- function(input_path) {
  if (!file.exists(input_path)) {
    stop("Input file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

build_tuned_overall_comparison <- function() {
  baseline_overall <- load_csv("outputs/prediction/stage1_baseline_overall_comparison.csv")
  class_weight_summary <- load_csv("outputs/prediction/stage1_multinomial_class_weight_tuning_summary.csv")

  test_baseline <- baseline_overall[baseline_overall$validation_split == "test", ]

  base_rows <- data.frame(
    model_name = c(
      "majority_baseline",
      "frequency_baseline",
      "multinomial_baseline"
    ),
    model_family = c(
      "majority",
      "frequency",
      "multinomial"
    ),
    test_accuracy = c(
      test_baseline$majority_accuracy,
      test_baseline$frequency_accuracy,
      test_baseline$multinomial_accuracy
    ),
    test_macro_recall = c(NA, NA, class_weight_summary$test_macro_recall[
      class_weight_summary$weight_power == 0
    ]),
    test_macro_f1 = c(NA, NA, class_weight_summary$test_macro_f1[
      class_weight_summary$weight_power == 0
    ]),
    negative_recall = c(NA, NA, class_weight_summary$negative_recall[
      class_weight_summary$weight_power == 0
    ]),
    positive_recall = c(NA, NA, class_weight_summary$positive_recall[
      class_weight_summary$weight_power == 0
    ]),
    scoring_pressure_recall = c(NA, NA, class_weight_summary$scoring_pressure_recall[
      class_weight_summary$weight_power == 0
    ]),
    under_pressure_recall = c(NA, NA, class_weight_summary$under_pressure_recall[
      class_weight_summary$weight_power == 0
    ]),
    neutral_recall = c(NA, NA, class_weight_summary$neutral_recall[
      class_weight_summary$weight_power == 0
    ]),
    stringsAsFactors = FALSE
  )

  weighted_rows <- class_weight_summary[class_weight_summary$weight_power > 0, ]
  weighted_rows <- data.frame(
    model_name = weighted_rows$variant_name,
    model_family = "weighted_multinomial",
    test_accuracy = weighted_rows$test_accuracy,
    test_macro_recall = weighted_rows$test_macro_recall,
    test_macro_f1 = weighted_rows$test_macro_f1,
    negative_recall = weighted_rows$negative_recall,
    positive_recall = weighted_rows$positive_recall,
    scoring_pressure_recall = weighted_rows$scoring_pressure_recall,
    under_pressure_recall = weighted_rows$under_pressure_recall,
    neutral_recall = weighted_rows$neutral_recall,
    stringsAsFactors = FALSE
  )

  comparison <- rbind(base_rows, weighted_rows)
  comparison$non_neutral_recall_average <- round(rowMeans(comparison[, c(
    "negative_recall",
    "positive_recall",
    "scoring_pressure_recall",
    "under_pressure_recall"
  )], na.rm = TRUE), 4)

  comparison$accuracy_lift_vs_frequency <- round(
    comparison$test_accuracy - test_baseline$frequency_accuracy,
    4
  )
  comparison$accuracy_lift_vs_multinomial <- round(
    comparison$test_accuracy - test_baseline$multinomial_accuracy,
    4
  )

  comparison[order(
    -comparison$test_macro_f1,
    -comparison$test_accuracy
  ), ]
}

build_tuned_recommendation <- function(tuned_comparison) {
  candidates <- tuned_comparison[!is.na(tuned_comparison$test_macro_f1), ]
  recommended <- candidates[order(
    -candidates$test_macro_f1,
    -candidates$non_neutral_recall_average,
    -candidates$test_accuracy
  ), ][1, ]

  data.frame(
    item = c(
      "recommended_model",
      "selection_reason",
      "test_accuracy",
      "test_macro_recall",
      "test_macro_f1",
      "non_neutral_recall_average",
      "next_step"
    ),
    value = c(
      recommended$model_name,
      "highest macro F1 with improved non-neutral recall while keeping accuracy above original multinomial",
      recommended$test_accuracy,
      recommended$test_macro_recall,
      recommended$test_macro_f1,
      recommended$non_neutral_recall_average,
      "compare probability calibration or try tree-based baseline"
    ),
    stringsAsFactors = FALSE
  )
}

save_tuned_model_comparison <- function(
  tuned_comparison,
  tuned_recommendation,
  comparison_path = "outputs/prediction/stage1_tuned_model_comparison.csv",
  recommendation_path = "outputs/prediction/stage1_tuned_model_recommendation.csv"
) {
  output_dir <- dirname(comparison_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(tuned_comparison, comparison_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(tuned_recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    comparison_path = comparison_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  tuned_comparison <- build_tuned_overall_comparison()
  tuned_recommendation <- build_tuned_recommendation(tuned_comparison)

  output_paths <- save_tuned_model_comparison(
    tuned_comparison,
    tuned_recommendation
  )

  message("Saved tuned model comparison to: ", output_paths$comparison_path)
  message("Saved tuned model recommendation to: ", output_paths$recommendation_path)
  message("Recommended model: ", tuned_recommendation$value[
    tuned_recommendation$item == "recommended_model"
  ])
}
