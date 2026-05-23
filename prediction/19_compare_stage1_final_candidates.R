#!/usr/bin/env Rscript

# Compare final Stage 1 candidate models and recommend v1 defaults.
# Run from the project root:
# Rscript prediction/19_compare_stage1_final_candidates.R

load_csv <- function(input_path) {
  if (!file.exists(input_path)) {
    stop("Input file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

build_final_candidate_summary <- function() {
  frequency <- load_csv("outputs/prediction/stage1_frequency_baseline_majority_baseline_comparison.csv")
  weighted <- load_csv("outputs/prediction/stage1_multinomial_class_weight_tuning_summary.csv")
  calibration <- load_csv("outputs/prediction/stage1_weighted_multinomial_calibration_evaluation.csv")
  tree <- load_csv("outputs/prediction/stage1_tree_baseline_summary.csv")

  test_frequency <- frequency[frequency$validation_split == "test", ]
  weighted_100 <- weighted[weighted$variant_name == "class_weight_power_1_00", ]
  calibration_test <- calibration[calibration$calibration_split == "test", ]
  tree_unweighted <- tree[tree$variant_name == "random_forest_unweighted", ]

  final_summary <- data.frame(
    candidate = c(
      "frequency_baseline",
      "weighted_multinomial_class_weight_1_00",
      "calibrated_weighted_multinomial_class_weight_1_00",
      "random_forest_unweighted"
    ),
    model_family = c(
      "frequency",
      "weighted_multinomial",
      "weighted_multinomial_calibrated_confidence",
      "random_forest"
    ),
    test_accuracy = c(
      test_frequency$frequency_accuracy,
      weighted_100$test_accuracy,
      calibration_test$accuracy,
      tree_unweighted$test_accuracy
    ),
    test_macro_recall = c(
      NA,
      weighted_100$test_macro_recall,
      NA,
      tree_unweighted$test_macro_recall
    ),
    test_macro_f1 = c(
      NA,
      weighted_100$test_macro_f1,
      NA,
      tree_unweighted$test_macro_f1
    ),
    negative_recall = c(
      NA,
      weighted_100$negative_recall,
      NA,
      tree_unweighted$negative_recall
    ),
    positive_recall = c(
      NA,
      weighted_100$positive_recall,
      NA,
      tree_unweighted$positive_recall
    ),
    scoring_pressure_recall = c(
      NA,
      weighted_100$scoring_pressure_recall,
      NA,
      tree_unweighted$scoring_pressure_recall
    ),
    under_pressure_recall = c(
      NA,
      weighted_100$under_pressure_recall,
      NA,
      tree_unweighted$under_pressure_recall
    ),
    neutral_recall = c(
      NA,
      weighted_100$neutral_recall,
      NA,
      tree_unweighted$neutral_recall
    ),
    brier_score = c(
      NA,
      NA,
      calibration_test$calibrated_brier_score,
      NA
    ),
    note = c(
      "Most interpretable Markov-like baseline",
      "Best non-neutral and pressure recall",
      "Same weighted multinomial family with calibrated confidence",
      "Best accuracy and macro F1"
    ),
    stringsAsFactors = FALSE
  )

  final_summary$non_neutral_recall_average <- round(rowMeans(final_summary[, c(
    "negative_recall",
    "positive_recall",
    "scoring_pressure_recall",
    "under_pressure_recall"
  )], na.rm = TRUE), 4)

  final_summary[order(-final_summary$test_accuracy), ]
}

build_final_class_comparison <- function() {
  weighted <- load_csv("outputs/prediction/stage1_multinomial_class_weight_tuning_class_metrics.csv")
  tree <- load_csv("outputs/prediction/stage1_tree_baseline_class_metrics.csv")

  weighted_test <- weighted[
    weighted$validation_split == "test" &
      weighted$weight_variant == "class_weight_power_1_00",
  ]
  tree_test <- tree[
    tree$validation_split == "test" &
      tree$tree_variant == "random_forest_unweighted",
  ]

  weighted_keep <- weighted_test[, c(
    "class",
    "support",
    "precision",
    "recall",
    "f1_score"
  )]
  names(weighted_keep) <- c(
    "class",
    "support",
    "weighted_multinomial_precision",
    "weighted_multinomial_recall",
    "weighted_multinomial_f1"
  )

  tree_keep <- tree_test[, c(
    "class",
    "precision",
    "recall",
    "f1_score"
  )]
  names(tree_keep) <- c(
    "class",
    "random_forest_precision",
    "random_forest_recall",
    "random_forest_f1"
  )

  comparison <- merge(weighted_keep, tree_keep, by = "class", all = TRUE)
  comparison$recall_difference_rf_minus_weighted <- round(
    comparison$random_forest_recall - comparison$weighted_multinomial_recall,
    4
  )
  comparison$f1_difference_rf_minus_weighted <- round(
    comparison$random_forest_f1 - comparison$weighted_multinomial_f1,
    4
  )

  comparison[order(comparison$class), ]
}

build_final_recommendation <- function(final_summary) {
  random_forest <- final_summary[final_summary$candidate == "random_forest_unweighted", ]
  weighted <- final_summary[final_summary$candidate == "weighted_multinomial_class_weight_1_00", ]

  data.frame(
    item = c(
      "stage1_v1_default_model",
      "secondary_reference_model",
      "default_model_reason",
      "secondary_model_reason",
      "decision_rule",
      "next_step"
    ),
    value = c(
      "random_forest_unweighted",
      "weighted_multinomial_class_weight_1_00",
      paste0(
        "best test accuracy = ",
        random_forest$test_accuracy,
        "; best macro F1 = ",
        random_forest$test_macro_f1
      ),
      paste0(
        "better non-neutral recall average = ",
        weighted$non_neutral_recall_average,
        "; useful for pressure/turning-point sensitivity"
      ),
      "Use random forest as default prediction model, but report weighted multinomial as interpretability and recall-sensitive benchmark",
      "build Stage 1 v1 prediction output using random_forest_unweighted plus model comparison metadata"
    ),
    stringsAsFactors = FALSE
  )
}

save_final_candidate_outputs <- function(
  final_summary,
  class_comparison,
  recommendation,
  summary_path = "outputs/prediction/stage1_final_candidate_summary.csv",
  class_comparison_path = "outputs/prediction/stage1_final_candidate_class_comparison.csv",
  recommendation_path = "outputs/prediction/stage1_final_candidate_recommendation.csv"
) {
  output_dir <- dirname(summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(final_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_comparison, class_comparison_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    summary_path = summary_path,
    class_comparison_path = class_comparison_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  final_summary <- build_final_candidate_summary()
  class_comparison <- build_final_class_comparison()
  recommendation <- build_final_recommendation(final_summary)

  output_paths <- save_final_candidate_outputs(
    final_summary,
    class_comparison,
    recommendation
  )

  message("Saved final candidate summary to: ", output_paths$summary_path)
  message("Saved final candidate class comparison to: ", output_paths$class_comparison_path)
  message("Saved final candidate recommendation to: ", output_paths$recommendation_path)
  message("Stage 1 v1 default model: ", recommendation$value[
    recommendation$item == "stage1_v1_default_model"
  ])
}
