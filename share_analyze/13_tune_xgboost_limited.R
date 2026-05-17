#!/usr/bin/env Rscript

# Limited hyperparameter tuning for controlled XGBoost model.

load_tuning_dataset <- function(
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

select_tuning_features <- function(model_df) {
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
    stop("Missing tuning feature columns: ", paste(missing_columns, collapse = ", "))
  }

  model_df[, feature_columns]
}

prepare_tuning_matrix <- function(model_df) {
  y <- ifelse(model_df$win == "win", 1, 0)
  x_df <- model_df[, setdiff(names(model_df), "win")]
  x <- model.matrix(~ . - 1, data = x_df)

  list(
    x = x,
    y = y,
    feature_names = colnames(x)
  )
}

build_limited_xgboost_grid <- function() {
  expand.grid(
    max_depth = c(2, 3, 4),
    eta = c(0.03, 0.05, 0.1),
    subsample = c(0.8, 1.0),
    colsample_bytree = c(0.8, 1.0),
    nrounds = c(100, 200),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
}

run_limited_xgboost_tuning <- function(xgb_data, grid, k = 5, seed = 2024) {
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

  tuning_rows <- vector("list", nrow(grid))

  for (i in seq_len(nrow(grid))) {
    params <- list(
      objective = "binary:logistic",
      eval_metric = "logloss",
      max_depth = grid$max_depth[i],
      eta = grid$eta[i],
      subsample = grid$subsample[i],
      colsample_bytree = grid$colsample_bytree[i]
    )

    fold_accuracy <- numeric(k)
    fold_f1 <- numeric(k)

    for (fold_id in seq_len(k)) {
      train_index <- folds != fold_id
      test_index <- folds == fold_id

      dtrain <- xgboost::xgb.DMatrix(data = xgb_data$x[train_index, ], label = xgb_data$y[train_index])
      model <- xgboost::xgb.train(
        params = params,
        data = dtrain,
        nrounds = grid$nrounds[i],
        verbose = 0
      )

      predicted_probability <- as.numeric(predict(model, xgb_data$x[test_index, ]))
      predicted_win <- ifelse(predicted_probability >= 0.5, 1, 0)
      actual_win <- xgb_data$y[test_index]

      true_positive <- sum(actual_win == 1 & predicted_win == 1)
      false_positive <- sum(actual_win == 0 & predicted_win == 1)
      false_negative <- sum(actual_win == 1 & predicted_win == 0)

      precision <- ifelse(
        true_positive + false_positive > 0,
        true_positive / (true_positive + false_positive),
        NA
      )
      sensitivity <- ifelse(
        true_positive + false_negative > 0,
        true_positive / (true_positive + false_negative),
        NA
      )
      f1 <- ifelse(
        !is.na(precision) && !is.na(sensitivity) && precision + sensitivity > 0,
        2 * precision * sensitivity / (precision + sensitivity),
        NA
      )

      fold_accuracy[fold_id] <- mean(predicted_win == actual_win)
      fold_f1[fold_id] <- f1
    }

    tuning_rows[[i]] <- data.frame(
      max_depth = grid$max_depth[i],
      eta = grid$eta[i],
      subsample = grid$subsample[i],
      colsample_bytree = grid$colsample_bytree[i],
      nrounds = grid$nrounds[i],
      mean_accuracy = mean(fold_accuracy, na.rm = TRUE),
      sd_accuracy = sd(fold_accuracy, na.rm = TRUE),
      mean_f1 = mean(fold_f1, na.rm = TRUE),
      sd_f1 = sd(fold_f1, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }

  tuning_results <- do.call(rbind, tuning_rows)
  tuning_results[order(-tuning_results$mean_f1, -tuning_results$mean_accuracy), ]
}

save_tuning_outputs <- function(
  tuning_results,
  output_dir = "outputs/model_xgboost_tuning"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  best_params <- tuning_results[1, ]

  write.csv(
    tuning_results,
    file.path(output_dir, "xgboost_tuning_results.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    best_params,
    file.path(output_dir, "xgboost_tuning_best_params.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  model_df <- load_tuning_dataset()
  model_df <- select_tuning_features(model_df)
  xgb_data <- prepare_tuning_matrix(model_df)
  grid <- build_limited_xgboost_grid()
  tuning_results <- run_limited_xgboost_tuning(xgb_data, grid, k = 5, seed = 2024)
  output_dir <- save_tuning_outputs(tuning_results)

  message("Saved XGBoost tuning outputs to: ", output_dir)
  message("Best mean accuracy: ", round(tuning_results$mean_accuracy[1], 4))
  message("Best mean F1: ", round(tuning_results$mean_f1[1], 4))
}
