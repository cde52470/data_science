#!/usr/bin/env Rscript

# Build cross-model feature importance consensus across Logistic, RF, XGBoost Gain, and SHAP.

load_importance_sources <- function(
  logistic_path = "outputs/model_descriptive/controlled_model_coefficients.csv",
  rf_path = "outputs/model_tree/random_forest_permutation_importance.csv",
  xgb_gain_path = "outputs/model_xgboost/xgboost_feature_importance.csv",
  xgb_shap_path = "outputs/model_xgboost/xgboost_shap_importance.csv"
) {
  paths <- c(logistic_path, rf_path, xgb_gain_path, xgb_shap_path)
  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0) {
    stop("Missing importance source files: ", paste(missing_paths, collapse = ", "))
  }

  list(
    logistic_coefficients = read.csv(logistic_path, stringsAsFactors = FALSE),
    rf_importance = read.csv(rf_path, stringsAsFactors = FALSE),
    xgb_gain = read.csv(xgb_gain_path, stringsAsFactors = FALSE),
    xgb_shap = read.csv(xgb_shap_path, stringsAsFactors = FALSE)
  )
}

standardize_feature_names <- function(importance_df, feature_column) {
  if (!feature_column %in% names(importance_df)) {
    stop("Feature column not found: ", feature_column)
  }

  importance_df$standard_feature <- importance_df[[feature_column]]
  importance_df$standard_feature <- sub("yes$", "", importance_df$standard_feature)
  importance_df$standard_feature <- sub("home$", "", importance_df$standard_feature)
  importance_df$standard_feature <- sub("away$", "", importance_df$standard_feature)
  importance_df$standard_feature <- sub("^is_home$", "is_home", importance_df$standard_feature)
  importance_df$standard_feature <- sub("^scored_first$", "scored_first", importance_df$standard_feature)
  importance_df$standard_feature <- sub("^led_after_3$", "led_after_3", importance_df$standard_feature)
  importance_df$standard_feature <- sub("^\\(Intercept\\)$", "intercept", importance_df$standard_feature)

  importance_df
}

classify_feature_domain <- function(feature) {
  if (feature %in% c("is_home")) {
    return("主客場因素")
  }

  if (feature %in% c("early_runs", "middle_runs", "late_runs", "scored_first", "led_after_3")) {
    return("得分節奏")
  }

  if (feature %in% c(
    "AB", "H", "BB", "SO", "double", "triple", "HR",
    "extra_base_hits", "power_score", "run_per_hit"
  )) {
    return("進攻效率")
  }

  if (feature %in% c(
    "innings_pitched", "hits_allowed", "bb_allowed", "hr_allowed",
    "so_pitched", "whip_like", "strikeout_walk_ratio"
  )) {
    return("防守/投手效率")
  }

  "其他"
}

build_consensus_rank_table <- function(sources) {
  logistic_df <- standardize_feature_names(sources$logistic_coefficients, "feature")
  logistic_df$importance_value <- abs(logistic_df$estimate)
  logistic_df$model_source <- "Logistic coefficient"
  logistic_rank <- logistic_df[, c("standard_feature", "model_source", "importance_value")]

  rf_df <- standardize_feature_names(sources$rf_importance, "feature")
  rf_df$importance_value <- rf_df$importance
  rf_df$model_source <- "Random Forest permutation"
  rf_rank <- rf_df[, c("standard_feature", "model_source", "importance_value")]

  xgb_gain_df <- standardize_feature_names(sources$xgb_gain, "Feature")
  xgb_gain_df$importance_value <- xgb_gain_df$Gain
  xgb_gain_df$model_source <- "XGBoost Gain"
  xgb_gain_rank <- xgb_gain_df[, c("standard_feature", "model_source", "importance_value")]

  xgb_shap_df <- standardize_feature_names(sources$xgb_shap, "feature")
  xgb_shap_df <- xgb_shap_df[xgb_shap_df$standard_feature != "intercept", ]
  xgb_shap_df$importance_value <- xgb_shap_df$mean_abs_shap
  xgb_shap_df$model_source <- "XGBoost SHAP"
  xgb_shap_rank <- xgb_shap_df[, c("standard_feature", "model_source", "importance_value")]

  long_df <- rbind(logistic_rank, rf_rank, xgb_gain_rank, xgb_shap_rank)
  long_df <- long_df[!is.na(long_df$importance_value), ]

  rank_rows <- lapply(split(long_df, long_df$model_source), function(model_df) {
    model_df <- model_df[order(-model_df$importance_value), ]
    model_df$rank <- seq_len(nrow(model_df))
    model_df
  })
  ranked_long_df <- do.call(rbind, rank_rows)

  features <- sort(unique(ranked_long_df$standard_feature))
  consensus_rows <- lapply(features, function(feature) {
    feature_df <- ranked_long_df[ranked_long_df$standard_feature == feature, ]
    model_count <- length(unique(feature_df$model_source))
    avg_rank <- mean(feature_df$rank, na.rm = TRUE)
    best_rank <- min(feature_df$rank, na.rm = TRUE)
    consensus_score <- model_count / avg_rank

    data.frame(
      feature = feature,
      domain = classify_feature_domain(feature),
      model_count = model_count,
      avg_rank = avg_rank,
      best_rank = best_rank,
      consensus_score = consensus_score,
      sources = paste(sort(unique(feature_df$model_source)), collapse = "; "),
      stringsAsFactors = FALSE
    )
  })

  consensus_df <- do.call(rbind, consensus_rows)
  consensus_df <- consensus_df[order(-consensus_df$consensus_score, consensus_df$avg_rank), ]
  rownames(consensus_df) <- NULL
  consensus_df
}

plot_consensus_importance <- function(
  consensus_df,
  output_path = "outputs/feature_importance_consensus/feature_importance_consensus.png",
  top_n = 12
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw consensus importance plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- consensus_df[seq_len(min(top_n, nrow(consensus_df))), ]
  plot_df$feature <- factor(plot_df$feature, levels = rev(plot_df$feature))

  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = feature, y = consensus_score, fill = domain)
  ) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Cross-Model Feature Importance Consensus",
      x = "特徵",
      y = "Consensus score",
      fill = "分析面向"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(output_path, p, width = 9, height = 6, dpi = 150)
  output_path
}

save_consensus_outputs <- function(
  consensus_df,
  output_dir = "outputs/feature_importance_consensus"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(
    consensus_df,
    file.path(output_dir, "feature_importance_consensus.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  sources <- load_importance_sources()
  consensus_df <- build_consensus_rank_table(sources)
  output_dir <- save_consensus_outputs(consensus_df)
  plot_path <- plot_consensus_importance(consensus_df)

  message("Saved consensus outputs to: ", output_dir)
  message("Saved consensus plot to: ", plot_path)
}
