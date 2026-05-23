#!/usr/bin/env Rscript

# Build context-aware Stage 1 scoring to Stage 2 win bridge output.
# Run from the project root:
# Rscript prediction/40_build_stage1_scoring_stage2_win_context_bridge.R

source("prediction/39_build_stage1_scoring_stage2_win_bridge_output.R")

bucket_score_diff_for_context_bridge <- function(score_diff_before) {
  ifelse(
    score_diff_before <= -4,
    "big_deficit",
    ifelse(
      score_diff_before <= -2,
      "small_deficit",
      ifelse(
        score_diff_before == -1,
        "one_run_deficit",
        ifelse(
          score_diff_before == 0,
          "tied",
          ifelse(
            score_diff_before == 1,
            "one_run_lead",
            ifelse(score_diff_before <= 3, "small_lead", "big_lead")
          )
        )
      )
    )
  )
}

add_context_bridge_features <- function(bridge_dataset) {
  required_columns <- c(
    "score_diff_before",
    "is_home_batting",
    "stage1_scoring_chance_state",
    "stage2_inning_phase",
    "stage2_score_state"
  )
  assert_required_columns(bridge_dataset, required_columns)

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

get_context_bridge_specs <- function() {
  list(
    list(
      lookup_level = "chance_phase_score_home",
      group_columns = c(
        "stage1_scoring_chance_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context"
      ),
      minimum_group_total = 80
    ),
    list(
      lookup_level = "chance_phase_score",
      group_columns = c(
        "stage1_scoring_chance_state",
        "stage2_inning_phase",
        "score_diff_bucket"
      ),
      minimum_group_total = 80
    ),
    list(
      lookup_level = "chance_phase_stage2_score",
      group_columns = c(
        "stage1_scoring_chance_state",
        "stage2_inning_phase",
        "stage2_score_state"
      ),
      minimum_group_total = 80
    ),
    list(
      lookup_level = "chance_phase",
      group_columns = c(
        "stage1_scoring_chance_state",
        "stage2_inning_phase"
      ),
      minimum_group_total = 1
    ),
    list(
      lookup_level = "chance_only",
      group_columns = c("stage1_scoring_chance_state"),
      minimum_group_total = 1
    )
  )
}

make_context_bridge_key <- function(dataset, group_columns) {
  assert_required_columns(dataset, group_columns)
  apply(dataset[, group_columns, drop = FALSE], 1, paste, collapse = "||")
}

build_one_context_bridge_table <- function(train_dataset, spec) {
  required_columns <- c(spec$group_columns, "stage2_team_win")
  assert_required_columns(train_dataset, required_columns)

  probability_table <- aggregate(
    as.integer(train_dataset$stage2_team_win),
    by = train_dataset[, spec$group_columns, drop = FALSE],
    FUN = mean
  )
  names(probability_table)[ncol(probability_table)] <- "context_bridge_win_probability"

  count_table <- aggregate(
    as.integer(train_dataset$stage2_team_win),
    by = train_dataset[, spec$group_columns, drop = FALSE],
    FUN = length
  )
  names(count_table)[ncol(count_table)] <- "context_bridge_train_rows"

  table_output <- merge(
    probability_table,
    count_table,
    by = spec$group_columns,
    all.x = TRUE,
    sort = FALSE
  )
  table_output$context_bridge_lookup_level <- spec$lookup_level
  table_output$context_bridge_group_columns <- paste(spec$group_columns, collapse = " + ")
  table_output$context_bridge_win_probability <- round(
    table_output$context_bridge_win_probability,
    6
  )

  table_output
}

build_all_context_bridge_tables <- function(train_dataset) {
  tables <- lapply(get_context_bridge_specs(), function(spec) {
    build_one_context_bridge_table(train_dataset, spec)
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

prepare_context_bridge_lookup <- function(context_table, spec) {
  required_columns <- c(
    "context_bridge_lookup_level",
    spec$group_columns,
    "context_bridge_win_probability",
    "context_bridge_train_rows"
  )
  assert_required_columns(context_table, required_columns)

  lookup <- context_table[
    context_table$context_bridge_lookup_level == spec$lookup_level &
      context_table$context_bridge_train_rows >= spec$minimum_group_total,
    required_columns
  ]
  lookup$context_bridge_key <- make_context_bridge_key(lookup, spec$group_columns)
  lookup <- lookup[, c(
    "context_bridge_key",
    "context_bridge_win_probability",
    "context_bridge_train_rows"
  )]

  lookup
}

apply_one_context_bridge_level <- function(prediction_output, context_table, spec) {
  lookup <- prepare_context_bridge_lookup(context_table, spec)
  prediction_output$context_bridge_key <- make_context_bridge_key(
    prediction_output,
    spec$group_columns
  )

  merged <- merge(
    prediction_output,
    lookup,
    by = "context_bridge_key",
    all.x = TRUE,
    sort = FALSE,
    suffixes = c("", "_candidate")
  )

  has_prediction <- is.na(merged$context_bridge_win_probability) &
    !is.na(merged$context_bridge_win_probability_candidate)

  merged$context_bridge_win_probability[has_prediction] <-
    merged$context_bridge_win_probability_candidate[has_prediction]
  merged$context_bridge_train_rows[has_prediction] <-
    merged$context_bridge_train_rows_candidate[has_prediction]
  merged$context_bridge_lookup_level[has_prediction] <- spec$lookup_level

  merged$context_bridge_win_probability_candidate <- NULL
  merged$context_bridge_train_rows_candidate <- NULL
  merged$context_bridge_key <- NULL

  merged
}

build_context_bridge_prediction_output <- function(bridge_dataset) {
  bridge_dataset <- add_context_bridge_features(bridge_dataset)
  train_dataset <- bridge_dataset[bridge_dataset$validation_split == "train", ]
  context_table <- build_all_context_bridge_tables(train_dataset)
  global_train_win_rate <- mean(train_dataset$stage2_team_win, na.rm = TRUE)

  keep_columns <- c(
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
    "stage1_scoring_probability",
    "stage1_scoring_chance_state",
    "stage2_inning_phase",
    "stage2_score_state",
    "stage2_combined_state",
    "stage2_momentum_state",
    "stage2_run_diff_now",
    "stage2_team_win"
  )
  assert_required_columns(bridge_dataset, keep_columns)

  prediction_output <- bridge_dataset[, keep_columns]
  prediction_output$context_bridge_win_probability <- NA_real_
  prediction_output$context_bridge_train_rows <- NA_real_
  prediction_output$context_bridge_lookup_level <- NA_character_

  for (spec in get_context_bridge_specs()) {
    prediction_output <- apply_one_context_bridge_level(
      prediction_output,
      context_table,
      spec
    )
  }

  missing_prediction <- is.na(prediction_output$context_bridge_win_probability)
  prediction_output$context_bridge_win_probability[missing_prediction] <-
    global_train_win_rate
  prediction_output$context_bridge_train_rows[missing_prediction] <- nrow(train_dataset)
  prediction_output$context_bridge_lookup_level[missing_prediction] <- "global"

  prediction_output$context_bridge_predicted_team_win <-
    prediction_output$context_bridge_win_probability >= 0.5
  prediction_output$is_correct_context_bridge_win_prediction <- (
    prediction_output$context_bridge_predicted_team_win ==
      as.logical(prediction_output$stage2_team_win)
  )

  list(
    prediction_output = prediction_output,
    context_table = context_table
  )
}

calculate_context_bridge_metrics <- function(prediction_output) {
  train_win_rate <- mean(
    as.logical(prediction_output$stage2_team_win[
      prediction_output$validation_split == "train"
    ]),
    na.rm = TRUE
  )

  context_metrics <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[prediction_output$validation_split == split_name, ]
      actual <- as.logical(split_data$stage2_team_win)
      predicted <- as.logical(split_data$context_bridge_predicted_team_win)
      probability <- split_data$context_bridge_win_probability

      data.frame(
        model_name = "context_bridge",
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 6),
        brier_score = round(mean((probability - as.integer(actual)) ^ 2), 6),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
        mean_predicted_win_probability = round(mean(probability, na.rm = TRUE), 6),
        predicted_win_rate = round(mean(predicted, na.rm = TRUE), 6),
        stringsAsFactors = FALSE
      )
    }
  ))

  global_metrics <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[prediction_output$validation_split == split_name, ]
      actual <- as.logical(split_data$stage2_team_win)
      probability <- rep(train_win_rate, nrow(split_data))
      predicted <- probability >= 0.5

      data.frame(
        model_name = "global_train_win_rate",
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 6),
        brier_score = round(mean((probability - as.integer(actual)) ^ 2), 6),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
        mean_predicted_win_probability = round(mean(probability), 6),
        predicted_win_rate = round(mean(predicted), 6),
        stringsAsFactors = FALSE
      )
    }
  ))

  rbind(context_metrics, global_metrics)
}

summarize_context_bridge_lookup_levels <- function(prediction_output) {
  lookup_counts <- as.data.frame(table(
    prediction_output$validation_split,
    prediction_output$context_bridge_lookup_level
  ), stringsAsFactors = FALSE)
  names(lookup_counts) <- c("validation_split", "context_bridge_lookup_level", "row_count")

  lookup_counts$proportion <- NA_real_
  for (split_name in unique(lookup_counts$validation_split)) {
    split_total <- sum(prediction_output$validation_split == split_name)
    lookup_counts$proportion[
      lookup_counts$validation_split == split_name
    ] <- round(
      lookup_counts$row_count[lookup_counts$validation_split == split_name] /
        split_total,
      6
    )
  }

  lookup_counts[order(lookup_counts$validation_split, -lookup_counts$row_count), ]
}

save_context_bridge_outputs <- function(
  prediction_output,
  context_table,
  metrics,
  lookup_summary,
  prediction_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_output.csv",
  context_table_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_table.csv",
  metrics_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_metrics.csv",
  lookup_summary_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_lookup_summary.csv"
) {
  output_dir <- dirname(prediction_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_output, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(context_table, context_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(metrics, metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(lookup_summary, lookup_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    context_table_path = context_table_path,
    metrics_path = metrics_path,
    lookup_summary_path = lookup_summary_path
  )
}

if (sys.nframe() == 0) {
  bridge_dataset <- load_stage1_stage2_scoring_bridge_dataset()
  result <- build_context_bridge_prediction_output(bridge_dataset)
  metrics <- calculate_context_bridge_metrics(result$prediction_output)
  lookup_summary <- summarize_context_bridge_lookup_levels(result$prediction_output)

  output_paths <- save_context_bridge_outputs(
    result$prediction_output,
    result$context_table,
    metrics,
    lookup_summary
  )

  message("Saved context bridge output to: ", output_paths$prediction_path)
  message("Saved context bridge table to: ", output_paths$context_table_path)
  message("Saved context bridge metrics to: ", output_paths$metrics_path)
  message("Saved context bridge lookup summary to: ", output_paths$lookup_summary_path)
  message("Rows: ", nrow(result$prediction_output))
  message("Columns: ", ncol(result$prediction_output))
}
