#!/usr/bin/env Rscript

# Visualize XGBoost interpretation results and compare model CV metrics.

load_xgboost_visual_data <- function(
  xgboost_dir = "outputs/model_xgboost"
) {
  paths <- list(
    cv_summary = file.path(xgboost_dir, "xgboost_cv_summary.csv"),
    feature_importance = file.path(xgboost_dir, "xgboost_feature_importance.csv"),
    shap_importance = file.path(xgboost_dir, "xgboost_shap_importance.csv")
  )

  missing_paths <- paths[!file.exists(unlist(paths))]
  if (length(missing_paths) > 0) {
    stop("Missing XGBoost result files: ", paste(unlist(missing_paths), collapse = ", "))
  }

  list(
    cv_summary = read.csv(paths$cv_summary, stringsAsFactors = FALSE),
    feature_importance = read.csv(paths$feature_importance, stringsAsFactors = FALSE),
    shap_importance = read.csv(paths$shap_importance, stringsAsFactors = FALSE)
  )
}

plot_xgboost_feature_importance <- function(
  feature_importance,
  output_path = "outputs/model_xgboost_visuals/xgboost_feature_importance_gain.png",
  top_n = 12
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw XGBoost visuals.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- feature_importance[order(-feature_importance$Gain), ]
  plot_df <- plot_df[seq_len(min(top_n, nrow(plot_df))), ]
  plot_df$Feature <- factor(plot_df$Feature, levels = rev(plot_df$Feature))

  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = Feature, y = Gain)
  ) +
    ggplot2::geom_col(width = 0.65, fill = "#2563EB") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "XGBoost Feature Importance by Gain",
      x = "特徵",
      y = "Gain"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 9, height = 6, dpi = 150)
  output_path
}

plot_xgboost_shap_importance <- function(
  shap_importance,
  output_path = "outputs/model_xgboost_visuals/xgboost_shap_importance.png",
  top_n = 12
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw XGBoost visuals.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- shap_importance[order(-shap_importance$mean_abs_shap), ]
  plot_df <- plot_df[seq_len(min(top_n, nrow(plot_df))), ]
  plot_df$feature <- factor(plot_df$feature, levels = rev(plot_df$feature))

  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = feature, y = mean_abs_shap)
  ) +
    ggplot2::geom_col(width = 0.65, fill = "#059669") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "XGBoost SHAP Mean Absolute Contribution",
      x = "特徵",
      y = "Mean absolute SHAP"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 9, height = 6, dpi = 150)
  output_path
}

build_model_cv_comparison <- function(
  logistic_path = "outputs/model_cv/controlled_logistic_cv_summary.csv",
  rf_path = "outputs/model_tree_cv/random_forest_cv_summary.csv",
  xgb_path = "outputs/model_xgboost/xgboost_cv_summary.csv"
) {
  paths <- c(logistic_path, rf_path, xgb_path)
  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0) {
    stop("Missing CV summary files: ", paste(missing_paths, collapse = ", "))
  }

  logistic_df <- read.csv(logistic_path, stringsAsFactors = FALSE)
  rf_df <- read.csv(rf_path, stringsAsFactors = FALSE)
  xgb_df <- read.csv(xgb_path, stringsAsFactors = FALSE)

  logistic_df$model <- "Controlled Logistic"
  rf_df$model <- "Random Forest"
  xgb_df$model <- "XGBoost"

  comparison_df <- rbind(logistic_df, rf_df, xgb_df)
  comparison_df <- comparison_df[, c("model", "metric", "mean", "sd")]
  comparison_df
}

plot_model_cv_comparison <- function(
  comparison_df,
  output_path = "outputs/model_comparison/model_cv_comparison.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw model comparison plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  comparison_df$model <- factor(
    comparison_df$model,
    levels = c("Controlled Logistic", "Random Forest", "XGBoost")
  )
  comparison_df$metric <- factor(
    comparison_df$metric,
    levels = c("accuracy", "sensitivity", "specificity", "precision", "f1")
  )

  p <- ggplot2::ggplot(
    comparison_df,
    ggplot2::aes(x = metric, y = mean, fill = model)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75), width = 0.65) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = mean - sd, ymax = mean + sd),
      position = ggplot2::position_dodge(width = 0.75),
      width = 0.18,
      linewidth = 0.45
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.05)) +
    ggplot2::labs(
      title = "5-Fold Cross-Validation Model Comparison",
      x = "評估指標",
      y = "平均表現",
      fill = "模型"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 10, height = 6, dpi = 150)
  output_path
}

save_model_comparison_outputs <- function(
  comparison_df,
  output_dir = "outputs/model_comparison"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(
    comparison_df,
    file.path(output_dir, "model_cv_comparison_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  xgboost_data <- load_xgboost_visual_data()

  xgb_gain_plot <- plot_xgboost_feature_importance(xgboost_data$feature_importance)
  xgb_shap_plot <- plot_xgboost_shap_importance(xgboost_data$shap_importance)

  comparison_df <- build_model_cv_comparison()
  save_model_comparison_outputs(comparison_df)
  comparison_plot <- plot_model_cv_comparison(comparison_df)

  message("Saved XGBoost Gain plot to: ", xgb_gain_plot)
  message("Saved XGBoost SHAP plot to: ", xgb_shap_plot)
  message("Saved model comparison outputs to: outputs/model_comparison")
  message("Saved model comparison plot to: ", comparison_plot)
}
