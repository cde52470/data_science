#!/usr/bin/env Rscript

# Cross-validation and visualization for controlled Random Forest models.

load_tree_cv_dataset <- function(
  path = "data/cleaned/model_dataset_win.csv"
) {
  if (!file.exists(path)) {
    stop("Model dataset file not found: ", path)
  }

  model_df <- read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
  model_df$win <- factor(model_df$win, levels = c("loss", "win"))
  model_df$is_home <- factor(model_df$is_home, levels = c("away", "home"))
  model_df$scored_first <- factor(model_df$scored_first, levels = c("no", "yes"))
  model_df$led_after_3 <- factor(model_df$led_after_3, levels = c("no", "yes"))
  model_df$led_after_6 <- factor(model_df$led_after_6, levels = c("no", "yes"))
  model_df
}

select_controlled_tree_cv_features <- function(model_df) {
  feature_columns <- c(
    "win",
    "is_home",
    "early_runs",
    "middle_runs",
    "late_runs",
    "scored_first",
    "led_after_3",
    "AB",
    "H",
    "BB",
    "SO",
    "double",
    "triple",
    "HR",
    "extra_base_hits",
    "power_score",
    "run_per_hit",
    "innings_pitched",
    "hits_allowed",
    "bb_allowed",
    "hr_allowed",
    "so_pitched",
    "whip_like",
    "strikeout_walk_ratio"
  )

  missing_columns <- setdiff(feature_columns, names(model_df))
  if (length(missing_columns) > 0) {
    stop("Missing tree CV feature columns: ", paste(missing_columns, collapse = ", "))
  }

  model_df[, feature_columns]
}

make_tree_cv_folds <- function(model_df, k = 5, seed = 2024) {
  set.seed(seed)
  folds <- integer(nrow(model_df))

  for (class_label in levels(model_df$win)) {
    class_indices <- which(model_df$win == class_label)
    shuffled_indices <- sample(class_indices)
    folds[shuffled_indices] <- rep(seq_len(k), length.out = length(shuffled_indices))
  }

  folds
}

run_random_forest_cv <- function(model_df, folds) {
  if (!requireNamespace("randomForest", quietly = TRUE)) {
    stop("Package 'randomForest' is required for this script.")
  }

  fold_ids <- sort(unique(folds))
  cv_rows <- vector("list", length(fold_ids))
  set.seed(2024)

  for (i in seq_along(fold_ids)) {
    fold_id <- fold_ids[i]
    train_df <- model_df[folds != fold_id, ]
    test_df <- model_df[folds == fold_id, ]

    model <- randomForest::randomForest(
      win ~ .,
      data = train_df,
      ntree = 500,
      importance = TRUE
    )

    predicted_win <- predict(model, newdata = test_df, type = "class")
    actual_win <- test_df$win

    true_positive <- sum(actual_win == "win" & predicted_win == "win")
    true_negative <- sum(actual_win == "loss" & predicted_win == "loss")
    false_positive <- sum(actual_win == "loss" & predicted_win == "win")
    false_negative <- sum(actual_win == "win" & predicted_win == "loss")

    accuracy <- mean(predicted_win == actual_win)
    sensitivity <- ifelse(
      true_positive + false_negative > 0,
      true_positive / (true_positive + false_negative),
      NA
    )
    specificity <- ifelse(
      true_negative + false_positive > 0,
      true_negative / (true_negative + false_positive),
      NA
    )
    precision <- ifelse(
      true_positive + false_positive > 0,
      true_positive / (true_positive + false_positive),
      NA
    )
    f1 <- ifelse(
      !is.na(precision) && !is.na(sensitivity) && precision + sensitivity > 0,
      2 * precision * sensitivity / (precision + sensitivity),
      NA
    )

    cv_rows[[i]] <- data.frame(
      fold = fold_id,
      test_rows = nrow(test_df),
      accuracy = accuracy,
      sensitivity = sensitivity,
      specificity = specificity,
      precision = precision,
      f1 = f1,
      true_positive = true_positive,
      true_negative = true_negative,
      false_positive = false_positive,
      false_negative = false_negative,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, cv_rows)
}

plot_rf_permutation_importance <- function(
  importance_df,
  output_path = "outputs/model_tree_cv/random_forest_permutation_importance.png",
  top_n = 12
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw Random Forest importance plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- importance_df[order(-importance_df$importance), ]
  plot_df <- plot_df[seq_len(min(top_n, nrow(plot_df))), ]
  plot_df$feature <- factor(plot_df$feature, levels = rev(plot_df$feature))

  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = feature, y = importance)
  ) +
    ggplot2::geom_col(width = 0.65, fill = "#3B82F6") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Random Forest Permutation Importance",
      x = "特徵",
      y = "Accuracy drop after permutation"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 9, height = 6, dpi = 150)
  output_path
}

save_tree_cv_outputs <- function(
  cv_results,
  importance_plot_path,
  output_dir = "outputs/model_tree_cv"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  cv_summary <- data.frame(
    metric = c("accuracy", "sensitivity", "specificity", "precision", "f1"),
    mean = c(
      mean(cv_results$accuracy, na.rm = TRUE),
      mean(cv_results$sensitivity, na.rm = TRUE),
      mean(cv_results$specificity, na.rm = TRUE),
      mean(cv_results$precision, na.rm = TRUE),
      mean(cv_results$f1, na.rm = TRUE)
    ),
    sd = c(
      sd(cv_results$accuracy, na.rm = TRUE),
      sd(cv_results$sensitivity, na.rm = TRUE),
      sd(cv_results$specificity, na.rm = TRUE),
      sd(cv_results$precision, na.rm = TRUE),
      sd(cv_results$f1, na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
  )

  write.csv(
    cv_results,
    file.path(output_dir, "random_forest_cv_results.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    cv_summary,
    file.path(output_dir, "random_forest_cv_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  data.frame(
    output_dir = output_dir,
    importance_plot_path = importance_plot_path,
    stringsAsFactors = FALSE
  )
}

if (sys.nframe() == 0) {
  model_df <- load_tree_cv_dataset()
  model_df <- select_controlled_tree_cv_features(model_df)
  folds <- make_tree_cv_folds(model_df, k = 5, seed = 2024)
  cv_results <- run_random_forest_cv(model_df, folds)

  importance_path <- "outputs/model_tree/random_forest_permutation_importance.csv"
  if (!file.exists(importance_path)) {
    stop("Permutation importance file not found: ", importance_path)
  }
  importance_df <- read.csv(importance_path, stringsAsFactors = FALSE)
  importance_plot_path <- plot_rf_permutation_importance(importance_df)

  save_tree_cv_outputs(cv_results, importance_plot_path)

  message("Saved Random Forest CV outputs to: outputs/model_tree_cv")
  message("Saved importance plot to: ", importance_plot_path)
  message("Mean accuracy: ", round(mean(cv_results$accuracy, na.rm = TRUE), 4))
  message("Mean F1: ", round(mean(cv_results$f1, na.rm = TRUE), 4))
}
