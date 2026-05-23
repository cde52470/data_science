#!/usr/bin/env Rscript

# Build a leakage-safe Stage 1 transition model dataset.
# Run from the project root:
# Rscript prediction/08_build_stage1_model_dataset.R

load_stage1_player_context_dataset <- function(
  input_path = "data/cleaned/stage1_transition_player_context_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 player context dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

assert_required_columns <- function(dataset, required_columns) {
  missing_columns <- setdiff(required_columns, names(dataset))

  if (length(missing_columns) > 0) {
    stop(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }

  invisible(TRUE)
}

get_stage1_identifier_columns <- function() {
  c(
    "game_id",
    "season",
    "date",
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
    "is_pinch_hitter"
  )
}

get_stage1_input_columns <- function() {
  c(
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

get_stage1_target_columns <- function() {
  c(
    "target_inning_end_momentum_state"
  )
}

build_stage1_model_dataset <- function(stage1_player_context_dataset) {
  identifier_columns <- get_stage1_identifier_columns()
  input_columns <- get_stage1_input_columns()
  target_columns <- get_stage1_target_columns()
  selected_columns <- c(identifier_columns, input_columns, target_columns)

  assert_required_columns(stage1_player_context_dataset, selected_columns)

  stage1_model_dataset <- stage1_player_context_dataset[, selected_columns]

  names(stage1_model_dataset)[
    names(stage1_model_dataset) == "target_inning_end_momentum_state"
  ] <- "stage1_target_momentum_state"

  stage1_model_dataset
}

create_stage1_model_dataset_summary <- function(stage1_model_dataset) {
  target_counts <- as.data.frame(table(
    stage1_model_dataset$stage1_target_momentum_state
  ), stringsAsFactors = FALSE)

  names(target_counts) <- c("summary_item", "count")
  target_counts$summary_group <- "target_distribution"
  target_counts$proportion <- round(target_counts$count / nrow(stage1_model_dataset), 4)

  target_counts <- target_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  missing_counts <- data.frame(
    summary_group = "missing_count",
    summary_item = names(stage1_model_dataset),
    count = sapply(stage1_model_dataset, function(column_values) {
      sum(is.na(column_values) | column_values == "")
    }),
    proportion = round(
      sapply(stage1_model_dataset, function(column_values) {
        mean(is.na(column_values) | column_values == "")
      }),
      4
    ),
    stringsAsFactors = FALSE
  )

  metadata <- data.frame(
    summary_group = "metadata",
    summary_item = c("rows", "columns"),
    count = c(nrow(stage1_model_dataset), ncol(stage1_model_dataset)),
    proportion = NA_real_,
    stringsAsFactors = FALSE
  )

  rbind(metadata, target_counts, missing_counts)
}

save_stage1_model_dataset <- function(
  stage1_model_dataset,
  summary,
  output_path = "data/cleaned/stage1_transition_model_dataset.csv",
  summary_path = "outputs/prediction/stage1_model_dataset_summary.csv"
) {
  output_dir <- dirname(output_path)
  summary_dir <- dirname(summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE)
  }

  write.csv(stage1_model_dataset, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    output_path = output_path,
    summary_path = summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_player_context_dataset <- load_stage1_player_context_dataset()

  stage1_model_dataset <- build_stage1_model_dataset(stage1_player_context_dataset)
  summary <- create_stage1_model_dataset_summary(stage1_model_dataset)

  output_paths <- save_stage1_model_dataset(stage1_model_dataset, summary)

  message("Saved Stage 1 model dataset to: ", output_paths$output_path)
  message("Saved Stage 1 model dataset summary to: ", output_paths$summary_path)
  message("Rows: ", nrow(stage1_model_dataset))
  message("Columns: ", ncol(stage1_model_dataset))
}
