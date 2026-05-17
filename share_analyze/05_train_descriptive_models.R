#!/usr/bin/env Rscript

# Train first-pass descriptive logistic regression models for CPBL 2024 win/loss.
# These models use post-game features and are intended for explanation.

load_model_dataset <- function(
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

create_model_formulas <- function() {
  full_formula <- win ~ is_home +
    runs_scored + runs_allowed + run_diff +
    early_runs + middle_runs + late_runs +
    scored_first + led_after_3 + led_after_6 +
    AB + H + BB + SO + double + triple + HR +
    extra_base_hits + power_score + run_per_hit + offense_pressure_score +
    innings_pitched + hits_allowed + bb_allowed + hr_allowed + so_pitched +
    whip_like + strikeout_walk_ratio + run_prevention_score

  reduced_formula <- win ~ is_home +
    early_runs + middle_runs + late_runs +
    scored_first + led_after_3 + led_after_6 +
    AB + H + BB + SO + double + triple + HR +
    extra_base_hits + power_score + run_per_hit + offense_pressure_score +
    innings_pitched + hits_allowed + bb_allowed + hr_allowed + so_pitched +
    whip_like + strikeout_walk_ratio + run_prevention_score

  list(
    full = full_formula,
    reduced = reduced_formula,
    controlled = create_controlled_formula()
  )
}

create_controlled_formula <- function() {
  win ~ is_home +
    early_runs + middle_runs + late_runs +
    scored_first + led_after_3 +
    AB + H + BB + SO + double + triple + HR +
    extra_base_hits + power_score + run_per_hit +
    innings_pitched + hits_allowed + bb_allowed + hr_allowed + so_pitched +
    whip_like + strikeout_walk_ratio
}

train_logistic_models <- function(model_df, formulas) {
  list(
    full_model = glm(formulas$full, data = model_df, family = binomial()),
    reduced_model = glm(formulas$reduced, data = model_df, family = binomial()),
    controlled_model = glm(formulas$controlled, data = model_df, family = binomial())
  )
}

evaluate_logistic_model <- function(model, model_df) {
  predicted_probability <- as.numeric(predict(model, newdata = model_df, type = "response"))
  predicted_win <- factor(
    ifelse(predicted_probability >= 0.5, "win", "loss"),
    levels = c("loss", "win")
  )

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

extract_model_coefficients <- function(model) {
  coefficient_df <- as.data.frame(summary(model)$coefficients)
  coefficient_df$feature <- rownames(coefficient_df)
  rownames(coefficient_df) <- NULL

  names(coefficient_df) <- c("estimate", "std_error", "z_value", "p_value", "feature")
  coefficient_df$odds_ratio <- exp(coefficient_df$estimate)
  coefficient_df$direction <- ifelse(
    coefficient_df$estimate > 0,
    "提高勝率",
    ifelse(coefficient_df$estimate < 0, "降低勝率", "無方向")
  )

  coefficient_df <- coefficient_df[
    coefficient_df$feature != "(Intercept)",
    c("feature", "estimate", "std_error", "z_value", "p_value", "odds_ratio", "direction")
  ]
  coefficient_df[order(coefficient_df$p_value), ]
}

save_model_outputs <- function(results, output_dir = "outputs/model_descriptive") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  performance_summary <- data.frame(
    model = c("full", "reduced", "controlled"),
    accuracy = c(
      results$full$evaluation$accuracy,
      results$reduced$evaluation$accuracy,
      results$controlled$evaluation$accuracy
    ),
    stringsAsFactors = FALSE
  )

  write.csv(
    performance_summary,
    file.path(output_dir, "model_performance_summary.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    results$full$coefficients,
    file.path(output_dir, "full_model_coefficients.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    results$reduced$coefficients,
    file.path(output_dir, "reduced_model_coefficients.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    results$controlled$coefficients,
    file.path(output_dir, "controlled_model_coefficients.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    results$full$evaluation$prediction_df,
    file.path(output_dir, "full_model_predictions.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    results$reduced$evaluation$prediction_df,
    file.path(output_dir, "reduced_model_predictions.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  write.csv(
    results$controlled$evaluation$prediction_df,
    file.path(output_dir, "controlled_model_predictions.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  output_dir
}

if (sys.nframe() == 0) {
  model_df <- load_model_dataset()
  formulas <- create_model_formulas()
  models <- train_logistic_models(model_df, formulas)

  results <- list(
    full = list(
      model = models$full_model,
      evaluation = evaluate_logistic_model(models$full_model, model_df),
      coefficients = extract_model_coefficients(models$full_model)
    ),
    reduced = list(
      model = models$reduced_model,
      evaluation = evaluate_logistic_model(models$reduced_model, model_df),
      coefficients = extract_model_coefficients(models$reduced_model)
    ),
    controlled = list(
      model = models$controlled_model,
      evaluation = evaluate_logistic_model(models$controlled_model, model_df),
      coefficients = extract_model_coefficients(models$controlled_model)
    )
  )

  output_dir <- save_model_outputs(results)

  message("Saved descriptive model outputs to: ", output_dir)
  message("Full model accuracy: ", round(results$full$evaluation$accuracy, 4))
  message("Reduced model accuracy: ", round(results$reduced$evaluation$accuracy, 4))
  message("Controlled model accuracy: ", round(results$controlled$evaluation$accuracy, 4))
}
