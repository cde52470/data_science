#!/usr/bin/env Rscript

# Build explicit transition targets for future Markov / context-dependent models.
# Run from the project root:
# Rscript prediction/06_build_transition_targets.R

load_pa_context_state_dataset <- function(
  input_path = "data/cleaned/pa_context_state_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("PA context state dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

add_transition_targets <- function(pa_context_state_dataset) {
  pa_context_state_dataset$current_base_out_state <- (
    pa_context_state_dataset$base_out_state_before
  )
  pa_context_state_dataset$next_base_out_state <- (
    pa_context_state_dataset$base_out_state_after
  )
  pa_context_state_dataset$transition_value_label <- (
    pa_context_state_dataset$run_value_label
  )
  pa_context_state_dataset$target_inning_end_score_state <- (
    pa_context_state_dataset$inning_end_score_state
  )
  pa_context_state_dataset$target_inning_end_momentum_state <- (
    pa_context_state_dataset$inning_end_momentum_state
  )
  pa_context_state_dataset$target_inning_end_event_signal <- (
    pa_context_state_dataset$inning_end_event_signal
  )
  pa_context_state_dataset$target_inning_end_combined_state <- (
    pa_context_state_dataset$inning_end_combined_state
  )

  pa_context_state_dataset
}

create_distribution <- function(data, column_name, top_n = NULL) {
  counts <- as.data.frame(table(data[[column_name]], useNA = "ifany"))
  names(counts) <- c("value", "count")
  counts$proportion <- counts$count / sum(counts$count)
  counts$target_field <- column_name
  counts <- counts[order(-counts$count), c("target_field", "value", "count", "proportion")]

  if (!is.null(top_n)) {
    counts <- head(counts, top_n)
  }

  counts
}

create_transition_target_summary <- function(pa_transition_target_dataset) {
  summaries <- list(
    create_distribution(pa_transition_target_dataset, "current_base_out_state"),
    create_distribution(pa_transition_target_dataset, "next_base_out_state"),
    create_distribution(pa_transition_target_dataset, "transition_value_label"),
    create_distribution(
      pa_transition_target_dataset,
      "target_inning_end_combined_state",
      top_n = 30
    )
  )

  do.call(rbind, summaries)
}

save_transition_target_dataset <- function(
  pa_transition_target_dataset,
  transition_target_summary,
  output_path = "data/cleaned/pa_transition_target_dataset.csv",
  summary_path = "outputs/prediction/transition_target_summary.csv"
) {
  output_dir <- dirname(output_path)
  summary_dir <- dirname(summary_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE)
  }

  write.csv(pa_transition_target_dataset, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(transition_target_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    output_path = output_path,
    summary_path = summary_path
  )
}

if (sys.nframe() == 0) {
  pa_context_state_dataset <- load_pa_context_state_dataset()
  pa_transition_target_dataset <- add_transition_targets(pa_context_state_dataset)
  transition_target_summary <- create_transition_target_summary(pa_transition_target_dataset)

  output_paths <- save_transition_target_dataset(
    pa_transition_target_dataset,
    transition_target_summary
  )

  message("Saved PA transition target dataset to: ", output_paths$output_path)
  message("Saved transition target summary to: ", output_paths$summary_path)
  message("Rows: ", nrow(pa_transition_target_dataset))
  message("Columns: ", ncol(pa_transition_target_dataset))
}
