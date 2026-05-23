#!/usr/bin/env Rscript

# Validate context-aware bridge details.
# Run from the project root:
# Rscript prediction/41_validate_context_bridge_details.R

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

create_context_bridge_probability_bins <- function(
  context_output,
  bin_count = 10
) {
  required_columns <- c(
    "validation_split",
    "context_bridge_win_probability",
    "stage2_team_win",
    "context_bridge_predicted_team_win"
  )
  assert_required_columns(context_output, required_columns)

  context_output$probability_bin <- cut(
    context_output$context_bridge_win_probability,
    breaks = seq(0, 1, length.out = bin_count + 1),
    include.lowest = TRUE
  )

  do.call(rbind, lapply(
    split(context_output, list(
      context_output$validation_split,
      context_output$probability_bin
    ), drop = TRUE),
    function(bin_data) {
      data.frame(
        validation_split = bin_data$validation_split[1],
        probability_bin = as.character(bin_data$probability_bin[1]),
        row_count = nrow(bin_data),
        mean_predicted_win_probability = round(
          mean(bin_data$context_bridge_win_probability, na.rm = TRUE),
          6
        ),
        actual_win_rate = round(
          mean(as.logical(bin_data$stage2_team_win), na.rm = TRUE),
          6
        ),
        predicted_win_rate = round(
          mean(as.logical(bin_data$context_bridge_predicted_team_win), na.rm = TRUE),
          6
        ),
        brier_score = round(mean(
          (
            bin_data$context_bridge_win_probability -
              as.integer(as.logical(bin_data$stage2_team_win))
          ) ^ 2,
          na.rm = TRUE
        ), 6),
        stringsAsFactors = FALSE
      )
    }
  ))
}

summarize_context_bridge_by_group <- function(context_output, group_column) {
  required_columns <- c(
    group_column,
    "validation_split",
    "context_bridge_win_probability",
    "context_bridge_predicted_team_win",
    "stage2_team_win"
  )
  assert_required_columns(context_output, required_columns)

  do.call(rbind, lapply(
    split(context_output, list(
      context_output$validation_split,
      context_output[[group_column]]
    ), drop = TRUE),
    function(group_data) {
      actual <- as.logical(group_data$stage2_team_win)
      predicted <- as.logical(group_data$context_bridge_predicted_team_win)
      probability <- group_data$context_bridge_win_probability

      data.frame(
        group_column = group_column,
        validation_split = group_data$validation_split[1],
        group_value = as.character(group_data[[group_column]][1]),
        row_count = nrow(group_data),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
        mean_predicted_win_probability = round(mean(probability, na.rm = TRUE), 6),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 6),
        brier_score = round(mean(
          (probability - as.integer(actual)) ^ 2,
          na.rm = TRUE
        ), 6),
        stringsAsFactors = FALSE
      )
    }
  ))
}

create_context_bridge_group_summaries <- function(context_output) {
  group_columns <- c(
    "score_diff_bucket",
    "home_away_context",
    "stage2_inning_phase",
    "stage1_scoring_chance_state",
    "context_bridge_lookup_level"
  )

  do.call(rbind, lapply(group_columns, function(group_column) {
    summarize_context_bridge_by_group(context_output, group_column)
  }))
}

create_context_bridge_validation_recommendation <- function(
  metrics,
  probability_bins,
  group_summary
) {
  test_metrics <- metrics[
    metrics$model_name == "context_bridge" &
      metrics$validation_split == "test",
  ]
  test_bins <- probability_bins[
    probability_bins$validation_split == "test",
  ]
  test_bins$calibration_gap <- abs(
    test_bins$mean_predicted_win_probability - test_bins$actual_win_rate
  )

  test_group_summary <- group_summary[
    group_summary$validation_split == "test",
  ]
  test_group_summary$calibration_gap <- abs(
    test_group_summary$mean_predicted_win_probability -
      test_group_summary$actual_win_rate
  )
  largest_group_gap <- test_group_summary[order(
    -test_group_summary$calibration_gap,
    -test_group_summary$row_count
  ), ][1, ]

  data.frame(
    check_item = c(
      "test_accuracy",
      "test_brier_score",
      "max_probability_bin_calibration_gap",
      "largest_group_calibration_gap",
      "largest_group_gap_location",
      "recommendation"
    ),
    value = c(
      test_metrics$accuracy,
      test_metrics$brier_score,
      round(max(test_bins$calibration_gap, na.rm = TRUE), 6),
      round(largest_group_gap$calibration_gap, 6),
      paste(
        largest_group_gap$group_column,
        largest_group_gap$group_value,
        sep = "__"
      ),
      "context_bridge_is_useful_but_needs_calibration_and_team_inning_level_validation"
    ),
    stringsAsFactors = FALSE
  )
}

save_context_bridge_detail_validation_outputs <- function(
  probability_bins,
  group_summary,
  recommendation,
  probability_bins_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_probability_bins.csv",
  group_summary_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_group_summary.csv",
  recommendation_path = "outputs/prediction/stage1_scoring_stage2_win_context_bridge_detail_recommendation.csv"
) {
  output_dir <- dirname(probability_bins_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(probability_bins, probability_bins_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(group_summary, group_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    probability_bins_path = probability_bins_path,
    group_summary_path = group_summary_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  context_output <- load_context_bridge_output()
  metrics <- read.csv(
    "outputs/prediction/stage1_scoring_stage2_win_context_bridge_metrics.csv",
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )

  probability_bins <- create_context_bridge_probability_bins(context_output)
  group_summary <- create_context_bridge_group_summaries(context_output)
  recommendation <- create_context_bridge_validation_recommendation(
    metrics,
    probability_bins,
    group_summary
  )

  output_paths <- save_context_bridge_detail_validation_outputs(
    probability_bins,
    group_summary,
    recommendation
  )

  message("Saved context bridge probability bins to: ", output_paths$probability_bins_path)
  message("Saved context bridge group summary to: ", output_paths$group_summary_path)
  message("Saved context bridge detail recommendation to: ", output_paths$recommendation_path)
}
