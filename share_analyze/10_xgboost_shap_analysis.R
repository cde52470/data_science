#!/usr/bin/env Rscript

# Train controlled XGBoost model, run cross-validation, and calculate SHAP importance.

load_xgboost_dataset <- function(
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

select_controlled_xgboost_features <- function(model_df) {
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
    stop("Missing XGBoost feature columns: ", paste(missing_columns, collapse = ", "))
  }

  model_df[, feature_columns]
}

prepare_xgboost_matrix <- function(model_df) {
  y <- ifelse(model_df$win == "win", 1, 0)
  x_df <- model_df[, setdiff(names(model_df), "win")]
  x <- model.matrix(~ . - 1, data = x_df)

  list(
    x = x,
    y = y,
    feature_names = colnames(x)
  )
}

train_xgboost_model <- function(xgb_data) {
  if (!requireNamespace("xgboost", quietly = TRUE)) {
    stop("Package 'xgboost' is required for this script.")
  }

  dtrain <- xgboost::xgb.DMatrix(data = xgb_data$x, label = xgb_data$y)

  params <- list(
    objective = "binary:logistic",
    eval_metric = "logloss",
    max_depth = 3,
    eta = 0.05,
    subsample = 0.8,
    colsample_bytree = 0.8
  )

  set.seed(2024)
  xgboost::xgb.train(
    params = params,
    data = dtrain,
    nrounds = 200,
    verbose = 0
  )
}

run_xgboost_cv <- function(xgb_data, k = 5, seed = 2024) {
  if (!requireNamespace("xgboost", quietly = TRUE)) {
    stop("Package 'xgboost' is required for this script.")
  }

  set.seed(seed)
  folds <- integer(length(xgb_data$y))
  for (class_label in c(0, 1)) {
    class_indices <- which(xgb_data$y == class_label)
    shuffled_indices <- sample(class_indices)
    folds[shuffled_indices] <- rep(seq_len(k), length.out = length(shuffled_indices))
  }

  params <- list(
    objective = "binary:logistic",
    eval_metric = "logloss",
    max_depth = 3,
    eta = 0.05,
    subsample = 0.8,
    colsample_bytree = 0.8
  )

  cv_rows <- vector("list", k)

  for (fold_id in seq_len(k)) {
    train_index <- folds != fold_id
    test_index <- folds == fold_id

    dtrain <- xgboost::xgb.DMatrix(data = xgb_data$x[train_index, ], label = xgb_data$y[train_index])
    model <- xgboost::xgb.train(
      params = params,
      data = dtrain,
      nrounds = 200,
      verbose = 0
    )

    predicted_probability <- as.numeric(predict(model, xgb_data$x[test_index, ]))
    predicted_win <- ifelse(predicted_probability >= 0.5, 1, 0)
    actual_win <- xgb_data$y[test_index]

    true_positive <- sum(actual_win == 1 & predicted_win == 1)
    true_negative <- sum(actual_win == 0 & predicted_win == 0)
    false_positive <- sum(actual_win == 0 & predicted_win == 1)
    false_negative <- sum(actual_win == 1 & predicted_win == 0)

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

    cv_rows[[fold_id]] <- data.frame(
      fold = fold_id,
      test_rows = sum(test_index),
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

calculate_xgboost_importance_and_shap <- function(model, xgb_data) {
  feature_importance <- xgboost::xgb.importance(
    feature_names = xgb_data$feature_names,
    model = model
  )

  shap_values <- predict(model, xgb_data$x, predcontrib = TRUE)
  shap_df <- as.data.frame(shap_values)
  shap_df$BIAS <- NULL

  shap_importance <- data.frame(
    feature = names(shap_df),
    mean_abs_shap = as.numeric(sapply(shap_df, function(column) mean(abs(column), na.rm = TRUE))),
    stringsAsFactors = FALSE
  )
  shap_importance <- shap_importance[order(-shap_importance$mean_abs_shap), ]

  list(
    feature_importance = as.data.frame(feature_importance),
    shap_importance = shap_importance
  )
}

save_xgboost_outputs <- function(
  cv_results,
  importance_results,
  output_dir = "outputs/model_xgboost"
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
    file.path(output_dir, "xgboost_cv_results.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    cv_summary,
    file.path(output_dir, "xgboost_cv_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    importance_results$feature_importance,
    file.path(output_dir, "xgboost_feature_importance.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    importance_results$shap_importance,
    file.path(output_dir, "xgboost_shap_importance.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  model_df <- load_xgboost_dataset()
  model_df <- select_controlled_xgboost_features(model_df)
  xgb_data <- prepare_xgboost_matrix(model_df)

  xgb_model <- train_xgboost_model(xgb_data)
  cv_results <- run_xgboost_cv(xgb_data, k = 5, seed = 2024)
  importance_results <- calculate_xgboost_importance_and_shap(xgb_model, xgb_data)
  output_dir <- save_xgboost_outputs(cv_results, importance_results)

  message("Saved XGBoost outputs to: ", output_dir)
  message("Mean accuracy: ", round(mean(cv_results$accuracy, na.rm = TRUE), 4))
  message("Mean F1: ", round(mean(cv_results$f1, na.rm = TRUE), 4))
}
