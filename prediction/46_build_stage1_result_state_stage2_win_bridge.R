#!/usr/bin/env Rscript

# Bridge Stage 1 result-state probability distribution to Stage 2 win probability.
# Run from the project root:
# Rscript prediction/46_build_stage1_result_state_stage2_win_bridge.R

source("prediction/40_build_stage1_scoring_stage2_win_context_bridge.R")

load_stage1_result_state_baseline_predictions <- function(
  input_path = "outputs/prediction/stage1_result_state_baseline_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 result-state baseline predictions not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_stage2_inning_outcome_dataset <- function(
  input_path = "data/cleaned/stage2_inning_outcome_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 2 inning outcome dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_stage1_result_state_classes <- function() {
  c(
    "big_inning",
    "no_score_stable",
    "score_multiple",
    "score_once",
    "wasted_chance"
  )
}

get_stage1_result_probability_columns <- function() {
  paste0("prob_result_state_", get_stage1_result_state_classes())
}

prepare_stage1_result_state_predictions_for_bridge <- function(
  stage1_predictions,
  model_name = "multinomial_with_player_type"
) {
  probability_columns <- get_stage1_result_probability_columns()
  required_columns <- c(
    "game_id",
    "season",
    "date",
    "game_date",
    "validation_split",
    "stadium",
    "inning",
    "half_inning",
    "batting_team",
    "fielding_team",
    "is_home_batting",
    "pa_order",
    "batter_name",
    "pitcher_name",
    "current_base_out_state",
    "score_diff_before",
    "run_expectancy_before",
    "batter_primary_type",
    "pitcher_primary_type",
    "stage1_result_state",
    "predicted_result_state",
    "predicted_probability",
    "model_name",
    probability_columns
  )
  assert_required_columns(stage1_predictions, required_columns)

  bridge_predictions <- stage1_predictions[stage1_predictions$model_name == model_name, ]

  probability_sum <- rowSums(bridge_predictions[, probability_columns], na.rm = TRUE)
  if (any(abs(probability_sum - 1) > 0.001)) {
    stop("Stage 1 result-state probability columns do not sum to 1.")
  }

  bridge_predictions
}

prepare_stage2_outcome_for_result_bridge <- function(stage2_outcome_dataset) {
  required_columns <- c(
    "game_id",
    "team",
    "inning",
    "inning_phase",
    "score_state",
    "momentum_state",
    "combined_state",
    "run_diff_now",
    "team_win"
  )
  assert_required_columns(stage2_outcome_dataset, required_columns)

  output <- stage2_outcome_dataset[, required_columns]
  names(output) <- c(
    "game_id",
    "batting_team",
    "inning",
    "stage2_inning_phase",
    "stage2_score_state",
    "stage2_momentum_state",
    "stage2_combined_state",
    "stage2_run_diff_now",
    "stage2_team_win"
  )

  output
}

build_stage1_result_state_stage2_bridge_dataset <- function(
  stage1_bridge_predictions,
  stage2_outcome_dataset
) {
  stage2_output <- prepare_stage2_outcome_for_result_bridge(stage2_outcome_dataset)

  bridge_dataset <- merge(
    stage1_bridge_predictions,
    stage2_output,
    by = c("game_id", "inning", "batting_team"),
    all.x = TRUE,
    sort = FALSE
  )

  if (any(is.na(bridge_dataset$stage2_team_win))) {
    stop("Unable to match all Stage 1 result-state rows to Stage 2 outcomes.")
  }

  bridge_dataset$score_diff_bucket <- bucket_score_diff_for_context_bridge(
    bridge_dataset$score_diff_before
  )
  bridge_dataset$home_away_context <- ifelse(
    bridge_dataset$is_home_batting,
    "home_batting",
    "away_batting"
  )

  bridge_dataset
}

get_result_state_win_bridge_specs <- function() {
  list(
    list(
      lookup_level = "result_phase_score_home",
      group_columns = c(
        "stage1_result_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context"
      ),
      minimum_group_total = 80
    ),
    list(
      lookup_level = "result_phase_score",
      group_columns = c(
        "stage1_result_state",
        "stage2_inning_phase",
        "score_diff_bucket"
      ),
      minimum_group_total = 80
    ),
    list(
      lookup_level = "result_phase_stage2_score",
      group_columns = c(
        "stage1_result_state",
        "stage2_inning_phase",
        "stage2_score_state"
      ),
      minimum_group_total = 80
    ),
    list(
      lookup_level = "result_phase",
      group_columns = c("stage1_result_state", "stage2_inning_phase"),
      minimum_group_total = 1
    ),
    list(
      lookup_level = "result_only",
      group_columns = c("stage1_result_state"),
      minimum_group_total = 1
    )
  )
}

make_result_bridge_key <- function(dataset, group_columns) {
  assert_required_columns(dataset, group_columns)
  apply(dataset[, group_columns, drop = FALSE], 1, paste, collapse = "||")
}

build_one_result_state_win_table <- function(train_dataset, spec) {
  required_columns <- c(spec$group_columns, "stage2_team_win")
  assert_required_columns(train_dataset, required_columns)

  probability_table <- aggregate(
    as.integer(train_dataset$stage2_team_win),
    by = train_dataset[, spec$group_columns, drop = FALSE],
    FUN = mean
  )
  names(probability_table)[ncol(probability_table)] <- "result_bridge_win_probability"

  count_table <- aggregate(
    as.integer(train_dataset$stage2_team_win),
    by = train_dataset[, spec$group_columns, drop = FALSE],
    FUN = length
  )
  names(count_table)[ncol(count_table)] <- "result_bridge_train_rows"

  table_output <- merge(
    probability_table,
    count_table,
    by = spec$group_columns,
    all.x = TRUE,
    sort = FALSE
  )
  table_output$result_bridge_lookup_level <- spec$lookup_level
  table_output$result_bridge_group_columns <- paste(spec$group_columns, collapse = " + ")
  table_output$result_bridge_win_probability <- round(
    table_output$result_bridge_win_probability,
    6
  )

  table_output
}

build_all_result_state_win_tables <- function(train_dataset) {
  tables <- lapply(get_result_state_win_bridge_specs(), function(spec) {
    build_one_result_state_win_table(train_dataset, spec)
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

prepare_result_state_win_lookup <- function(result_bridge_table, spec) {
  required_columns <- c(
    "result_bridge_lookup_level",
    spec$group_columns,
    "result_bridge_win_probability",
    "result_bridge_train_rows"
  )
  assert_required_columns(result_bridge_table, required_columns)

  lookup <- result_bridge_table[
    result_bridge_table$result_bridge_lookup_level == spec$lookup_level &
      result_bridge_table$result_bridge_train_rows >= spec$minimum_group_total,
    required_columns
  ]

  lookup$result_bridge_key <- make_result_bridge_key(lookup, spec$group_columns)
  lookup[, c(
    "result_bridge_key",
    "result_bridge_win_probability",
    "result_bridge_train_rows"
  )]
}

lookup_result_state_win_probability <- function(
  prediction_row,
  candidate_result_state,
  result_bridge_table,
  global_win_probability,
  global_train_rows
) {
  lookup_row <- prediction_row
  lookup_row$stage1_result_state <- candidate_result_state

  for (spec in get_result_state_win_bridge_specs()) {
    lookup <- prepare_result_state_win_lookup(result_bridge_table, spec)
    lookup_key <- make_result_bridge_key(lookup_row, spec$group_columns)
    match_row <- lookup[lookup$result_bridge_key == lookup_key, ]

    if (nrow(match_row) > 0) {
      return(list(
        win_probability = match_row$result_bridge_win_probability[1],
        train_rows = match_row$result_bridge_train_rows[1],
        lookup_level = spec$lookup_level
      ))
    }
  }

  list(
    win_probability = global_win_probability,
    train_rows = global_train_rows,
    lookup_level = "global"
  )
}

build_stage1_result_state_stage2_win_bridge_output <- function(bridge_dataset) {
  result_classes <- get_stage1_result_state_classes()
  probability_columns <- get_stage1_result_probability_columns()
  required_columns <- c(
    "game_id",
    "season",
    "date",
    "game_date",
    "validation_split",
    "stadium",
    "inning",
    "half_inning",
    "batting_team",
    "fielding_team",
    "is_home_batting",
    "home_away_context",
    "pa_order",
    "batter_name",
    "pitcher_name",
    "current_base_out_state",
    "score_diff_before",
    "score_diff_bucket",
    "run_expectancy_before",
    "batter_primary_type",
    "pitcher_primary_type",
    "stage1_result_state",
    "predicted_result_state",
    "predicted_probability",
    probability_columns,
    "stage2_inning_phase",
    "stage2_score_state",
    "stage2_combined_state",
    "stage2_momentum_state",
    "stage2_run_diff_now",
    "stage2_team_win"
  )
  assert_required_columns(bridge_dataset, required_columns)

  train_dataset <- bridge_dataset[bridge_dataset$validation_split == "train", ]
  result_bridge_table <- build_all_result_state_win_tables(train_dataset)
  global_win_probability <- mean(train_dataset$stage2_team_win, na.rm = TRUE)
  global_train_rows <- nrow(train_dataset)

  output <- bridge_dataset[, required_columns]
  output$weighted_result_bridge_win_probability <- 0
  output$top_result_bridge_win_probability <- NA_real_
  output$top_result_bridge_train_rows <- NA_real_
  output$top_result_bridge_lookup_level <- NA_character_

  for (class_name in result_classes) {
    lookup_results <- lapply(seq_len(nrow(output)), function(row_index) {
      lookup_result_state_win_probability(
        prediction_row = output[row_index, ],
        candidate_result_state = class_name,
        result_bridge_table = result_bridge_table,
        global_win_probability = global_win_probability,
        global_train_rows = global_train_rows
      )
    })

    win_probability_column <- paste0("win_probability_if_", class_name)
    train_rows_column <- paste0("train_rows_if_", class_name)
    lookup_level_column <- paste0("lookup_level_if_", class_name)
    stage1_probability_column <- paste0("prob_result_state_", class_name)

    output[[win_probability_column]] <- vapply(
      lookup_results,
      function(result) result$win_probability,
      numeric(1)
    )
    output[[train_rows_column]] <- vapply(
      lookup_results,
      function(result) result$train_rows,
      numeric(1)
    )
    output[[lookup_level_column]] <- vapply(
      lookup_results,
      function(result) result$lookup_level,
      character(1)
    )
    output$weighted_result_bridge_win_probability <-
      output$weighted_result_bridge_win_probability +
      output[[stage1_probability_column]] * output[[win_probability_column]]

    top_rows <- output$predicted_result_state == class_name
    output$top_result_bridge_win_probability[top_rows] <-
      output[[win_probability_column]][top_rows]
    output$top_result_bridge_train_rows[top_rows] <- output[[train_rows_column]][top_rows]
    output$top_result_bridge_lookup_level[top_rows] <- output[[lookup_level_column]][top_rows]
  }

  output$weighted_result_bridge_win_probability <- round(
    output$weighted_result_bridge_win_probability,
    6
  )
  output$weighted_result_bridge_predicted_team_win <-
    output$weighted_result_bridge_win_probability >= 0.5
  output$is_correct_weighted_result_bridge_win_prediction <- (
    output$weighted_result_bridge_predicted_team_win ==
      as.logical(output$stage2_team_win)
  )
  output$top_result_bridge_predicted_team_win <-
    output$top_result_bridge_win_probability >= 0.5
  output$is_correct_top_result_bridge_win_prediction <- (
    output$top_result_bridge_predicted_team_win ==
      as.logical(output$stage2_team_win)
  )

  list(
    prediction_output = output,
    result_bridge_table = result_bridge_table
  )
}

calculate_result_bridge_binary_metrics <- function(
  prediction_output,
  probability_column,
  predicted_column,
  model_name
) {
  split_names <- sort(unique(prediction_output$validation_split))

  do.call(rbind, lapply(split_names, function(split_name) {
    split_data <- prediction_output[prediction_output$validation_split == split_name, ]
    actual <- as.integer(split_data$stage2_team_win)
    predicted <- as.integer(split_data[[predicted_column]])
    probability <- pmin(pmax(split_data[[probability_column]], 1e-6), 1 - 1e-6)

    data.frame(
      model_name = model_name,
      validation_split = split_name,
      row_count = nrow(split_data),
      accuracy = round(mean(actual == predicted, na.rm = TRUE), 4),
      brier_score = round(mean((probability - actual) ^ 2, na.rm = TRUE), 4),
      mean_predicted_probability = round(mean(probability, na.rm = TRUE), 4),
      actual_win_rate = round(mean(actual, na.rm = TRUE), 4),
      stringsAsFactors = FALSE
    )
  }))
}

calculate_stage1_result_state_stage2_bridge_metrics <- function(prediction_output) {
  train_data <- prediction_output[prediction_output$validation_split == "train", ]
  global_win_probability <- mean(train_data$stage2_team_win, na.rm = TRUE)
  global_output <- prediction_output
  global_output$global_win_probability <- global_win_probability
  global_output$global_predicted_team_win <- global_win_probability >= 0.5

  rbind(
    calculate_result_bridge_binary_metrics(
      prediction_output,
      probability_column = "weighted_result_bridge_win_probability",
      predicted_column = "weighted_result_bridge_predicted_team_win",
      model_name = "weighted_stage1_result_distribution_bridge"
    ),
    calculate_result_bridge_binary_metrics(
      prediction_output,
      probability_column = "top_result_bridge_win_probability",
      predicted_column = "top_result_bridge_predicted_team_win",
      model_name = "top_stage1_result_state_bridge"
    ),
    calculate_result_bridge_binary_metrics(
      global_output,
      probability_column = "global_win_probability",
      predicted_column = "global_predicted_team_win",
      model_name = "global_train_win_rate"
    )
  )
}

calculate_result_bridge_probability_bins <- function(prediction_output) {
  prediction_output$probability_bin <- cut(
    prediction_output$weighted_result_bridge_win_probability,
    breaks = c(0, 0.2, 0.4, 0.5, 0.6, 0.8, 1),
    labels = c("0.00-0.20", "0.20-0.40", "0.40-0.50", "0.50-0.60", "0.60-0.80", "0.80-1.00"),
    include.lowest = TRUE,
    right = FALSE
  )

  correct_counts <- aggregate(
    prediction_output$is_correct_weighted_result_bridge_win_prediction,
    by = prediction_output[, c("validation_split", "probability_bin")],
    FUN = function(values) sum(values, na.rm = TRUE)
  )
  names(correct_counts)[ncol(correct_counts)] <- "correct_count"

  totals <- aggregate(
    rep(1, nrow(prediction_output)),
    by = prediction_output[, c("validation_split", "probability_bin")],
    FUN = sum
  )
  names(totals)[ncol(totals)] <- "total_count"

  actual_rates <- aggregate(
    as.integer(prediction_output$stage2_team_win),
    by = prediction_output[, c("validation_split", "probability_bin")],
    FUN = mean
  )
  names(actual_rates)[ncol(actual_rates)] <- "actual_win_rate"

  predicted_rates <- aggregate(
    prediction_output$weighted_result_bridge_win_probability,
    by = prediction_output[, c("validation_split", "probability_bin")],
    FUN = mean
  )
  names(predicted_rates)[ncol(predicted_rates)] <- "mean_predicted_probability"

  bins <- merge(correct_counts, totals, by = c("validation_split", "probability_bin"), all.x = TRUE)
  bins <- merge(bins, actual_rates, by = c("validation_split", "probability_bin"), all.x = TRUE)
  bins <- merge(bins, predicted_rates, by = c("validation_split", "probability_bin"), all.x = TRUE)
  bins$accuracy <- round(bins$correct_count / bins$total_count, 4)
  bins$actual_win_rate <- round(bins$actual_win_rate, 4)
  bins$mean_predicted_probability <- round(bins$mean_predicted_probability, 4)
  bins <- bins[order(bins$validation_split, bins$probability_bin), ]
  row.names(bins) <- NULL

  bins
}

summarize_result_bridge_lookup_levels <- function(prediction_output) {
  result_classes <- get_stage1_result_state_classes()
  summaries <- lapply(result_classes, function(class_name) {
    lookup_column <- paste0("lookup_level_if_", class_name)
    lookup_counts <- aggregate(
      rep(1, nrow(prediction_output)),
      by = prediction_output[, c("validation_split", lookup_column)],
      FUN = sum
    )
    names(lookup_counts) <- c("validation_split", "lookup_level", "row_count")
    lookup_counts$result_state <- class_name

    split_totals <- aggregate(
      rep(1, nrow(prediction_output)),
      by = prediction_output[, "validation_split", drop = FALSE],
      FUN = sum
    )
    names(split_totals)[2] <- "split_total"

    lookup_counts <- merge(
      lookup_counts,
      split_totals,
      by = "validation_split",
      all.x = TRUE,
      sort = FALSE
    )
    lookup_counts$row_share <- round(lookup_counts$row_count / lookup_counts$split_total, 4)
    lookup_counts
  })

  summary <- do.call(rbind, summaries)
  summary <- summary[order(
    summary$result_state,
    summary$validation_split,
    -summary$row_share
  ), ]
  row.names(summary) <- NULL

  summary
}

create_stage1_result_state_stage2_bridge_recommendation <- function(metrics) {
  test_metrics <- metrics[metrics$validation_split == "test", ]
  weighted_metrics <- test_metrics[
    test_metrics$model_name == "weighted_stage1_result_distribution_bridge",
  ]
  top_metrics <- test_metrics[
    test_metrics$model_name == "top_stage1_result_state_bridge",
  ]
  global_metrics <- test_metrics[test_metrics$model_name == "global_train_win_rate", ]

  data.frame(
    summary_group = c(
      "recommended_bridge",
      "test_metric",
      "test_metric",
      "lift_vs_top_state",
      "lift_vs_global",
      "next_step"
    ),
    summary_item = c(
      "stage1_to_stage2_bridge",
      "weighted_accuracy",
      "weighted_brier_score",
      "weighted_brier_improvement",
      "weighted_brier_improvement",
      "recommendation"
    ),
    value = c(
      "weighted_stage1_result_distribution_bridge",
      weighted_metrics$accuracy,
      weighted_metrics$brier_score,
      top_metrics$brier_score - weighted_metrics$brier_score,
      global_metrics$brier_score - weighted_metrics$brier_score,
      "update_shiny_to_use_result_state_distribution_bridge"
    ),
    stringsAsFactors = FALSE
  )
}

save_stage1_result_state_stage2_bridge_outputs <- function(
  bridge_dataset,
  prediction_output,
  result_bridge_table,
  metrics,
  probability_bins,
  lookup_summary,
  recommendation,
  bridge_dataset_path = "data/cleaned/stage1_result_state_stage2_win_bridge_dataset.csv",
  prediction_output_path = "outputs/prediction/stage1_result_state_stage2_win_bridge_output.csv",
  result_bridge_table_path = "outputs/prediction/stage1_result_state_stage2_win_bridge_table.csv",
  metrics_path = "outputs/prediction/stage1_result_state_stage2_win_bridge_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_result_state_stage2_win_bridge_probability_bins.csv",
  lookup_summary_path = "outputs/prediction/stage1_result_state_stage2_win_bridge_lookup_summary.csv",
  recommendation_path = "outputs/prediction/stage1_result_state_stage2_win_bridge_recommendation.csv"
) {
  for (output_dir in unique(c(
    dirname(bridge_dataset_path),
    dirname(prediction_output_path),
    dirname(result_bridge_table_path),
    dirname(metrics_path),
    dirname(probability_bins_path),
    dirname(lookup_summary_path),
    dirname(recommendation_path)
  ))) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
  }

  write.csv(bridge_dataset, bridge_dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(prediction_output, prediction_output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(result_bridge_table, result_bridge_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(metrics, metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(lookup_summary, lookup_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    bridge_dataset_path = bridge_dataset_path,
    prediction_output_path = prediction_output_path,
    result_bridge_table_path = result_bridge_table_path,
    metrics_path = metrics_path,
    probability_bins_path = probability_bins_path,
    lookup_summary_path = lookup_summary_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  stage1_predictions <- load_stage1_result_state_baseline_predictions()
  stage2_outcome_dataset <- load_stage2_inning_outcome_dataset()
  stage1_bridge_predictions <- prepare_stage1_result_state_predictions_for_bridge(
    stage1_predictions
  )

  bridge_dataset <- build_stage1_result_state_stage2_bridge_dataset(
    stage1_bridge_predictions,
    stage2_outcome_dataset
  )
  bridge_output <- build_stage1_result_state_stage2_win_bridge_output(bridge_dataset)
  prediction_output <- bridge_output$prediction_output
  result_bridge_table <- bridge_output$result_bridge_table
  metrics <- calculate_stage1_result_state_stage2_bridge_metrics(prediction_output)
  probability_bins <- calculate_result_bridge_probability_bins(prediction_output)
  lookup_summary <- summarize_result_bridge_lookup_levels(prediction_output)
  recommendation <- create_stage1_result_state_stage2_bridge_recommendation(metrics)

  output_paths <- save_stage1_result_state_stage2_bridge_outputs(
    bridge_dataset,
    prediction_output,
    result_bridge_table,
    metrics,
    probability_bins,
    lookup_summary,
    recommendation
  )

  test_metrics <- metrics[metrics$validation_split == "test", ]
  weighted_metrics <- test_metrics[
    test_metrics$model_name == "weighted_stage1_result_distribution_bridge",
  ]

  message("Saved Stage 1 result-state Stage 2 bridge output to: ", output_paths$prediction_output_path)
  message("Weighted test accuracy: ", weighted_metrics$accuracy)
  message("Weighted test Brier score: ", weighted_metrics$brier_score)
}
