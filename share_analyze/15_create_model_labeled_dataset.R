#!/usr/bin/env Rscript

# Merge controlled logistic predictions back into the full team-game dataset.

load_labeling_inputs <- function(
  feature_path = "data/cleaned/team_game_features.csv",
  prediction_path = "outputs/model_descriptive/controlled_model_predictions.csv"
) {
  paths <- c(feature_path, prediction_path)
  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0) {
    stop("Missing labeling input files: ", paste(missing_paths, collapse = ", "))
  }

  list(
    team_game_features = read.csv(feature_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM"),
    model_predictions = read.csv(prediction_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
  )
}

validate_labeling_inputs <- function(inputs) {
  feature_rows <- nrow(inputs$team_game_features)
  prediction_rows <- nrow(inputs$model_predictions)

  if (feature_rows != prediction_rows) {
    stop(
      "Row count mismatch: team_game_features has ",
      feature_rows,
      " rows, but model_predictions has ",
      prediction_rows,
      " rows."
    )
  }

  TRUE
}

add_model_labels <- function(team_game_features, model_predictions) {
  labeled_df <- team_game_features

  labeled_df$model_predicted_result <- model_predictions$predicted_win
  labeled_df$model_win_probability <- model_predictions$predicted_probability
  labeled_df$model_confidence_label <- ifelse(
    labeled_df$model_win_probability >= 0.75 | labeled_df$model_win_probability <= 0.25,
    "高信心",
    ifelse(
      (labeled_df$model_win_probability >= 0.60 & labeled_df$model_win_probability < 0.75) |
        (labeled_df$model_win_probability > 0.25 & labeled_df$model_win_probability <= 0.40),
      "中信心",
      "低信心"
    )
  )
  labeled_df$model_correct <- model_predictions$actual_win == model_predictions$predicted_win

  labeled_df$model_prediction_type <- ifelse(
    model_predictions$predicted_win == "win" & model_predictions$actual_win == "win",
    "模型判斷勝且實際勝",
    ifelse(
      model_predictions$predicted_win == "loss" & model_predictions$actual_win == "loss",
      "模型判斷敗且實際敗",
      ifelse(
        model_predictions$predicted_win == "win" & model_predictions$actual_win == "loss",
        "模型判斷勝但實際敗",
        "模型判斷敗但實際勝"
      )
    )
  )

  labeled_df
}

summarize_model_labels <- function(labeled_df) {
  confidence_summary <- as.data.frame(table(labeled_df$model_confidence_label), stringsAsFactors = FALSE)
  names(confidence_summary) <- c("model_confidence_label", "count")
  confidence_summary$proportion <- confidence_summary$count / sum(confidence_summary$count)

  prediction_type_summary <- as.data.frame(table(labeled_df$model_prediction_type), stringsAsFactors = FALSE)
  names(prediction_type_summary) <- c("model_prediction_type", "count")
  prediction_type_summary$proportion <- prediction_type_summary$count / sum(prediction_type_summary$count)

  list(
    confidence_summary = confidence_summary,
    prediction_type_summary = prediction_type_summary
  )
}

save_labeled_dataset <- function(
  labeled_df,
  summaries,
  output_path = "data/cleaned/team_game_model_labeled.csv",
  summary_dir = "outputs/model_labeling"
) {
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE)
  }

  write.csv(labeled_df, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(
    summaries$confidence_summary,
    file.path(summary_dir, "model_confidence_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    summaries$prediction_type_summary,
    file.path(summary_dir, "model_prediction_type_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_path
}

if (sys.nframe() == 0) {
  inputs <- load_labeling_inputs()
  validate_labeling_inputs(inputs)

  labeled_df <- add_model_labels(inputs$team_game_features, inputs$model_predictions)
  summaries <- summarize_model_labels(labeled_df)
  output_path <- save_labeled_dataset(labeled_df, summaries)

  message("Saved model-labeled dataset to: ", output_path)
  message("Rows: ", nrow(labeled_df))
  message("Columns: ", ncol(labeled_df))
}
