#!/usr/bin/env Rscript

# Merge batter and pitcher context into the Stage 1 transition target dataset.
# Run from the project root:
# Rscript prediction/07_merge_player_context_with_transition_dataset.R

load_transition_target_dataset <- function(
  input_path = "data/cleaned/pa_transition_target_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("PA transition target dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_batter_type_profile <- function(
  input_path = "data/cleaned/batter_type_profile.csv"
) {
  if (!file.exists(input_path)) {
    stop("Batter type profile file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_pitcher_type_profile <- function(
  input_path = "data/cleaned/pitcher_type_profile.csv"
) {
  if (!file.exists(input_path)) {
    stop("Pitcher type profile file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

prepare_batter_context <- function(batter_type_profile) {
  batter_context <- batter_type_profile[, c(
    "batter_name",
    "sample_size_tier",
    "contact_score",
    "power_score",
    "discipline_score",
    "risk_score",
    "run_value_score",
    "batter_primary_type"
  )]

  names(batter_context) <- c(
    "batter_name",
    "batter_sample_size_tier",
    "batter_contact_score",
    "batter_power_score",
    "batter_discipline_score",
    "batter_risk_score",
    "batter_run_value_score",
    "batter_primary_type"
  )

  batter_context
}

prepare_pitcher_context <- function(pitcher_type_profile) {
  pitcher_context <- pitcher_type_profile[, c(
    "pitcher_name",
    "sample_size_tier",
    "strikeout_score",
    "control_score",
    "suppression_score",
    "power_risk_score",
    "run_prevention_score",
    "pitcher_primary_type"
  )]

  names(pitcher_context) <- c(
    "pitcher_name",
    "pitcher_sample_size_tier",
    "pitcher_strikeout_score",
    "pitcher_control_score",
    "pitcher_suppression_score",
    "pitcher_power_risk_score",
    "pitcher_run_prevention_score",
    "pitcher_primary_type"
  )

  pitcher_context
}

merge_player_context <- function(
  transition_target_dataset,
  batter_context,
  pitcher_context
) {
  transition_target_dataset$row_id <- seq_len(nrow(transition_target_dataset))

  merged <- merge(
    transition_target_dataset,
    batter_context,
    by = "batter_name",
    all.x = TRUE,
    sort = FALSE
  )

  merged <- merge(
    merged,
    pitcher_context,
    by = "pitcher_name",
    all.x = TRUE,
    sort = FALSE
  )

  merged <- merged[order(merged$row_id), ]
  merged$row_id <- NULL
  merged
}

create_player_context_missing_summary <- function(stage1_dataset) {
  player_context_columns <- c(
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

  data.frame(
    column = player_context_columns,
    missing_count = sapply(player_context_columns, function(column_name) {
      sum(is.na(stage1_dataset[[column_name]]))
    }),
    stringsAsFactors = FALSE
  )
}

save_stage1_player_context_dataset <- function(
  stage1_dataset,
  missing_summary,
  output_path = "data/cleaned/stage1_transition_player_context_dataset.csv",
  missing_summary_path = "outputs/prediction/stage1_player_context_missing_summary.csv"
) {
  output_dir <- dirname(output_path)
  summary_dir <- dirname(missing_summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE)
  }

  write.csv(stage1_dataset, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(missing_summary, missing_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    output_path = output_path,
    missing_summary_path = missing_summary_path
  )
}

if (sys.nframe() == 0) {
  transition_target_dataset <- load_transition_target_dataset()
  batter_type_profile <- load_batter_type_profile()
  pitcher_type_profile <- load_pitcher_type_profile()

  batter_context <- prepare_batter_context(batter_type_profile)
  pitcher_context <- prepare_pitcher_context(pitcher_type_profile)

  stage1_dataset <- merge_player_context(
    transition_target_dataset,
    batter_context,
    pitcher_context
  )
  missing_summary <- create_player_context_missing_summary(stage1_dataset)

  output_paths <- save_stage1_player_context_dataset(stage1_dataset, missing_summary)

  message("Saved Stage 1 player context dataset to: ", output_paths$output_path)
  message("Saved player context missing summary to: ", output_paths$missing_summary_path)
  message("Rows: ", nrow(stage1_dataset))
  message("Columns: ", ncol(stage1_dataset))
}
