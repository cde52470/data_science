#!/usr/bin/env Rscript

# Visualize descriptive model and cross-validation results.

load_model_result_files <- function(
  descriptive_dir = "outputs/model_descriptive",
  cv_dir = "outputs/model_cv"
) {
  paths <- list(
    performance_summary = file.path(descriptive_dir, "model_performance_summary.csv"),
    controlled_coefficients = file.path(descriptive_dir, "controlled_model_coefficients.csv"),
    controlled_predictions = file.path(descriptive_dir, "controlled_model_predictions.csv"),
    cv_summary = file.path(cv_dir, "controlled_logistic_cv_summary.csv"),
    cv_results = file.path(cv_dir, "controlled_logistic_cv_results.csv")
  )

  missing_paths <- paths[!file.exists(unlist(paths))]
  if (length(missing_paths) > 0) {
    stop("Missing model result files: ", paste(unlist(missing_paths), collapse = ", "))
  }

  list(
    performance_summary = read.csv(paths$performance_summary, stringsAsFactors = FALSE),
    controlled_coefficients = read.csv(paths$controlled_coefficients, stringsAsFactors = FALSE),
    controlled_predictions = read.csv(paths$controlled_predictions, stringsAsFactors = FALSE),
    cv_summary = read.csv(paths$cv_summary, stringsAsFactors = FALSE),
    cv_results = read.csv(paths$cv_results, stringsAsFactors = FALSE)
  )
}

plot_model_accuracy_comparison <- function(
  performance_summary,
  output_path = "outputs/model_visuals/model_accuracy_comparison.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw model visuals.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  performance_summary$model <- factor(
    performance_summary$model,
    levels = c("full", "reduced", "controlled")
  )

  p <- ggplot2::ggplot(
    performance_summary,
    ggplot2::aes(x = model, y = accuracy, fill = model)
  ) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(accuracy, accuracy = 0.1)),
      vjust = -0.35,
      size = 4
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.08)) +
    ggplot2::labs(
      title = "Descriptive Model Accuracy Comparison",
      x = "模型版本",
      y = "In-sample accuracy"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.minor = ggplot2::element_blank()
    )

  ggplot2::ggsave(output_path, p, width = 8, height = 5, dpi = 150)
  output_path
}

plot_cv_metrics <- function(
  cv_summary,
  output_path = "outputs/model_visuals/controlled_cv_metrics.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw model visuals.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  cv_summary$metric <- factor(
    cv_summary$metric,
    levels = c("accuracy", "sensitivity", "specificity", "precision", "f1")
  )

  p <- ggplot2::ggplot(
    cv_summary,
    ggplot2::aes(x = metric, y = mean, fill = metric)
  ) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = mean - sd, ymax = mean + sd),
      width = 0.18,
      linewidth = 0.5
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(mean, accuracy = 0.1)),
      vjust = -0.45,
      size = 4
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.08)) +
    ggplot2::labs(
      title = "Controlled Logistic Model 5-Fold CV Metrics",
      x = "評估指標",
      y = "平均表現"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.minor = ggplot2::element_blank()
    )

  ggplot2::ggsave(output_path, p, width = 8, height = 5, dpi = 150)
  output_path
}

plot_controlled_coefficients <- function(
  controlled_coefficients,
  output_path = "outputs/model_visuals/controlled_model_top_coefficients.png",
  top_n = 12
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw model visuals.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- controlled_coefficients[order(controlled_coefficients$p_value), ]
  plot_df <- plot_df[seq_len(min(top_n, nrow(plot_df))), ]
  plot_df$feature <- factor(plot_df$feature, levels = rev(plot_df$feature))
  plot_df$effect_direction <- ifelse(plot_df$estimate >= 0, "提高勝率", "降低勝率")

  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = feature, y = estimate, fill = effect_direction)
  ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray45", linewidth = 0.4) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Controlled Model Top Logistic Coefficients",
      x = "特徵",
      y = "係數估計值",
      fill = "方向"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 9, height = 6, dpi = 150)
  output_path
}

plot_prediction_probability_distribution <- function(
  controlled_predictions,
  output_path = "outputs/model_visuals/controlled_prediction_probability_distribution.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw model visuals.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  controlled_predictions$actual_win <- factor(
    controlled_predictions$actual_win,
    levels = c("loss", "win")
  )

  p <- ggplot2::ggplot(
    controlled_predictions,
    ggplot2::aes(x = predicted_probability, fill = actual_win)
  ) +
    ggplot2::geom_histogram(position = "identity", bins = 30, alpha = 0.65) +
    ggplot2::geom_vline(xintercept = 0.5, color = "gray20", linetype = "dashed", linewidth = 0.5) +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::coord_cartesian(xlim = c(0, 1)) +
    ggplot2::labs(
      title = "Controlled Model Predicted Win Probability Distribution",
      x = "預測勝率",
      y = "場數",
      fill = "實際結果"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 8, height = 5, dpi = 150)
  output_path
}

if (sys.nframe() == 0) {
  result_files <- load_model_result_files()

  paths <- c(
    plot_model_accuracy_comparison(result_files$performance_summary),
    plot_cv_metrics(result_files$cv_summary),
    plot_controlled_coefficients(result_files$controlled_coefficients),
    plot_prediction_probability_distribution(result_files$controlled_predictions)
  )

  for (path in paths) {
    message("Saved plot to: ", path)
  }
}
