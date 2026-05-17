#!/usr/bin/env Rscript

# Add tuned XGBoost results to model comparison outputs.

load_model_comparison_inputs <- function(
  original_path = "outputs/model_comparison/model_cv_comparison_summary.csv",
  tuned_path = "outputs/model_xgboost_tuning/xgboost_tuning_best_params.csv"
) {
  paths <- c(original_path, tuned_path)
  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0) {
    stop("Missing comparison input files: ", paste(missing_paths, collapse = ", "))
  }

  list(
    original_comparison = read.csv(original_path, stringsAsFactors = FALSE),
    tuned_xgboost_best = read.csv(tuned_path, stringsAsFactors = FALSE)
  )
}

build_comparison_with_tuned_xgboost <- function(inputs) {
  original_df <- inputs$original_comparison
  original_df <- original_df[original_df$metric %in% c("accuracy", "f1"), ]

  tuned_best <- inputs$tuned_xgboost_best[1, ]
  tuned_df <- data.frame(
    model = c("Tuned XGBoost", "Tuned XGBoost"),
    metric = c("accuracy", "f1"),
    mean = c(tuned_best$mean_accuracy, tuned_best$mean_f1),
    sd = c(tuned_best$sd_accuracy, tuned_best$sd_f1),
    stringsAsFactors = FALSE
  )

  comparison_df <- rbind(original_df, tuned_df)
  comparison_df$model <- factor(
    comparison_df$model,
    levels = c("Controlled Logistic", "Random Forest", "XGBoost", "Tuned XGBoost")
  )
  comparison_df$metric <- factor(comparison_df$metric, levels = c("accuracy", "f1"))
  comparison_df
}

plot_comparison_with_tuned_xgboost <- function(
  comparison_df,
  output_path = "outputs/model_comparison/model_cv_comparison_with_tuned_xgboost.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw model comparison plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  p <- ggplot2::ggplot(
    comparison_df,
    ggplot2::aes(x = metric, y = mean, fill = model)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78), width = 0.68) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = mean - sd, ymax = mean + sd),
      position = ggplot2::position_dodge(width = 0.78),
      width = 0.16,
      linewidth = 0.45
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.05)) +
    ggplot2::labs(
      title = "Model CV Comparison with Tuned XGBoost",
      x = "評估指標",
      y = "平均表現",
      fill = "模型"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 10, height = 6, dpi = 150)
  output_path
}

save_comparison_with_tuned_xgboost <- function(
  comparison_df,
  output_dir = "outputs/model_comparison"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(
    comparison_df,
    file.path(output_dir, "model_cv_comparison_with_tuned_xgboost.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  inputs <- load_model_comparison_inputs()
  comparison_df <- build_comparison_with_tuned_xgboost(inputs)
  output_dir <- save_comparison_with_tuned_xgboost(comparison_df)
  plot_path <- plot_comparison_with_tuned_xgboost(comparison_df)

  message("Saved tuned model comparison outputs to: ", output_dir)
  message("Saved tuned model comparison plot to: ", plot_path)
}
