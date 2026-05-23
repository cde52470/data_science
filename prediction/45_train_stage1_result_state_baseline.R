#!/usr/bin/env Rscript

# Train Stage 1 result-state baselines.
# Run from the project root:
# Rscript prediction/45_train_stage1_result_state_baseline.R

source("prediction/11_validate_stage1_frequency_baseline.R")

if (!requireNamespace("nnet", quietly = TRUE)) {
  stop("Required R package not installed: nnet")
}

load_stage1_result_state_model_dataset <- function(
  input_path = "data/cleaned/stage1_result_state_model_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 result-state model dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_stage1_result_state_feature_columns <- function(include_player_features = TRUE) {
  base_features <- c(
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
    "run_expectancy_before"
  )

  player_features <- c(
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

  if (include_player_features) {
    c(base_features, player_features)
  } else {
    base_features
  }
}

prepare_stage1_result_state_dataset <- function(model_dataset) {
  feature_columns <- get_stage1_result_state_feature_columns(TRUE)
  required_columns <- c("stage1_result_state", "date", "game_id", feature_columns)
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
  prepared_dataset$stage1_result_state <- factor(prepared_dataset$stage1_result_state)

  for (column_name in categorical_columns) {
    prepared_dataset[[column_name]] <- factor(prepared_dataset[[column_name]])
  }

  prepared_dataset
}

build_stage1_result_majority_baseline <- function(split_dataset) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  class_counts <- sort(table(train_data$stage1_result_state), decreasing = TRUE)
  majority_class <- names(class_counts)[1]
  majority_probability <- as.numeric(class_counts[1]) / nrow(train_data)
  result_classes <- sort(unique(as.character(split_dataset$stage1_result_state)))

  predictions <- split_dataset
  predictions$predicted_result_state <- majority_class
  predictions$predicted_probability <- majority_probability
  for (class_name in result_classes) {
    probability_column <- paste0("prob_result_state_", class_name)
    predictions[[probability_column]] <- ifelse(class_name == majority_class, 1, 0)
  }
  predictions$used_baseline_level <- "train_majority_class"
  predictions$model_name <- "majority_baseline"
  predictions$is_correct_prediction <- (
    as.character(predictions$stage1_result_state) == predictions$predicted_result_state
  )

  predictions
}

get_stage1_result_frequency_specs <- function(include_player_types = TRUE) {
  if (include_player_types) {
    list(
      list(
        used_baseline_level = "score_momentum_baseout_player",
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
        used_baseline_level = "baseout_player",
        group_columns = c(
          "current_base_out_state",
          "batter_primary_type",
          "pitcher_primary_type"
        ),
        minimum_group_total = 50
      ),
      list(
        used_baseline_level = "score_baseout",
        group_columns = c("before_score_state", "current_base_out_state"),
        minimum_group_total = 30
      ),
      list(
        used_baseline_level = "baseout_only",
        group_columns = c("current_base_out_state"),
        minimum_group_total = 1
      )
    )
  } else {
    list(
      list(
        used_baseline_level = "score_momentum_baseout",
        group_columns = c(
          "before_score_state",
          "before_momentum_state",
          "current_base_out_state"
        ),
        minimum_group_total = 50
      ),
      list(
        used_baseline_level = "score_baseout",
        group_columns = c("before_score_state", "current_base_out_state"),
        minimum_group_total = 30
      ),
      list(
        used_baseline_level = "baseout_only",
        group_columns = c("current_base_out_state"),
        minimum_group_total = 1
      )
    )
  }
}

make_stage1_result_context_key <- function(dataset, group_columns) {
  assert_required_columns(dataset, group_columns)
  apply(dataset[, group_columns, drop = FALSE], 1, paste, collapse = "||")
}

build_one_stage1_result_frequency_table <- function(train_data, spec) {
  group_columns <- spec$group_columns
  required_columns <- c(group_columns, "stage1_result_state")
  assert_required_columns(train_data, required_columns)

  group_class_counts <- aggregate(
    rep(1, nrow(train_data)),
    by = train_data[, c(group_columns, "stage1_result_state"), drop = FALSE],
    FUN = sum
  )
  names(group_class_counts)[ncol(group_class_counts)] <- "class_count"

  group_totals <- aggregate(
    group_class_counts$class_count,
    by = group_class_counts[, group_columns, drop = FALSE],
    FUN = sum
  )
  names(group_totals)[ncol(group_totals)] <- "group_total"

  group_class_counts <- merge(
    group_class_counts,
    group_totals,
    by = group_columns,
    all.x = TRUE,
    sort = FALSE
  )
  group_class_counts$class_probability <- group_class_counts$class_count /
    group_class_counts$group_total
  group_class_counts <- group_class_counts[
    group_class_counts$group_total >= spec$minimum_group_total,
  ]

  if (nrow(group_class_counts) == 0) {
    return(data.frame())
  }

  group_class_counts <- group_class_counts[order(
    group_class_counts[, group_columns[1]],
    -group_class_counts$class_probability,
    -group_class_counts$class_count
  ), ]
  group_class_counts$context_key <- make_stage1_result_context_key(
    group_class_counts,
    group_columns
  )
  top_rows <- !duplicated(group_class_counts$context_key)
  top_predictions <- group_class_counts[top_rows, ]
  top_predictions$used_baseline_level <- spec$used_baseline_level

  top_predictions[, c(
    "context_key",
    "stage1_result_state",
    "class_probability",
    "group_total",
    "used_baseline_level"
  )]
}

build_stage1_result_frequency_tables <- function(train_data, include_player_types) {
  specs <- get_stage1_result_frequency_specs(include_player_types)
  tables <- lapply(specs, function(spec) {
    frequency_table <- build_one_stage1_result_frequency_table(train_data, spec)
    if (nrow(frequency_table) > 0) {
      frequency_table$spec_index <- which(vapply(
        specs,
        function(candidate) candidate$used_baseline_level == spec$used_baseline_level,
        logical(1)
      ))[1]
    }
    frequency_table
  })

  do.call(rbind, tables)
}

apply_one_stage1_result_frequency_level <- function(prediction_dataset, train_data, spec) {
  frequency_table <- build_one_stage1_result_frequency_table(train_data, spec)

  if (nrow(frequency_table) == 0) {
    return(prediction_dataset)
  }

  prediction_dataset$temporary_context_key <- make_stage1_result_context_key(
    prediction_dataset,
    spec$group_columns
  )
  lookup <- frequency_table[, c(
    "context_key",
    "stage1_result_state",
    "class_probability",
    "group_total",
    "used_baseline_level"
  )]
  names(lookup)[names(lookup) == "context_key"] <- "temporary_context_key"
  names(lookup)[names(lookup) == "stage1_result_state"] <- "lookup_result_state"
  names(lookup)[names(lookup) == "class_probability"] <- "lookup_probability"
  names(lookup)[names(lookup) == "group_total"] <- "lookup_group_total"
  names(lookup)[names(lookup) == "used_baseline_level"] <- "lookup_used_baseline_level"

  merged <- merge(
    prediction_dataset,
    lookup,
    by = "temporary_context_key",
    all.x = TRUE,
    sort = FALSE
  )
  merged <- merged[order(merged$row_id), ]

  missing_prediction <- is.na(merged$predicted_result_state)
  has_lookup <- !is.na(merged$lookup_result_state)
  fill_rows <- missing_prediction & has_lookup

  merged$predicted_result_state[fill_rows] <- as.character(merged$lookup_result_state[fill_rows])
  merged$predicted_probability[fill_rows] <- merged$lookup_probability[fill_rows]
  merged$used_baseline_level[fill_rows] <- as.character(
    merged$lookup_used_baseline_level[fill_rows]
  )
  merged$frequency_group_total[fill_rows] <- merged$lookup_group_total[fill_rows]

  drop_columns <- c(
    "temporary_context_key",
    "lookup_result_state",
    "lookup_probability",
    "lookup_group_total",
    "lookup_used_baseline_level"
  )
  merged[, setdiff(names(merged), drop_columns)]
}

build_stage1_result_frequency_baseline <- function(
  split_dataset,
  include_player_types = TRUE,
  model_name = "frequency_with_player_type"
) {
  train_data <- split_dataset[split_dataset$validation_split == "train", ]
  specs <- get_stage1_result_frequency_specs(include_player_types)
  train_class_counts <- sort(table(train_data$stage1_result_state), decreasing = TRUE)
  global_class <- names(train_class_counts)[1]
  global_probability <- as.numeric(train_class_counts[1]) / nrow(train_data)

  predictions <- split_dataset
  predictions$row_id <- seq_len(nrow(predictions))
  predictions$predicted_result_state <- NA_character_
  predictions$predicted_probability <- NA_real_
  predictions$used_baseline_level <- NA_character_
  predictions$frequency_group_total <- NA_real_

  for (spec in specs) {
    predictions <- apply_one_stage1_result_frequency_level(predictions, train_data, spec)
  }

  missing_prediction <- is.na(predictions$predicted_result_state)
  predictions$predicted_result_state[missing_prediction] <- global_class
  predictions$predicted_probability[missing_prediction] <- global_probability
  predictions$used_baseline_level[missing_prediction] <- "global_train_majority"
  predictions$frequency_group_total[missing_prediction] <- nrow(train_data)
  result_classes <- sort(unique(as.character(split_dataset$stage1_result_state)))
  for (class_name in result_classes) {
    probability_column <- paste0("prob_result_state_", class_name)
    predictions[[probability_column]] <- ifelse(
      predictions$predicted_result_state == class_name,
      predictions$predicted_probability,
      NA_real_
    )
  }
  predictions$model_name <- model_name
  predictions$is_correct_prediction <- (
    as.character(predictions$stage1_result_state) == predictions$predicted_result_state
  )

  predictions
}

train_stage1_result_multinomial_model <- function(train_dataset, include_player_features) {
  feature_columns <- get_stage1_result_state_feature_columns(include_player_features)
  formula_text <- paste(
    "stage1_result_state ~",
    paste(feature_columns, collapse = " + ")
  )

  nnet::multinom(
    formula = as.formula(formula_text),
    data = train_dataset,
    trace = FALSE,
    MaxNWts = 30000,
    maxit = 400
  )
}

predict_stage1_result_multinomial <- function(model, prediction_dataset, model_name) {
  probability_matrix <- predict(model, newdata = prediction_dataset, type = "probs")
  probability_matrix <- as.matrix(probability_matrix)
  predicted_index <- max.col(probability_matrix, ties.method = "first")

  predictions <- prediction_dataset
  predictions$predicted_result_state <- colnames(probability_matrix)[predicted_index]
  predictions$predicted_probability <- probability_matrix[
    cbind(seq_len(nrow(probability_matrix)), predicted_index)
  ]
  for (class_name in colnames(probability_matrix)) {
    probability_column <- paste0("prob_result_state_", class_name)
    predictions[[probability_column]] <- probability_matrix[, class_name]
  }
  predictions$used_baseline_level <- "multinomial_model"
  predictions$model_name <- model_name
  predictions$is_correct_prediction <- (
    as.character(predictions$stage1_result_state) == predictions$predicted_result_state
  )

  predictions
}

align_stage1_result_prediction_columns <- function(prediction_list) {
  all_columns <- unique(unlist(lapply(prediction_list, names)))

  aligned_predictions <- lapply(prediction_list, function(prediction_dataset) {
    missing_columns <- setdiff(all_columns, names(prediction_dataset))
    for (column_name in missing_columns) {
      prediction_dataset[[column_name]] <- NA
    }
    prediction_dataset[, all_columns]
  })

  do.call(rbind, aligned_predictions)
}

assign_stage1_result_probability_bin <- function(probabilities) {
  cut(
    probabilities,
    breaks = c(0, 0.3, 0.4, 0.5, 0.6, 0.7, 1),
    labels = c(
      "0.00-0.30",
      "0.30-0.40",
      "0.40-0.50",
      "0.50-0.60",
      "0.60-0.70",
      "0.70-1.00"
    ),
    include.lowest = TRUE,
    right = FALSE
  )
}

calculate_stage1_result_class_metrics <- function(prediction_dataset) {
  split_names <- sort(unique(prediction_dataset$validation_split))
  model_names <- sort(unique(prediction_dataset$model_name))

  do.call(rbind, lapply(model_names, function(model_name) {
    model_data <- prediction_dataset[prediction_dataset$model_name == model_name, ]

    do.call(rbind, lapply(split_names, function(split_name) {
      split_data <- model_data[model_data$validation_split == split_name, ]
      classes <- sort(unique(c(
        as.character(split_data$stage1_result_state),
        split_data$predicted_result_state
      )))

      do.call(rbind, lapply(classes, function(class_name) {
        true_positive <- sum(
          as.character(split_data$stage1_result_state) == class_name &
            split_data$predicted_result_state == class_name
        )
        false_positive <- sum(
          as.character(split_data$stage1_result_state) != class_name &
            split_data$predicted_result_state == class_name
        )
        false_negative <- sum(
          as.character(split_data$stage1_result_state) == class_name &
            split_data$predicted_result_state != class_name
        )

        precision <- ifelse(
          true_positive + false_positive == 0,
          0,
          true_positive / (true_positive + false_positive)
        )
        recall <- ifelse(
          true_positive + false_negative == 0,
          0,
          true_positive / (true_positive + false_negative)
        )
        f1_score <- ifelse(
          precision + recall == 0,
          0,
          2 * precision * recall / (precision + recall)
        )

        data.frame(
          model_name = model_name,
          validation_split = split_name,
          class = class_name,
          support = sum(as.character(split_data$stage1_result_state) == class_name),
          predicted_count = sum(split_data$predicted_result_state == class_name),
          true_positive = true_positive,
          false_positive = false_positive,
          false_negative = false_negative,
          precision = round(precision, 4),
          recall = round(recall, 4),
          f1_score = round(f1_score, 4),
          stringsAsFactors = FALSE
        )
      }))
    }))
  }))
}

calculate_stage1_result_model_comparison <- function(prediction_dataset, class_metrics) {
  split_names <- sort(unique(prediction_dataset$validation_split))
  model_names <- sort(unique(prediction_dataset$model_name))

  comparison <- do.call(rbind, lapply(model_names, function(model_name) {
    model_data <- prediction_dataset[prediction_dataset$model_name == model_name, ]

    do.call(rbind, lapply(split_names, function(split_name) {
      split_data <- model_data[model_data$validation_split == split_name, ]
      split_class_metrics <- class_metrics[
        class_metrics$model_name == model_name &
          class_metrics$validation_split == split_name,
      ]

      data.frame(
        model_name = model_name,
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(split_data$is_correct_prediction, na.rm = TRUE), 4),
        macro_precision = round(mean(split_class_metrics$precision, na.rm = TRUE), 4),
        macro_recall = round(mean(split_class_metrics$recall, na.rm = TRUE), 4),
        macro_f1 = round(mean(split_class_metrics$f1_score, na.rm = TRUE), 4),
        mean_predicted_probability = round(
          mean(split_data$predicted_probability, na.rm = TRUE),
          4
        ),
        stringsAsFactors = FALSE
      )
    }))
  }))

  row.names(comparison) <- NULL
  comparison
}

calculate_stage1_result_probability_bins <- function(prediction_dataset) {
  prediction_dataset$probability_bin <- assign_stage1_result_probability_bin(
    prediction_dataset$predicted_probability
  )

  aggregate_data <- aggregate(
    prediction_dataset$is_correct_prediction,
    by = prediction_dataset[, c("model_name", "validation_split", "probability_bin")],
    FUN = function(values) sum(values, na.rm = TRUE)
  )
  names(aggregate_data)[ncol(aggregate_data)] <- "correct_count"

  totals <- aggregate(
    rep(1, nrow(prediction_dataset)),
    by = prediction_dataset[, c("model_name", "validation_split", "probability_bin")],
    FUN = sum
  )
  names(totals)[ncol(totals)] <- "total_count"

  probability_means <- aggregate(
    prediction_dataset$predicted_probability,
    by = prediction_dataset[, c("model_name", "validation_split", "probability_bin")],
    FUN = mean
  )
  names(probability_means)[ncol(probability_means)] <- "mean_predicted_probability"

  bins <- merge(aggregate_data, totals, by = c(
    "model_name",
    "validation_split",
    "probability_bin"
  ), all.x = TRUE, sort = FALSE)
  bins <- merge(bins, probability_means, by = c(
    "model_name",
    "validation_split",
    "probability_bin"
  ), all.x = TRUE, sort = FALSE)

  bins$accuracy <- round(bins$correct_count / bins$total_count, 4)
  bins$mean_predicted_probability <- round(bins$mean_predicted_probability, 4)
  bins <- bins[order(bins$model_name, bins$validation_split, bins$probability_bin), ]
  row.names(bins) <- NULL

  bins
}

summarize_stage1_result_frequency_lookup <- function(prediction_dataset) {
  frequency_data <- prediction_dataset[
    prediction_dataset$model_name %in% c(
      "frequency_with_player_type",
      "frequency_without_player_type"
    ),
  ]

  lookup_counts <- aggregate(
    rep(1, nrow(frequency_data)),
    by = frequency_data[, c("model_name", "validation_split", "used_baseline_level")],
    FUN = sum
  )
  names(lookup_counts)[ncol(lookup_counts)] <- "row_count"

  split_totals <- aggregate(
    rep(1, nrow(frequency_data)),
    by = frequency_data[, c("model_name", "validation_split")],
    FUN = sum
  )
  names(split_totals)[ncol(split_totals)] <- "split_total"

  lookup_summary <- merge(
    lookup_counts,
    split_totals,
    by = c("model_name", "validation_split"),
    all.x = TRUE,
    sort = FALSE
  )
  lookup_summary$row_share <- round(lookup_summary$row_count / lookup_summary$split_total, 4)
  lookup_summary <- lookup_summary[order(
    lookup_summary$model_name,
    lookup_summary$validation_split,
    -lookup_summary$row_share
  ), ]
  row.names(lookup_summary) <- NULL

  lookup_summary
}

create_stage1_result_baseline_recommendation <- function(comparison, class_metrics) {
  test_comparison <- comparison[comparison$validation_split == "test", ]
  test_comparison <- test_comparison[order(-test_comparison$macro_f1), ]
  best_model <- test_comparison$model_name[1]

  with_player <- test_comparison[
    test_comparison$model_name == "multinomial_with_player_type",
  ]
  without_player <- test_comparison[
    test_comparison$model_name == "multinomial_without_player_type",
  ]

  player_macro_f1_lift <- ifelse(
    nrow(with_player) == 1 & nrow(without_player) == 1,
    with_player$macro_f1 - without_player$macro_f1,
    NA_real_
  )
  player_accuracy_lift <- ifelse(
    nrow(with_player) == 1 & nrow(without_player) == 1,
    with_player$accuracy - without_player$accuracy,
    NA_real_
  )

  important_classes <- class_metrics[
    class_metrics$validation_split == "test" &
      class_metrics$model_name == best_model &
      class_metrics$class %in% c("big_inning", "score_multiple", "wasted_chance"),
  ]
  important_recall <- round(mean(important_classes$recall, na.rm = TRUE), 4)

  data.frame(
    summary_group = c(
      "recommended_model",
      "player_type_signal",
      "player_type_signal",
      "minority_state_signal",
      "next_step"
    ),
    summary_item = c(
      "best_test_macro_f1_model",
      "multinomial_player_macro_f1_lift",
      "multinomial_player_accuracy_lift",
      "best_model_important_state_mean_recall",
      "recommendation"
    ),
    value = c(
      best_model,
      round(player_macro_f1_lift, 4),
      round(player_accuracy_lift, 4),
      important_recall,
      "connect_result_state_prediction_to_stage2_win_bridge"
    ),
    stringsAsFactors = FALSE
  )
}

save_stage1_result_baseline_outputs <- function(
  prediction_dataset,
  comparison,
  class_metrics,
  probability_bins,
  lookup_summary,
  recommendation,
  prediction_path = "outputs/prediction/stage1_result_state_baseline_predictions.csv",
  comparison_path = "outputs/prediction/stage1_result_state_baseline_comparison.csv",
  class_metrics_path = "outputs/prediction/stage1_result_state_baseline_class_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_result_state_baseline_probability_bins.csv",
  lookup_summary_path = "outputs/prediction/stage1_result_state_frequency_lookup_summary.csv",
  recommendation_path = "outputs/prediction/stage1_result_state_baseline_recommendation.csv"
) {
  output_dir <- dirname(prediction_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_dataset, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(comparison, comparison_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(lookup_summary, lookup_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    comparison_path = comparison_path,
    class_metrics_path = class_metrics_path,
    probability_bins_path = probability_bins_path,
    lookup_summary_path = lookup_summary_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  model_dataset <- load_stage1_result_state_model_dataset()
  prepared_dataset <- prepare_stage1_result_state_dataset(model_dataset)
  split_info <- create_chronological_split(prepared_dataset)
  split_dataset <- split_info$dataset
  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]

  majority_predictions <- build_stage1_result_majority_baseline(split_dataset)
  frequency_without_player_predictions <- build_stage1_result_frequency_baseline(
    split_dataset,
    include_player_types = FALSE,
    model_name = "frequency_without_player_type"
  )
  frequency_with_player_predictions <- build_stage1_result_frequency_baseline(
    split_dataset,
    include_player_types = TRUE,
    model_name = "frequency_with_player_type"
  )

  multinomial_without_player_model <- train_stage1_result_multinomial_model(
    train_dataset,
    include_player_features = FALSE
  )
  multinomial_without_player_predictions <- predict_stage1_result_multinomial(
    multinomial_without_player_model,
    split_dataset,
    model_name = "multinomial_without_player_type"
  )

  multinomial_with_player_model <- train_stage1_result_multinomial_model(
    train_dataset,
    include_player_features = TRUE
  )
  multinomial_with_player_predictions <- predict_stage1_result_multinomial(
    multinomial_with_player_model,
    split_dataset,
    model_name = "multinomial_with_player_type"
  )

  prediction_dataset <- align_stage1_result_prediction_columns(
    list(
      majority_predictions,
      frequency_without_player_predictions,
      frequency_with_player_predictions,
      multinomial_without_player_predictions,
      multinomial_with_player_predictions
    )
  )

  class_metrics <- calculate_stage1_result_class_metrics(prediction_dataset)
  comparison <- calculate_stage1_result_model_comparison(prediction_dataset, class_metrics)
  probability_bins <- calculate_stage1_result_probability_bins(prediction_dataset)
  lookup_summary <- summarize_stage1_result_frequency_lookup(prediction_dataset)
  recommendation <- create_stage1_result_baseline_recommendation(comparison, class_metrics)

  output_paths <- save_stage1_result_baseline_outputs(
    prediction_dataset,
    comparison,
    class_metrics,
    probability_bins,
    lookup_summary,
    recommendation
  )

  test_comparison <- comparison[comparison$validation_split == "test", ]
  test_comparison <- test_comparison[order(-test_comparison$macro_f1), ]

  message("Saved Stage 1 result-state baseline predictions to: ", output_paths$prediction_path)
  message("Saved Stage 1 result-state baseline comparison to: ", output_paths$comparison_path)
  message("Best test macro-F1 model: ", test_comparison$model_name[1])
}
