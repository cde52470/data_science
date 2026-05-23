#!/usr/bin/env Rscript

# Validate context bridge at team-inning level.
# Run from the project root:
# Rscript prediction/42_validate_context_bridge_team_inning_level.R

load_context_bridge_output <- function(
  input_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_output.csv"
) {
  if (!file.exists(input_path)) {
    stop("Context bridge output not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

assert_required_columns <- function(dataset, required_columns) {
  missing_columns <- setdiff(required_columns, names(dataset))

  if (length(missing_columns) > 0) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }

  invisible(TRUE)
}

first_value <- function(values) {
  values[1]
}

last_value <- function(values) {
  values[length(values)]
}

most_severe_scoring_chance <- function(scoring_chance_state) {
  severity_order <- c(
    "low_scoring_chance" = 1,
    "medium_scoring_chance" = 2,
    "high_scoring_chance" = 3
  )
  scored_values <- severity_order[scoring_chance_state]
  scoring_chance_state[which.max(scored_values)]
}

build_context_bridge_team_inning_dataset <- function(context_output) {
  required_columns <- c(
    "game_id",
    "season",
    "date",
    "game_date",
    "validation_split",
    "stadium",
    "inning",
    "batting_team",
    "fielding_team",
    "is_home_batting",
    "home_away_context",
    "pa_order",
    "score_diff_before",
    "score_diff_bucket",
    "stage1_scoring_probability",
    "stage1_scoring_chance_state",
    "stage2_inning_phase",
    "stage2_score_state",
    "stage2_combined_state",
    "stage2_momentum_state",
    "stage2_run_diff_now",
    "stage2_team_win",
    "context_bridge_win_probability"
  )
  assert_required_columns(context_output, required_columns)

  sorted_output <- context_output[order(
    context_output$game_id,
    context_output$inning,
    context_output$batting_team,
    context_output$pa_order
  ), ]

  group_key <- paste(
    sorted_output$game_id,
    sorted_output$inning,
    sorted_output$batting_team,
    sep = "||"
  )

  team_inning_rows <- lapply(split(seq_len(nrow(sorted_output)), group_key), function(row_indices) {
    group_data <- sorted_output[row_indices, ]
    max_stage1_index <- which.max(group_data$stage1_scoring_probability)
    max_bridge_index <- which.max(group_data$context_bridge_win_probability)

    data.frame(
      game_id = group_data$game_id[1],
      season = group_data$season[1],
      date = group_data$date[1],
      game_date = group_data$game_date[1],
      validation_split = group_data$validation_split[1],
      stadium = group_data$stadium[1],
      inning = group_data$inning[1],
      batting_team = group_data$batting_team[1],
      fielding_team = group_data$fielding_team[1],
      is_home_batting = group_data$is_home_batting[1],
      home_away_context = group_data$home_away_context[1],
      pa_count_in_team_inning = nrow(group_data),
      first_pa_order = group_data$pa_order[1],
      last_pa_order = group_data$pa_order[nrow(group_data)],
      first_pa_score_diff_before = group_data$score_diff_before[1],
      first_pa_score_diff_bucket = group_data$score_diff_bucket[1],
      max_stage1_scoring_chance_state = most_severe_scoring_chance(
        group_data$stage1_scoring_chance_state
      ),
      max_stage1_scoring_probability = max(group_data$stage1_scoring_probability, na.rm = TRUE),
      mean_stage1_scoring_probability = mean(group_data$stage1_scoring_probability, na.rm = TRUE),
      first_context_bridge_win_probability =
        group_data$context_bridge_win_probability[1],
      max_stage1_context_bridge_win_probability =
        group_data$context_bridge_win_probability[max_stage1_index],
      max_context_bridge_win_probability =
        group_data$context_bridge_win_probability[max_bridge_index],
      mean_context_bridge_win_probability =
        mean(group_data$context_bridge_win_probability, na.rm = TRUE),
      stage2_inning_phase = group_data$stage2_inning_phase[1],
      stage2_score_state = group_data$stage2_score_state[1],
      stage2_combined_state = group_data$stage2_combined_state[1],
      stage2_momentum_state = group_data$stage2_momentum_state[1],
      stage2_run_diff_now = group_data$stage2_run_diff_now[1],
      stage2_team_win = group_data$stage2_team_win[1],
      stringsAsFactors = FALSE
    )
  })

  team_inning_dataset <- do.call(rbind, team_inning_rows)
  row.names(team_inning_dataset) <- NULL

  probability_columns <- c(
    "first_context_bridge_win_probability",
    "max_stage1_context_bridge_win_probability",
    "max_context_bridge_win_probability",
    "mean_context_bridge_win_probability"
  )
  for (column_name in probability_columns) {
    team_inning_dataset[[paste0(column_name, "_predicted_team_win")]] <-
      team_inning_dataset[[column_name]] >= 0.5
  }

  team_inning_dataset
}

calculate_team_inning_bridge_metrics <- function(team_inning_dataset) {
  probability_specs <- data.frame(
    model_name = c(
      "first_pa_context_bridge",
      "max_stage1_context_bridge",
      "max_context_bridge",
      "mean_context_bridge"
    ),
    probability_column = c(
      "first_context_bridge_win_probability",
      "max_stage1_context_bridge_win_probability",
      "max_context_bridge_win_probability",
      "mean_context_bridge_win_probability"
    ),
    stringsAsFactors = FALSE
  )

  do.call(rbind, lapply(seq_len(nrow(probability_specs)), function(spec_index) {
    spec <- probability_specs[spec_index, ]
    predicted_column <- paste0(spec$probability_column, "_predicted_team_win")

    do.call(rbind, lapply(
      sort(unique(team_inning_dataset$validation_split)),
      function(split_name) {
        split_data <- team_inning_dataset[
          team_inning_dataset$validation_split == split_name,
        ]
        actual <- as.logical(split_data$stage2_team_win)
        predicted <- as.logical(split_data[[predicted_column]])
        probability <- split_data[[spec$probability_column]]

        data.frame(
          model_name = spec$model_name,
          validation_split = split_name,
          row_count = nrow(split_data),
          accuracy = round(mean(actual == predicted, na.rm = TRUE), 6),
          brier_score = round(mean(
            (probability - as.integer(actual)) ^ 2,
            na.rm = TRUE
          ), 6),
          actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
          mean_predicted_win_probability = round(mean(probability, na.rm = TRUE), 6),
          predicted_win_rate = round(mean(predicted, na.rm = TRUE), 6),
          stringsAsFactors = FALSE
        )
      }
    ))
  }))
}

create_team_inning_probability_bins <- function(
  team_inning_dataset,
  probability_column = "first_context_bridge_win_probability",
  bin_count = 10
) {
  team_inning_dataset$probability_bin <- cut(
    team_inning_dataset[[probability_column]],
    breaks = seq(0, 1, length.out = bin_count + 1),
    include.lowest = TRUE
  )

  do.call(rbind, lapply(
    split(team_inning_dataset, list(
      team_inning_dataset$validation_split,
      team_inning_dataset$probability_bin
    ), drop = TRUE),
    function(bin_data) {
      data.frame(
        probability_column = probability_column,
        validation_split = bin_data$validation_split[1],
        probability_bin = as.character(bin_data$probability_bin[1]),
        row_count = nrow(bin_data),
        mean_predicted_win_probability = round(
          mean(bin_data[[probability_column]], na.rm = TRUE),
          6
        ),
        actual_win_rate = round(
          mean(as.logical(bin_data$stage2_team_win), na.rm = TRUE),
          6
        ),
        stringsAsFactors = FALSE
      )
    }
  ))
}

summarize_team_inning_by_group <- function(team_inning_dataset, group_column) {
  required_columns <- c(
    group_column,
    "validation_split",
    "first_context_bridge_win_probability",
    "stage2_team_win"
  )
  assert_required_columns(team_inning_dataset, required_columns)

  do.call(rbind, lapply(
    split(team_inning_dataset, list(
      team_inning_dataset$validation_split,
      team_inning_dataset[[group_column]]
    ), drop = TRUE),
    function(group_data) {
      data.frame(
        group_column = group_column,
        validation_split = group_data$validation_split[1],
        group_value = as.character(group_data[[group_column]][1]),
        row_count = nrow(group_data),
        actual_win_rate = round(mean(as.logical(group_data$stage2_team_win), na.rm = TRUE), 6),
        mean_predicted_win_probability = round(
          mean(group_data$first_context_bridge_win_probability, na.rm = TRUE),
          6
        ),
        stringsAsFactors = FALSE
      )
    }
  ))
}

create_team_inning_group_summary <- function(team_inning_dataset) {
  group_columns <- c(
    "first_pa_score_diff_bucket",
    "home_away_context",
    "stage2_inning_phase",
    "max_stage1_scoring_chance_state"
  )

  do.call(rbind, lapply(group_columns, function(group_column) {
    summarize_team_inning_by_group(team_inning_dataset, group_column)
  }))
}

create_team_inning_validation_recommendation <- function(metrics) {
  test_metrics <- metrics[metrics$validation_split == "test", ]
  best_metric <- test_metrics[order(
    test_metrics$brier_score,
    -test_metrics$accuracy
  ), ][1, ]

  data.frame(
    check_item = c(
      "best_team_inning_model",
      "best_test_accuracy",
      "best_test_brier",
      "recommendation"
    ),
    value = c(
      best_metric$model_name,
      best_metric$accuracy,
      best_metric$brier_score,
      paste0(
        "team_inning_signal_remains_useful_next_step_calibrate_",
        best_metric$model_name
      )
    ),
    stringsAsFactors = FALSE
  )
}

save_team_inning_validation_outputs <- function(
  team_inning_dataset,
  metrics,
  probability_bins,
  group_summary,
  recommendation,
  dataset_path = "data/cleaned/stage1_scoring_stage2_win_context_bridge_team_inning_dataset.csv",
  metrics_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_team_inning_metrics.csv",
  probability_bins_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_team_inning_probability_bins.csv",
  group_summary_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_team_inning_group_summary.csv",
  recommendation_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_team_inning_recommendation.csv"
) {
  for (output_dir in unique(c(
    dirname(dataset_path),
    dirname(metrics_path),
    dirname(probability_bins_path),
    dirname(group_summary_path),
    dirname(recommendation_path)
  ))) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
  }

  write.csv(team_inning_dataset, dataset_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(metrics, metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(group_summary, group_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    dataset_path = dataset_path,
    metrics_path = metrics_path,
    probability_bins_path = probability_bins_path,
    group_summary_path = group_summary_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  context_output <- load_context_bridge_output()
  team_inning_dataset <- build_context_bridge_team_inning_dataset(context_output)
  metrics <- calculate_team_inning_bridge_metrics(team_inning_dataset)
  probability_bins <- create_team_inning_probability_bins(team_inning_dataset)
  group_summary <- create_team_inning_group_summary(team_inning_dataset)
  recommendation <- create_team_inning_validation_recommendation(metrics)

  output_paths <- save_team_inning_validation_outputs(
    team_inning_dataset,
    metrics,
    probability_bins,
    group_summary,
    recommendation
  )

  message("Saved context bridge team-inning dataset to: ", output_paths$dataset_path)
  message("Saved context bridge team-inning metrics to: ", output_paths$metrics_path)
  message("Saved context bridge team-inning probability bins to: ", output_paths$probability_bins_path)
  message("Saved context bridge team-inning group summary to: ", output_paths$group_summary_path)
  message("Saved context bridge team-inning recommendation to: ", output_paths$recommendation_path)
  message("Rows: ", nrow(team_inning_dataset))
  message("Columns: ", ncol(team_inning_dataset))
}
