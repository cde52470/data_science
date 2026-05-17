#!/usr/bin/env Rscript

# Train a controlled Random Forest model and calculate permutation importance.

load_tree_model_dataset <- function(
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

select_controlled_tree_features <- function(model_df) {
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
    stop("Missing tree model feature columns: ", paste(missing_columns, collapse = ", "))
  }

  model_df[, feature_columns]
}

train_random_forest_model <- function(model_df) {
  if (!requireNamespace("randomForest", quietly = TRUE)) {
    stop("Package 'randomForest' is required for this script.")
  }

  set.seed(2024)
  randomForest::randomForest(
    win ~ .,
    data = model_df,
    ntree = 500,
    importance = TRUE
  )
}

evaluate_tree_model <- function(model, model_df) {
  predicted_win <- predict(model, newdata = model_df, type = "class")
  predicted_probability <- as.numeric(predict(model, newdata = model_df, type = "prob")[, "win"])
  actual_win <- model_df$win

  confusion_matrix <- table(actual = actual_win, predicted = predicted_win)
  accuracy <- mean(predicted_win == actual_win)

  list(
    accuracy = accuracy,
    confusion_matrix = confusion_matrix,
    prediction_df = data.frame(
      actual_win = actual_win,
      predicted_win = predicted_win,
      predicted_probability = predicted_probability,
      stringsAsFactors = FALSE
    )
  )
}

calculate_permutation_importance <- function(model, model_df, target = "win") {
  if (!target %in% names(model_df)) {
    stop("Target column not found: ", target)
  }

  baseline_prediction <- predict(model, newdata = model_df, type = "class")
  baseline_accuracy <- mean(baseline_prediction == model_df[[target]])
  feature_columns <- setdiff(names(model_df), target)

  importance_rows <- vector("list", length(feature_columns))
  set.seed(2024)

  for (i in seq_along(feature_columns)) {
    feature <- feature_columns[i]
    permuted_df <- model_df
    permuted_df[[feature]] <- sample(permuted_df[[feature]])

    permuted_prediction <- predict(model, newdata = permuted_df, type = "class")
    permuted_accuracy <- mean(permuted_prediction == model_df[[target]])

    importance_rows[[i]] <- data.frame(
      feature = feature,
      baseline_accuracy = baseline_accuracy,
      permuted_accuracy = permuted_accuracy,
      importance = baseline_accuracy - permuted_accuracy,
      stringsAsFactors = FALSE
    )
  }

  importance_df <- do.call(rbind, importance_rows)
  importance_df[order(-importance_df$importance), ]
}

save_tree_model_outputs <- function(
  evaluation,
  permutation_importance,
  output_dir = "outputs/model_tree"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  performance <- data.frame(
    model = "random_forest_controlled",
    accuracy = evaluation$accuracy,
    stringsAsFactors = FALSE
  )

  write.csv(
    performance,
    file.path(output_dir, "random_forest_performance.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    evaluation$prediction_df,
    file.path(output_dir, "random_forest_predictions.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    permutation_importance,
    file.path(output_dir, "random_forest_permutation_importance.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  model_df <- load_tree_model_dataset()
  model_df <- select_controlled_tree_features(model_df)
  rf_model <- train_random_forest_model(model_df)
  evaluation <- evaluate_tree_model(rf_model, model_df)
  permutation_importance <- calculate_permutation_importance(rf_model, model_df)
  output_dir <- save_tree_model_outputs(evaluation, permutation_importance)

  message("Saved tree model outputs to: ", output_dir)
  message("Random Forest in-sample accuracy: ", round(evaluation$accuracy, 4))
}
