#!/usr/bin/env Rscript

# Build Stage 1 scoring prediction output.
# Run from the project root:
# Rscript prediction/36_build_stage1_scoring_prediction_output.R

source("prediction/35_tune_stage1_inning_scoring_threshold.R")

get_stage1_scoring_prediction_threshold <- function(
  recommendation_path = "outputs/prediction/stage1_inning_scoring_threshold_recommendation.csv"
) {
  if (!file.exists(recommendation_path)) {
    stop("Stage 1 scoring threshold recommendation not found: ", recommendation_path)
  }

  recommendation <- read.csv(
    recommendation_path,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )
  as.numeric(recommendation$threshold[1])
}

build_stage1_scoring_prediction_output <- function(
  logistic_predictions,
  recommended_threshold = get_stage1_scoring_prediction_threshold(),
  low_threshold = 0.20,
  high_threshold = 0.35
) {
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
    "pa_order",
    "pa_round",
    "batter_name",
    "pitcher_name",
    "batter_hand",
    "pitcher_hand",
    "is_pinch_hitter",
    "before_score_state",
    "before_momentum_state",
    "before_event_signal",
    "before_combined_state",
    "current_base_out_state",
    "outs_before",
    "bases_before",
    "base_occupancy_before",
    "score_diff_before",
    "batting_score_before",
    "fielding_score_before",
    "run_expectancy_before",
    "batter_primary_type",
    "batter_sample_size_tier",
    "pitcher_primary_type",
    "pitcher_sample_size_tier",
    "runs_from_current_pa_to_inning_end",
    "will_score_from_current_pa",
    "current_pa_scores",
    "pa_hit",
    "pa_extra_base_hit",
    "pa_home_run",
    "pa_hit_or_walk",
    "pa_positive_run_value",
    "target_inning_end_score_state",
    "target_inning_end_momentum_state",
    "target_inning_end_event_signal",
    "target_inning_end_combined_state",
    "logistic_scoring_probability"
  )
  assert_required_columns(logistic_predictions, keep_columns)

  prediction_output <- logistic_predictions[, keep_columns]
  prediction_output$stage1_scoring_model <- "logistic_regression"
  prediction_output$stage1_scoring_probability <- round(
    prediction_output$logistic_scoring_probability,
    6
  )
  prediction_output$stage1_scoring_recommended_threshold <- recommended_threshold
  prediction_output$stage1_scoring_flag_threshold_030 <- as.integer(
    prediction_output$stage1_scoring_probability >= recommended_threshold
  )
  prediction_output$stage1_scoring_chance_state <- label_scoring_chance_state(
    prediction_output$stage1_scoring_probability,
    low_threshold = low_threshold,
    high_threshold = high_threshold
  )
  prediction_output$stage1_scoring_chance_state_zh <- ifelse(
    prediction_output$stage1_scoring_chance_state == "low_scoring_chance",
    "低得分機會",
    ifelse(
      prediction_output$stage1_scoring_chance_state == "medium_scoring_chance",
      "普通得分機會",
      "高得分機會"
    )
  )
  prediction_output$is_correct_scoring_flag <- (
    prediction_output$stage1_scoring_flag_threshold_030 ==
      prediction_output$will_score_from_current_pa
  )

  prediction_output$logistic_scoring_probability <- NULL

  prediction_output
}

summarize_stage1_scoring_prediction_output <- function(prediction_output) {
  split_rows <- as.data.frame(table(
    prediction_output$validation_split
  ), stringsAsFactors = FALSE)
  names(split_rows) <- c("summary_item", "count")
  split_rows$summary_group <- "split_rows"
  split_rows$proportion <- round(split_rows$count / nrow(prediction_output), 6)

  split_accuracy <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[
        prediction_output$validation_split == split_name,
      ]

      data.frame(
        summary_group = "threshold_030_accuracy",
        summary_item = paste0(split_name, "_accuracy"),
        count = sum(split_data$is_correct_scoring_flag, na.rm = TRUE),
        proportion = round(mean(split_data$is_correct_scoring_flag, na.rm = TRUE), 6),
        stringsAsFactors = FALSE
      )
    }
  ))

  state_distribution <- as.data.frame(table(
    prediction_output$validation_split,
    prediction_output$stage1_scoring_chance_state
  ), stringsAsFactors = FALSE)
  names(state_distribution) <- c(
    "validation_split",
    "stage1_scoring_chance_state",
    "count"
  )
  state_distribution$summary_group <- "scoring_chance_state_distribution"
  state_distribution$summary_item <- paste(
    state_distribution$validation_split,
    state_distribution$stage1_scoring_chance_state,
    sep = "__"
  )
  state_distribution$proportion <- NA_real_
  for (split_name in unique(state_distribution$validation_split)) {
    split_total <- sum(prediction_output$validation_split == split_name)
    state_distribution$proportion[
      state_distribution$validation_split == split_name
    ] <- round(
      state_distribution$count[state_distribution$validation_split == split_name] /
        split_total,
      6
    )
  }
  state_distribution <- state_distribution[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  probability_summary <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[
        prediction_output$validation_split == split_name,
      ]

      data.frame(
        summary_group = "scoring_probability",
        summary_item = c(
          paste0(split_name, "_mean_probability"),
          paste0(split_name, "_actual_scoring_rate")
        ),
        count = nrow(split_data),
        proportion = c(
          round(mean(split_data$stage1_scoring_probability), 6),
          round(mean(split_data$will_score_from_current_pa), 6)
        ),
        stringsAsFactors = FALSE
      )
    }
  ))

  rbind(
    split_rows[, c("summary_group", "summary_item", "count", "proportion")],
    split_accuracy[, c("summary_group", "summary_item", "count", "proportion")],
    state_distribution,
    probability_summary
  )
}

save_stage1_scoring_prediction_outputs <- function(
  prediction_output,
  prediction_summary,
  prediction_path = "outputs/prediction/stage1_scoring_prediction_output.csv",
  summary_path = "outputs/prediction/stage1_scoring_prediction_summary.csv"
) {
  output_dir <- dirname(prediction_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_output, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(prediction_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    summary_path = summary_path
  )
}

if (sys.nframe() == 0) {
  logistic_predictions <- load_stage1_scoring_logistic_predictions()
  recommended_threshold <- get_stage1_scoring_prediction_threshold()

  prediction_output <- build_stage1_scoring_prediction_output(
    logistic_predictions,
    recommended_threshold = recommended_threshold
  )
  prediction_summary <- summarize_stage1_scoring_prediction_output(
    prediction_output
  )

  output_paths <- save_stage1_scoring_prediction_outputs(
    prediction_output,
    prediction_summary
  )

  message("Saved Stage 1 scoring prediction output to: ", output_paths$prediction_path)
  message("Saved Stage 1 scoring prediction summary to: ", output_paths$summary_path)
  message("Rows: ", nrow(prediction_output))
  message("Columns: ", ncol(prediction_output))
}
