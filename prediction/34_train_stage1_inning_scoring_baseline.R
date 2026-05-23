#!/usr/bin/env Rscript

# Train Stage 1 inning-scoring probability baselines.
# Run from the project root:
# Rscript prediction/34_train_stage1_inning_scoring_baseline.R

source("prediction/11_validate_stage1_frequency_baseline.R")
source("prediction/33_build_stage1_inning_scoring_dataset.R")

load_stage1_inning_scoring_model_dataset <- function(
  input_path = "data/cleaned/stage1_inning_scoring_model_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 inning-scoring model dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_stage1_inning_scoring_feature_columns <- function() {
  c(
    "before_score_state",
    "before_momentum_state",
    "before_event_signal",
    "current_base_out_state",
    "inning",
    "half_inning",
    "is_home_batting",
    "outs_before",
    "bases_before",
    "base_occupancy_before",
    "score_diff_before",
    "batting_score_before",
    "fielding_score_before",
    "run_expectancy_before",
    "batter_primary_type",
    "batter_sample_size_tier",
    "batter_contact_score",
    "batter_power_score",
    "batter_discipline_score",
    "batter_risk_score",
    "batter_run_value_score",
    "pitcher_primary_type",
    "pitcher_sample_size_tier",
    "pitcher_strikeout_score",
    "pitcher_control_score",
    "pitcher_suppression_score",
    "pitcher_power_risk_score",
    "pitcher_run_prevention_score"
  )
}

prepare_stage1_inning_scoring_dataset <- function(model_dataset) {
  feature_columns <- get_stage1_inning_scoring_feature_columns()
  required_columns <- c(
    "will_score_from_current_pa",
    "validation_split",
    "game_date",
    feature_columns
  )
  assert_required_columns(model_dataset, required_columns)

  categorical_columns <- c(
    "before_score_state",
    "before_momentum_state",
    "before_event_signal",
    "current_base_out_state",
    "half_inning",
    "is_home_batting",
    "base_occupancy_before",
    "batter_primary_type",
    "batter_sample_size_tier",
    "pitcher_primary_type",
    "pitcher_sample_size_tier"
  )

  prepared_dataset <- model_dataset
  prepared_dataset$will_score_from_current_pa <- as.integer(
    prepared_dataset$will_score_from_current_pa
  )
  prepared_dataset$will_score_from_current_pa_factor <- factor(
    prepared_dataset$will_score_from_current_pa,
    levels = c(0, 1)
  )

  for (column_name in categorical_columns) {
    prepared_dataset[[column_name]] <- factor(prepared_dataset[[column_name]])
  }

  prepared_dataset
}

calculate_scoring_binary_metrics <- function(
  prediction_dataset,
  model_name,
  probability_column,
  predicted_column,
  threshold = 0.5
) {
  do.call(rbind, lapply(
    sort(unique(prediction_dataset$validation_split)),
    function(split_name) {
      split_data <- prediction_dataset[
        prediction_dataset$validation_split == split_name,
      ]
      actual <- as.integer(split_data$will_score_from_current_pa)
      predicted <- as.integer(split_data[[predicted_column]])
      probability <- pmin(pmax(split_data[[probability_column]], 1e-6), 1 - 1e-6)

      true_positive <- sum(actual == 1 & predicted == 1, na.rm = TRUE)
      false_positive <- sum(actual == 0 & predicted == 1, na.rm = TRUE)
      false_negative <- sum(actual == 1 & predicted == 0, na.rm = TRUE)
      true_negative <- sum(actual == 0 & predicted == 0, na.rm = TRUE)

      precision <- ifelse(
        true_positive + false_positive == 0,
        NA_real_,
        true_positive / (true_positive + false_positive)
      )
      recall <- ifelse(
        true_positive + false_negative == 0,
        NA_real_,
        true_positive / (true_positive + false_negative)
      )
      specificity <- ifelse(
        true_negative + false_positive == 0,
        NA_real_,
        true_negative / (true_negative + false_positive)
      )
      f1_score <- ifelse(
        is.na(precision) | is.na(recall) | precision + recall == 0,
        NA_real_,
        2 * precision * recall / (precision + recall)
      )

      data.frame(
        model_name = model_name,
        validation_split = split_name,
        row_count = nrow(split_data),
        threshold = threshold,
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 4),
        precision = round(precision, 4),
        recall = round(recall, 4),
        specificity = round(specificity, 4),
        f1_score = round(f1_score, 4),
        brier_score = round(mean((probability - actual) ^ 2, na.rm = TRUE), 4),
        log_loss = round(mean(
          -(actual * log(probability) + (1 - actual) * log(1 - probability)),
          na.rm = TRUE
        ), 4),
        positive_rate = round(mean(actual == 1, na.rm = TRUE), 4),
        predicted_positive_rate = round(mean(predicted == 1, na.rm = TRUE), 4),
        stringsAsFactors = FALSE
      )
    }
  ))
}

build_scoring_majority_baseline <- function(split_dataset, threshold = 0.5) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  train_positive_rate <- mean(train_data$will_score_from_current_pa)

  predictions <- split_dataset
  predictions$majority_scoring_probability <- train_positive_rate
  predictions$majority_predicted_will_score <- as.integer(
    train_positive_rate >= threshold
  )

  metrics <- calculate_scoring_binary_metrics(
    predictions,
    model_name = "majority_baseline",
    probability_column = "majority_scoring_probability",
    predicted_column = "majority_predicted_will_score",
    threshold = threshold
  )

  list(predictions = predictions, metrics = metrics)
}

get_scoring_frequency_specs <- function() {
  list(
    list(
      model_name = "full_context_frequency",
      group_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_group_total = 50
    ),
    list(
      model_name = "baseout_player_type_frequency",
      group_columns = c(
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_group_total = 50
    ),
    list(
      model_name = "score_baseout_frequency",
      group_columns = c(
        "before_score_state",
        "current_base_out_state"
      ),
      minimum_group_total = 30
    ),
    list(
      model_name = "baseout_frequency",
      group_columns = c("current_base_out_state"),
      minimum_group_total = 1
    )
  )
}

make_scoring_context_key <- function(dataset, group_columns) {
  assert_required_columns(dataset, group_columns)
  apply(dataset[, group_columns, drop = FALSE], 1, paste, collapse = "||")
}

build_one_scoring_frequency_table <- function(train_data, spec) {
  group_columns <- spec$group_columns
  required_columns <- c(group_columns, "will_score_from_current_pa")
  assert_required_columns(train_data, required_columns)

  group_summary <- aggregate(
    train_data$will_score_from_current_pa,
    by = train_data[, group_columns, drop = FALSE],
    FUN = mean
  )
  names(group_summary)[ncol(group_summary)] <- "scoring_probability"

  group_counts <- aggregate(
    rep(1, nrow(train_data)),
    by = train_data[, group_columns, drop = FALSE],
    FUN = sum
  )
  names(group_counts)[ncol(group_counts)] <- "group_total"

  frequency_table <- merge(
    group_summary,
    group_counts,
    by = group_columns,
    all.x = TRUE,
    sort = FALSE
  )
  frequency_table$model_name <- spec$model_name
  frequency_table$group_columns <- paste(group_columns, collapse = " + ")
  frequency_table$scoring_probability <- round(
    frequency_table$scoring_probability,
    6
  )

  frequency_table <- frequency_table[order(
    frequency_table$model_name,
    -frequency_table$group_total,
    -frequency_table$scoring_probability
  ), ]

  frequency_table
}

build_all_scoring_frequency_tables <- function(train_data) {
  tables <- lapply(get_scoring_frequency_specs(), function(spec) {
    build_one_scoring_frequency_table(train_data, spec)
  })

  all_columns <- unique(unlist(lapply(tables, names)))
  aligned_tables <- lapply(tables, function(table_item) {
    missing_columns <- setdiff(all_columns, names(table_item))
    for (column_name in missing_columns) {
      table_item[[column_name]] <- NA
    }
    table_item[, all_columns]
  })

  do.call(rbind, aligned_tables)
}

prepare_scoring_frequency_lookup <- function(frequency_table, spec) {
  group_columns <- spec$group_columns
  required_columns <- c(
    "model_name",
    group_columns,
    "scoring_probability",
    "group_total"
  )
  assert_required_columns(frequency_table, required_columns)

  lookup <- frequency_table[
    frequency_table$model_name == spec$model_name &
      frequency_table$group_total >= spec$minimum_group_total,
    required_columns
  ]
  lookup$context_key <- make_scoring_context_key(lookup, group_columns)
  lookup <- lookup[, c("context_key", "scoring_probability", "group_total")]
  names(lookup) <- c(
    "context_key",
    "candidate_scoring_probability",
    "candidate_group_total"
  )

  lookup
}

apply_one_scoring_frequency_level <- function(predictions, frequency_table, spec) {
  lookup <- prepare_scoring_frequency_lookup(frequency_table, spec)
  predictions$context_key <- make_scoring_context_key(predictions, spec$group_columns)

  merged <- merge(
    predictions,
    lookup,
    by = "context_key",
    all.x = TRUE,
    sort = FALSE
  )

  has_prediction <- is.na(merged$frequency_scoring_probability) &
    !is.na(merged$candidate_scoring_probability)

  merged$frequency_scoring_probability[has_prediction] <-
    merged$candidate_scoring_probability[has_prediction]
  merged$used_frequency_level[has_prediction] <- spec$model_name
  merged$used_frequency_group_total[has_prediction] <-
    merged$candidate_group_total[has_prediction]

  merged$candidate_scoring_probability <- NULL
  merged$candidate_group_total <- NULL
  merged$context_key <- NULL

  merged
}

apply_scoring_frequency_baseline <- function(
  split_dataset,
  frequency_table,
  threshold = 0.5
) {
  train_positive_rate <- mean(
    split_dataset$will_score_from_current_pa[
      split_dataset$validation_split == "train"
    ],
    na.rm = TRUE
  )

  predictions <- split_dataset
  predictions$frequency_scoring_probability <- NA_real_
  predictions$used_frequency_level <- NA_character_
  predictions$used_frequency_group_total <- NA_integer_

  for (spec in get_scoring_frequency_specs()) {
    predictions <- apply_one_scoring_frequency_level(
      predictions,
      frequency_table,
      spec
    )
  }

  missing_probability <- is.na(predictions$frequency_scoring_probability)
  predictions$frequency_scoring_probability[missing_probability] <- train_positive_rate
  predictions$used_frequency_level[missing_probability] <- "global_train_rate"
  predictions$used_frequency_group_total[missing_probability] <- sum(
    split_dataset$validation_split == "train"
  )
  predictions$frequency_predicted_will_score <- as.integer(
    predictions$frequency_scoring_probability >= threshold
  )

  predictions
}

build_scoring_frequency_baseline <- function(split_dataset, threshold = 0.5) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  frequency_table <- build_all_scoring_frequency_tables(train_data)
  predictions <- apply_scoring_frequency_baseline(
    split_dataset,
    frequency_table,
    threshold = threshold
  )

  metrics <- calculate_scoring_binary_metrics(
    predictions,
    model_name = "context_frequency",
    probability_column = "frequency_scoring_probability",
    predicted_column = "frequency_predicted_will_score",
    threshold = threshold
  )

  list(
    frequency_table = frequency_table,
    predictions = predictions,
    metrics = metrics
  )
}

train_scoring_logistic_model <- function(train_data) {
  feature_columns <- get_stage1_inning_scoring_feature_columns()
  formula_text <- paste(
    "will_score_from_current_pa_factor ~",
    paste(feature_columns, collapse = " + ")
  )

  glm(
    formula = as.formula(formula_text),
    data = train_data,
    family = binomial()
  )
}

build_scoring_logistic_baseline <- function(split_dataset, threshold = 0.5) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  logistic_model <- train_scoring_logistic_model(train_data)

  predictions <- split_dataset
  predictions$logistic_scoring_probability <- as.numeric(predict(
    logistic_model,
    newdata = predictions,
    type = "response"
  ))
  predictions$logistic_predicted_will_score <- as.integer(
    predictions$logistic_scoring_probability >= threshold
  )

  metrics <- calculate_scoring_binary_metrics(
    predictions,
    model_name = "logistic_regression",
    probability_column = "logistic_scoring_probability",
    predicted_column = "logistic_predicted_will_score",
    threshold = threshold
  )

  list(
    model = logistic_model,
    predictions = predictions,
    metrics = metrics
  )
}

create_scoring_probability_bins <- function(
  prediction_dataset,
  model_name,
  probability_column,
  predicted_column,
  bin_count = 10
) {
  prediction_dataset$probability_bin <- cut(
    prediction_dataset[[probability_column]],
    breaks = seq(0, 1, length.out = bin_count + 1),
    include.lowest = TRUE
  )

  do.call(rbind, lapply(
    split(prediction_dataset, list(
      prediction_dataset$validation_split,
      prediction_dataset$probability_bin
    ), drop = TRUE),
    function(bin_data) {
      data.frame(
        model_name = model_name,
        validation_split = bin_data$validation_split[1],
        probability_bin = as.character(bin_data$probability_bin[1]),
        row_count = nrow(bin_data),
        mean_predicted_probability = round(
          mean(bin_data[[probability_column]], na.rm = TRUE),
          6
        ),
        actual_scoring_rate = round(
          mean(bin_data$will_score_from_current_pa, na.rm = TRUE),
          6
        ),
        predicted_positive_rate = round(
          mean(bin_data[[predicted_column]] == 1, na.rm = TRUE),
          6
        ),
        stringsAsFactors = FALSE
      )
    }
  ))
}

create_frequency_level_summary <- function(frequency_predictions) {
  level_counts <- as.data.frame(table(
    frequency_predictions$validation_split,
    frequency_predictions$used_frequency_level
  ), stringsAsFactors = FALSE)
  names(level_counts) <- c(
    "validation_split",
    "used_frequency_level",
    "row_count"
  )

  level_counts$proportion <- NA_real_
  for (split_name in unique(level_counts$validation_split)) {
    split_total <- sum(frequency_predictions$validation_split == split_name)
    level_counts$proportion[level_counts$validation_split == split_name] <- round(
      level_counts$row_count[level_counts$validation_split == split_name] / split_total,
      6
    )
  }

  level_counts[order(
    level_counts$validation_split,
    -level_counts$row_count
  ), ]
}

select_stage1_scoring_baseline_recommendation <- function(model_comparison) {
  test_comparison <- model_comparison[
    model_comparison$validation_split == "test",
  ]

  test_comparison <- test_comparison[order(
    test_comparison$brier_score,
    -test_comparison$f1_score,
    -test_comparison$recall,
    -test_comparison$accuracy
  ), ]

  recommendation <- test_comparison[1, ]
  recommendation$decision_reason <- paste(
    "lowest_test_brier_then_f1_at_threshold_0_5",
    "accuracy_is_secondary_because_positive_rate_is_imbalanced",
    sep = "__"
  )

  recommendation
}

save_stage1_scoring_baseline_outputs <- function(
  model_comparison,
  frequency_table,
  frequency_predictions,
  logistic_predictions,
  probability_bins,
  frequency_level_summary,
  recommendation,
  comparison_path = "outputs/prediction/stage1_inning_scoring_baseline_comparison.csv",
  frequency_table_path = "outputs/prediction/stage1_inning_scoring_frequency_table.csv",
  frequency_predictions_path = "outputs/prediction/stage1_inning_scoring_frequency_predictions.csv",
  logistic_predictions_path = "outputs/prediction/stage1_inning_scoring_logistic_predictions.csv",
  probability_bins_path = "outputs/prediction/stage1_inning_scoring_probability_bins.csv",
  frequency_level_summary_path = "outputs/prediction/stage1_inning_scoring_frequency_level_summary.csv",
  recommendation_path = "outputs/prediction/stage1_inning_scoring_baseline_recommendation.csv"
) {
  output_dir <- dirname(comparison_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(model_comparison, comparison_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(frequency_table, frequency_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(frequency_predictions, frequency_predictions_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(logistic_predictions, logistic_predictions_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(frequency_level_summary, frequency_level_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    comparison_path = comparison_path,
    frequency_table_path = frequency_table_path,
    frequency_predictions_path = frequency_predictions_path,
    logistic_predictions_path = logistic_predictions_path,
    probability_bins_path = probability_bins_path,
    frequency_level_summary_path = frequency_level_summary_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  set.seed(20260523)

  model_dataset <- load_stage1_inning_scoring_model_dataset()
  split_info <- create_chronological_split(model_dataset)
  split_dataset <- prepare_stage1_inning_scoring_dataset(split_info$dataset)

  majority_result <- build_scoring_majority_baseline(split_dataset)
  frequency_result <- build_scoring_frequency_baseline(split_dataset)
  logistic_result <- build_scoring_logistic_baseline(split_dataset)

  model_comparison <- rbind(
    majority_result$metrics,
    frequency_result$metrics,
    logistic_result$metrics
  )

  probability_bins <- rbind(
    create_scoring_probability_bins(
      frequency_result$predictions,
      model_name = "context_frequency",
      probability_column = "frequency_scoring_probability",
      predicted_column = "frequency_predicted_will_score"
    ),
    create_scoring_probability_bins(
      logistic_result$predictions,
      model_name = "logistic_regression",
      probability_column = "logistic_scoring_probability",
      predicted_column = "logistic_predicted_will_score"
    )
  )

  frequency_level_summary <- create_frequency_level_summary(
    frequency_result$predictions
  )
  recommendation <- select_stage1_scoring_baseline_recommendation(
    model_comparison
  )

  output_paths <- save_stage1_scoring_baseline_outputs(
    model_comparison,
    frequency_result$frequency_table,
    frequency_result$predictions,
    logistic_result$predictions,
    probability_bins,
    frequency_level_summary,
    recommendation
  )

  message("Saved Stage 1 inning-scoring baseline comparison to: ", output_paths$comparison_path)
  message("Saved Stage 1 inning-scoring frequency table to: ", output_paths$frequency_table_path)
  message("Saved Stage 1 inning-scoring frequency predictions to: ", output_paths$frequency_predictions_path)
  message("Saved Stage 1 inning-scoring logistic predictions to: ", output_paths$logistic_predictions_path)
  message("Saved Stage 1 inning-scoring probability bins to: ", output_paths$probability_bins_path)
  message("Saved Stage 1 inning-scoring frequency level summary to: ", output_paths$frequency_level_summary_path)
  message("Saved Stage 1 inning-scoring baseline recommendation to: ", output_paths$recommendation_path)
}
