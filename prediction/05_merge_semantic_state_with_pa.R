#!/usr/bin/env Rscript

# Merge inning-level semantic states into the PA-level baseball state dataset.
# Run from the project root:
# Rscript prediction/05_merge_semantic_state_with_pa.R

load_pa_run_value <- function(
  input_path = "data/cleaned/pa_baseball_state_run_value.csv"
) {
  if (!file.exists(input_path)) {
    stop("PA baseball state run value file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_team_inning_state_labeled <- function(
  input_path = "data/cleaned/team_inning_state_labeled.csv"
) {
  if (!file.exists(input_path)) {
    stop("Team-inning semantic state file not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

prepare_semantic_state_lookup <- function(
  team_inning_state_labeled,
  prefix,
  inning_offset = 0
) {
  semantic_columns <- c(
    "game_id",
    "team",
    "inning",
    "score_state",
    "score_state_zh",
    "momentum_state",
    "momentum_state_zh",
    "event_signal",
    "event_signal_zh",
    "combined_state",
    "combined_state_zh"
  )

  lookup <- team_inning_state_labeled[, semantic_columns]
  lookup$batting_team <- lookup$team
  lookup$join_inning <- lookup$inning + inning_offset
  lookup$team <- NULL
  lookup$inning <- NULL

  state_columns <- c(
    "score_state",
    "score_state_zh",
    "momentum_state",
    "momentum_state_zh",
    "event_signal",
    "event_signal_zh",
    "combined_state",
    "combined_state_zh"
  )

  names(lookup)[names(lookup) %in% state_columns] <- paste0(
    prefix,
    names(lookup)[names(lookup) %in% state_columns]
  )

  lookup
}

merge_before_inning_semantic_state <- function(
  pa_run_value,
  team_inning_state_labeled
) {
  before_lookup <- prepare_semantic_state_lookup(
    team_inning_state_labeled,
    prefix = "before_",
    inning_offset = 1
  )

  pa_run_value$row_id <- seq_len(nrow(pa_run_value))
  merged <- merge(
    pa_run_value,
    before_lookup,
    by.x = c("game_id", "batting_team", "inning"),
    by.y = c("game_id", "batting_team", "join_inning"),
    all.x = TRUE,
    sort = FALSE
  )
  merged <- merged[order(merged$row_id), ]

  before_columns <- c(
    "before_score_state",
    "before_score_state_zh",
    "before_momentum_state",
    "before_momentum_state_zh",
    "before_event_signal",
    "before_event_signal_zh",
    "before_combined_state",
    "before_combined_state_zh"
  )

  for (column_name in before_columns) {
    merged[[column_name]][is.na(merged[[column_name]])] <- "game_start"
  }

  merged
}

merge_inning_end_semantic_state <- function(
  pa_with_before_state,
  team_inning_state_labeled
) {
  inning_end_lookup <- prepare_semantic_state_lookup(
    team_inning_state_labeled,
    prefix = "inning_end_",
    inning_offset = 0
  )

  merged <- merge(
    pa_with_before_state,
    inning_end_lookup,
    by.x = c("game_id", "batting_team", "inning"),
    by.y = c("game_id", "batting_team", "join_inning"),
    all.x = TRUE,
    sort = FALSE
  )
  merged <- merged[order(merged$row_id), ]
  merged$row_id <- NULL

  merged
}

save_pa_context_state_dataset <- function(
  pa_context_state_dataset,
  output_path = "data/cleaned/pa_context_state_dataset.csv"
) {
  output_dir <- dirname(output_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(pa_context_state_dataset, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  output_path
}

if (sys.nframe() == 0) {
  pa_run_value <- load_pa_run_value()
  team_inning_state_labeled <- load_team_inning_state_labeled()

  pa_context_state_dataset <- merge_before_inning_semantic_state(
    pa_run_value,
    team_inning_state_labeled
  )
  pa_context_state_dataset <- merge_inning_end_semantic_state(
    pa_context_state_dataset,
    team_inning_state_labeled
  )
  output_path <- save_pa_context_state_dataset(pa_context_state_dataset)

  message("Saved PA context state dataset to: ", output_path)
  message("Rows: ", nrow(pa_context_state_dataset))
  message("Columns: ", ncol(pa_context_state_dataset))
}
