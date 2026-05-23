#!/usr/bin/env Rscript

# Validate Stage 1 scoring prediction patterns.
# Run from the project root:
# Rscript prediction/37_validate_stage1_scoring_prediction_patterns.R

load_stage1_scoring_prediction_output <- function(
  input_path = "outputs/prediction/stage1_scoring_prediction_output.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 scoring prediction output not found: ", input_path)
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

add_inning_phase_for_scoring_validation <- function(prediction_output) {
  assert_required_columns(prediction_output, "inning")

  prediction_output$inning_phase <- ifelse(
    prediction_output$inning <= 3,
    "early",
    ifelse(
      prediction_output$inning <= 6,
      "middle",
      ifelse(prediction_output$inning <= 9, "late", "extra")
    )
  )

  prediction_output
}

summarize_scoring_pattern_by_group <- function(
  prediction_output,
  group_column,
  minimum_rows = 50
) {
  required_columns <- c(
    group_column,
    "stage1_scoring_probability",
    "stage1_scoring_flag_threshold_030",
    "stage1_scoring_chance_state",
    "will_score_from_current_pa"
  )
  assert_required_columns(prediction_output, required_columns)

  group_values <- prediction_output[[group_column]]
  row_counts <- as.data.frame(table(group_values), stringsAsFactors = FALSE)
  names(row_counts) <- c(group_column, "row_count")
  row_counts <- row_counts[row_counts$row_count >= minimum_rows, ]

  if (nrow(row_counts) == 0) {
    return(data.frame())
  }

  probability_summary <- aggregate(
    cbind(
      mean_scoring_probability = prediction_output$stage1_scoring_probability,
      actual_scoring_rate = prediction_output$will_score_from_current_pa,
      predicted_high_flag_rate = prediction_output$stage1_scoring_flag_threshold_030
    ),
    by = list(group_value = group_values),
    FUN = mean
  )
  probability_summary[, c(
    "mean_scoring_probability",
    "actual_scoring_rate",
    "predicted_high_flag_rate"
  )] <- round(probability_summary[, c(
    "mean_scoring_probability",
    "actual_scoring_rate",
    "predicted_high_flag_rate"
  )], 6)

  high_state_rate <- aggregate(
    as.integer(prediction_output$stage1_scoring_chance_state == "high_scoring_chance"),
    by = list(group_value = group_values),
    FUN = mean
  )
  names(high_state_rate)[2] <- "high_scoring_chance_rate"
  high_state_rate$high_scoring_chance_rate <- round(
    high_state_rate$high_scoring_chance_rate,
    6
  )

  names(row_counts)[1] <- "group_value"
  pattern_summary <- merge(row_counts, probability_summary, by = "group_value")
  pattern_summary <- merge(pattern_summary, high_state_rate, by = "group_value")
  pattern_summary$group_column <- group_column
  pattern_summary <- pattern_summary[, c(
    "group_column",
    "group_value",
    "row_count",
    "mean_scoring_probability",
    "actual_scoring_rate",
    "predicted_high_flag_rate",
    "high_scoring_chance_rate"
  )]

  pattern_summary[order(
    pattern_summary$group_column,
    -pattern_summary$mean_scoring_probability,
    -pattern_summary$row_count
  ), ]
}

summarize_scoring_state_by_group <- function(
  prediction_output,
  group_column,
  minimum_rows = 50
) {
  required_columns <- c(group_column, "stage1_scoring_chance_state")
  assert_required_columns(prediction_output, required_columns)

  state_counts <- as.data.frame(table(
    prediction_output[[group_column]],
    prediction_output$stage1_scoring_chance_state
  ), stringsAsFactors = FALSE)
  names(state_counts) <- c("group_value", "scoring_chance_state", "row_count")

  group_totals <- aggregate(
    state_counts$row_count,
    by = list(group_value = state_counts$group_value),
    FUN = sum
  )
  names(group_totals)[2] <- "group_total"

  state_distribution <- merge(
    state_counts,
    group_totals,
    by = "group_value",
    all.x = TRUE,
    sort = FALSE
  )
  state_distribution <- state_distribution[state_distribution$group_total >= minimum_rows, ]
  state_distribution$state_share <- round(
    state_distribution$row_count / state_distribution$group_total,
    6
  )
  state_distribution$group_column <- group_column

  state_distribution <- state_distribution[, c(
    "group_column",
    "group_value",
    "scoring_chance_state",
    "row_count",
    "group_total",
    "state_share"
  )]

  state_distribution[order(
    state_distribution$group_column,
    state_distribution$group_value,
    state_distribution$scoring_chance_state
  ), ]
}

create_stage1_scoring_pattern_summaries <- function(prediction_output) {
  prediction_output <- add_inning_phase_for_scoring_validation(prediction_output)
  validation_dataset <- prediction_output[
    prediction_output$validation_split == "test",
  ]

  group_columns <- c(
    "current_base_out_state",
    "batter_primary_type",
    "pitcher_primary_type",
    "before_score_state",
    "before_momentum_state",
    "inning_phase"
  )

  pattern_summary <- do.call(rbind, lapply(group_columns, function(group_column) {
    summarize_scoring_pattern_by_group(
      validation_dataset,
      group_column = group_column,
      minimum_rows = 30
    )
  }))

  state_distribution <- do.call(rbind, lapply(group_columns, function(group_column) {
    summarize_scoring_state_by_group(
      validation_dataset,
      group_column = group_column,
      minimum_rows = 30
    )
  }))

  list(
    pattern_summary = pattern_summary,
    state_distribution = state_distribution
  )
}

create_stage1_scoring_pattern_recommendation <- function(pattern_summary) {
  base_out_summary <- pattern_summary[
    pattern_summary$group_column == "current_base_out_state",
  ]
  top_base_out <- base_out_summary[order(
    -base_out_summary$mean_scoring_probability
  ), ][1, ]
  bottom_base_out <- base_out_summary[order(
    base_out_summary$mean_scoring_probability
  ), ][1, ]

  data.frame(
    check_item = c(
      "top_base_out_state",
      "bottom_base_out_state",
      "base_out_probability_spread",
      "recommendation"
    ),
    value = c(
      top_base_out$group_value,
      bottom_base_out$group_value,
      round(
        top_base_out$mean_scoring_probability -
          bottom_base_out$mean_scoring_probability,
        6
      ),
      "stage1_scoring_patterns_are_directionally_reasonable_validate_more_before_stage2_integration"
    ),
    stringsAsFactors = FALSE
  )
}

save_stage1_scoring_pattern_validation_outputs <- function(
  pattern_summary,
  state_distribution,
  recommendation,
  pattern_summary_path = "outputs/prediction/stage1_scoring_prediction_pattern_summary.csv",
  state_distribution_path = "outputs/prediction/stage1_scoring_prediction_state_distribution.csv",
  recommendation_path = "outputs/prediction/stage1_scoring_prediction_pattern_recommendation.csv"
) {
  output_dir <- dirname(pattern_summary_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(pattern_summary, pattern_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(state_distribution, state_distribution_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(recommendation, recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    pattern_summary_path = pattern_summary_path,
    state_distribution_path = state_distribution_path,
    recommendation_path = recommendation_path
  )
}

if (sys.nframe() == 0) {
  prediction_output <- load_stage1_scoring_prediction_output()
  summaries <- create_stage1_scoring_pattern_summaries(prediction_output)
  recommendation <- create_stage1_scoring_pattern_recommendation(
    summaries$pattern_summary
  )

  output_paths <- save_stage1_scoring_pattern_validation_outputs(
    summaries$pattern_summary,
    summaries$state_distribution,
    recommendation
  )

  message("Saved Stage 1 scoring pattern summary to: ", output_paths$pattern_summary_path)
  message("Saved Stage 1 scoring state distribution to: ", output_paths$state_distribution_path)
  message("Saved Stage 1 scoring pattern recommendation to: ", output_paths$recommendation_path)
}
