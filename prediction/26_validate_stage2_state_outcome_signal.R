#!/usr/bin/env Rscript

# Validate Stage 2 state label signal against future outcomes.
# Run from the project root:
# Rscript prediction/26_validate_stage2_state_outcome_signal.R

source("prediction/09_build_stage1_frequency_baseline.R")

load_stage2_inning_outcome_dataset <- function(
  input_path = "data/cleaned/stage2_inning_outcome_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 2 inning outcome dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

prepare_stage2_signal_dataset <- function(stage2_dataset) {
  required_columns <- c(
    "score_state",
    "momentum_state",
    "event_signal",
    "combined_state",
    "state_label",
    "inning_phase",
    "next_inning_scored",
    "team_scores_again_after_current_inning",
    "team_win",
    "remaining_run_diff_after_current_inning",
    "remaining_team_runs_after_current_inning"
  )
  assert_required_columns(stage2_dataset, required_columns)

  logical_columns <- c(
    "next_inning_scored",
    "team_scores_again_after_current_inning",
    "team_win"
  )
  for (column_name in logical_columns) {
    stage2_dataset[[column_name]] <- as.logical(stage2_dataset[[column_name]])
  }

  numeric_columns <- c(
    "remaining_run_diff_after_current_inning",
    "remaining_team_runs_after_current_inning"
  )
  for (column_name in numeric_columns) {
    stage2_dataset[[column_name]] <- as.numeric(stage2_dataset[[column_name]])
  }

  stage2_dataset
}

get_stage2_signal_label_specs <- function() {
  list(
    list(label_name = "score_state", label_column = "score_state"),
    list(label_name = "momentum_state", label_column = "momentum_state"),
    list(label_name = "event_signal", label_column = "event_signal"),
    list(label_name = "combined_state", label_column = "combined_state"),
    list(label_name = "state_label", label_column = "state_label"),
    list(label_name = "inning_phase", label_column = "inning_phase")
  )
}

get_stage2_outcome_specs <- function() {
  list(
    list(
      outcome_name = "team_win",
      outcome_column = "team_win",
      outcome_type = "binary"
    ),
    list(
      outcome_name = "team_scores_again_after_current_inning",
      outcome_column = "team_scores_again_after_current_inning",
      outcome_type = "binary"
    ),
    list(
      outcome_name = "next_inning_scored",
      outcome_column = "next_inning_scored",
      outcome_type = "binary"
    ),
    list(
      outcome_name = "remaining_run_diff_after_current_inning",
      outcome_column = "remaining_run_diff_after_current_inning",
      outcome_type = "numeric"
    ),
    list(
      outcome_name = "remaining_team_runs_after_current_inning",
      outcome_column = "remaining_team_runs_after_current_inning",
      outcome_type = "numeric"
    )
  )
}

summarize_one_label_outcome <- function(
  stage2_dataset,
  label_name,
  label_column,
  outcome_name,
  outcome_column,
  outcome_type,
  minimum_group_rows = 20
) {
  group_summary <- aggregate(
    stage2_dataset[[outcome_column]],
    by = list(label_value = stage2_dataset[[label_column]]),
    FUN = mean
  )
  names(group_summary)[2] <- "outcome_mean"

  group_counts <- as.data.frame(table(
    stage2_dataset[[label_column]]
  ), stringsAsFactors = FALSE)
  names(group_counts) <- c("label_value", "row_count")

  group_summary <- merge(
    group_summary,
    group_counts,
    by = "label_value",
    all.x = TRUE,
    sort = FALSE
  )
  group_summary <- group_summary[group_summary$row_count >= minimum_group_rows, ]

  group_summary$label_name <- label_name
  group_summary$label_column <- label_column
  group_summary$outcome_name <- outcome_name
  group_summary$outcome_column <- outcome_column
  group_summary$outcome_type <- outcome_type
  group_summary$outcome_mean <- round(group_summary$outcome_mean, 4)
  group_summary$row_share <- round(group_summary$row_count / nrow(stage2_dataset), 4)

  group_summary <- group_summary[, c(
    "label_name",
    "label_column",
    "label_value",
    "row_count",
    "row_share",
    "outcome_name",
    "outcome_type",
    "outcome_mean"
  )]

  group_summary[order(
    group_summary$label_name,
    group_summary$outcome_name,
    -group_summary$outcome_mean,
    -group_summary$row_count
  ), ]
}

build_stage2_label_outcome_summary <- function(stage2_dataset) {
  label_specs <- get_stage2_signal_label_specs()
  outcome_specs <- get_stage2_outcome_specs()

  summaries <- list()
  summary_index <- 1

  for (label_spec in label_specs) {
    for (outcome_spec in outcome_specs) {
      summaries[[summary_index]] <- summarize_one_label_outcome(
        stage2_dataset = stage2_dataset,
        label_name = label_spec$label_name,
        label_column = label_spec$label_column,
        outcome_name = outcome_spec$outcome_name,
        outcome_column = outcome_spec$outcome_column,
        outcome_type = outcome_spec$outcome_type
      )
      summary_index <- summary_index + 1
    }
  }

  do.call(rbind, summaries)
}

build_stage2_signal_strength_summary <- function(label_outcome_summary) {
  grouped <- split(
    label_outcome_summary,
    paste(
      label_outcome_summary$label_name,
      label_outcome_summary$outcome_name,
      sep = "__"
    )
  )

  signal_rows <- lapply(grouped, function(group_data) {
    data.frame(
      label_name = group_data$label_name[1],
      outcome_name = group_data$outcome_name[1],
      outcome_type = group_data$outcome_type[1],
      group_count = nrow(group_data),
      total_rows_in_groups = sum(group_data$row_count),
      min_outcome_mean = min(group_data$outcome_mean, na.rm = TRUE),
      max_outcome_mean = max(group_data$outcome_mean, na.rm = TRUE),
      outcome_spread = max(group_data$outcome_mean, na.rm = TRUE) -
        min(group_data$outcome_mean, na.rm = TRUE),
      weighted_sd = sqrt(weighted.mean(
        (group_data$outcome_mean - weighted.mean(
          group_data$outcome_mean,
          group_data$row_count
        )) ^ 2,
        group_data$row_count
      )),
      stringsAsFactors = FALSE
    )
  })

  signal_summary <- do.call(rbind, signal_rows)
  numeric_columns <- c(
    "min_outcome_mean",
    "max_outcome_mean",
    "outcome_spread",
    "weighted_sd"
  )
  for (column_name in numeric_columns) {
    signal_summary[[column_name]] <- round(signal_summary[[column_name]], 4)
  }

  signal_summary[order(
    signal_summary$outcome_name,
    -signal_summary$outcome_spread,
    -signal_summary$weighted_sd
  ), ]
}

build_stage2_target_recommendation <- function(signal_strength_summary) {
  target_order <- c(
    "team_win",
    "remaining_run_diff_after_current_inning",
    "team_scores_again_after_current_inning",
    "next_inning_scored",
    "remaining_team_runs_after_current_inning"
  )

  recommendation_rows <- lapply(target_order, function(outcome_name) {
    outcome_rows <- signal_strength_summary[
      signal_strength_summary$outcome_name == outcome_name,
    ]
    best_row <- outcome_rows[which.max(outcome_rows$outcome_spread), ]

    data.frame(
      outcome_name = outcome_name,
      best_label_name = best_row$label_name,
      best_outcome_spread = best_row$outcome_spread,
      best_weighted_sd = best_row$weighted_sd,
      note = ifelse(
        outcome_name == "team_win",
        "Primary Stage 2 classification target candidate",
        ifelse(
          outcome_name == "remaining_run_diff_after_current_inning",
          "Primary Stage 2 numeric target candidate",
          ifelse(
            outcome_name == "next_inning_scored",
            "Weak short-horizon scoring target",
            "Secondary target candidate"
          )
        )
      ),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, recommendation_rows)
}

save_stage2_signal_outputs <- function(
  label_outcome_summary,
  signal_strength_summary,
  target_recommendation,
  label_outcome_summary_path = "outputs/prediction/stage2_label_outcome_summary.csv",
  signal_strength_summary_path = "outputs/prediction/stage2_signal_strength_summary.csv",
  target_recommendation_path = "outputs/prediction/stage2_target_recommendation.csv"
) {
  output_dir <- dirname(label_outcome_summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(label_outcome_summary, label_outcome_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(signal_strength_summary, signal_strength_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(target_recommendation, target_recommendation_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    label_outcome_summary_path = label_outcome_summary_path,
    signal_strength_summary_path = signal_strength_summary_path,
    target_recommendation_path = target_recommendation_path
  )
}

if (sys.nframe() == 0) {
  stage2_dataset <- load_stage2_inning_outcome_dataset()
  signal_dataset <- prepare_stage2_signal_dataset(stage2_dataset)

  label_outcome_summary <- build_stage2_label_outcome_summary(signal_dataset)
  signal_strength_summary <- build_stage2_signal_strength_summary(
    label_outcome_summary
  )
  target_recommendation <- build_stage2_target_recommendation(
    signal_strength_summary
  )

  output_paths <- save_stage2_signal_outputs(
    label_outcome_summary,
    signal_strength_summary,
    target_recommendation
  )

  message("Saved Stage 2 label outcome summary to: ", output_paths$label_outcome_summary_path)
  message("Saved Stage 2 signal strength summary to: ", output_paths$signal_strength_summary_path)
  message("Saved Stage 2 target recommendation to: ", output_paths$target_recommendation_path)
}
