#!/usr/bin/env Rscript

# Cross-validation for the controlled descriptive logistic model.

load_cv_model_dataset <- function(
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

create_controlled_cv_formula <- function() {
  win ~ is_home +
    early_runs + middle_runs + late_runs +
    scored_first + led_after_3 +
    AB + H + BB + SO + double + triple + HR +
    extra_base_hits + power_score + run_per_hit +
    innings_pitched + hits_allowed + bb_allowed + hr_allowed + so_pitched +
    whip_like + strikeout_walk_ratio
}

make_cv_folds <- function(model_df, k = 5, seed = 2024) {
  set.seed(seed)
  folds <- integer(nrow(model_df))

  for (class_label in levels(model_df$win)) {
    class_indices <- which(model_df$win == class_label)
    shuffled_indices <- sample(class_indices)
    folds[shuffled_indices] <- rep(seq_len(k), length.out = length(shuffled_indices))
  }

  folds
}

run_logistic_cv <- function(model_df, formula, folds) {
  fold_ids <- sort(unique(folds))
  cv_rows <- vector("list", length(fold_ids))

  for (i in seq_along(fold_ids)) {
    fold_id <- fold_ids[i]
    train_df <- model_df[folds != fold_id, ]
    test_df <- model_df[folds == fold_id, ]

    model <- glm(formula, data = train_df, family = binomial())
    predicted_probability <- as.numeric(predict(model, newdata = test_df, type = "response"))
    predicted_win <- factor(
      ifelse(predicted_probability >= 0.5, "win", "loss"),
      levels = c("loss", "win")
    )
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

save_cv_outputs <- function(cv_results, output_dir = "outputs/model_cv") {
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
    file.path(output_dir, "controlled_logistic_cv_results.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    cv_summary,
    file.path(output_dir, "controlled_logistic_cv_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  model_df <- load_cv_model_dataset()
  formula <- create_controlled_cv_formula()
  folds <- make_cv_folds(model_df, k = 5, seed = 2024)
  cv_results <- run_logistic_cv(model_df, formula, folds)
  output_dir <- save_cv_outputs(cv_results)

  message("Saved cross-validation outputs to: ", output_dir)
  message("Mean accuracy: ", round(mean(cv_results$accuracy, na.rm = TRUE), 4))
  message("Mean F1: ", round(mean(cv_results$f1, na.rm = TRUE), 4))
}
