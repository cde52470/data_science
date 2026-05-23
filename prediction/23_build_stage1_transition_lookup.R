#!/usr/bin/env Rscript

# Build Stage 1 v1 transition lookup helpers and example outputs.
# Run from the project root:
# Rscript prediction/23_build_stage1_transition_lookup.R

source("prediction/22_build_stage1_transition_probability_table.R")

load_stage1_v1_transition_table <- function(
  input_path = "outputs/prediction/stage1_v1_transition_probability_table.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 v1 transition probability table not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_transition_lookup_fallback_specs <- function() {
  list(
    list(
      transition_level = "full_context",
      required_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      )
    ),
    list(
      transition_level = "state_baseout_player_type",
      required_columns = c(
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      )
    ),
    list(
      transition_level = "score_state_baseout",
      required_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state"
      )
    ),
    list(
      transition_level = "state_baseout",
      required_columns = c(
        "before_momentum_state",
        "current_base_out_state"
      )
    )
  )
}

build_context_label_from_row <- function(input_row, required_columns) {
  paste(
    as.character(input_row[required_columns]),
    collapse = " | "
  )
}

lookup_stage1_transition_probability <- function(
  input_row,
  transition_table,
  fallback_specs = get_transition_lookup_fallback_specs()
) {
  for (spec in fallback_specs) {
    if (!all(spec$required_columns %in% names(input_row))) {
      next
    }

    if (any(is.na(input_row[spec$required_columns]))) {
      next
    }

    context_label <- build_context_label_from_row(
      input_row,
      spec$required_columns
    )
    candidate_rows <- transition_table[
      transition_table$transition_level == spec$transition_level &
        transition_table$context_label == context_label,
    ]

    if (nrow(candidate_rows) > 0) {
      candidate_rows$matched_transition_level <- spec$transition_level
      candidate_rows$matched_context_label <- context_label
      candidate_rows$fallback_rank <- which(vapply(
        fallback_specs,
        function(item) item$transition_level == spec$transition_level,
        logical(1)
      ))
      return(candidate_rows[order(-candidate_rows$model_probability), ])
    }
  }

  data.frame()
}

build_stage1_lookup_example_inputs <- function() {
  data.frame(
    example_id = c(
      "full_context_neutral_start",
      "score_state_under_pressure",
      "state_baseout_scoring_pressure",
      "fallback_to_state_baseout"
    ),
    before_score_state = c(
      "tied",
      "big_deficit",
      NA,
      "rare_score_state"
    ),
    before_momentum_state = c(
      "neutral_momentum",
      "under_pressure",
      "scoring_pressure",
      "neutral_momentum"
    ),
    current_base_out_state = c(
      "0_outs_empty",
      "0_outs_1b",
      "0_outs_1b",
      "2_outs_empty"
    ),
    batter_primary_type = c(
      "power_hitter",
      NA,
      NA,
      "rare_hitter_type"
    ),
    pitcher_primary_type = c(
      "balanced_pitcher",
      NA,
      NA,
      "rare_pitcher_type"
    ),
    stringsAsFactors = FALSE
  )
}

format_lookup_result <- function(example_row, lookup_result) {
  if (nrow(lookup_result) == 0) {
    return(data.frame(
      example_id = example_row$example_id,
      matched_transition_level = NA_character_,
      matched_context_label = NA_character_,
      fallback_rank = NA_integer_,
      next_momentum_state = NA_character_,
      model_probability = NA_real_,
      empirical_target_probability = NA_real_,
      predicted_top_share = NA_real_,
      context_total = NA_integer_,
      is_top_state = NA,
      stringsAsFactors = FALSE
    ))
  }

  top_state <- lookup_result$next_momentum_state[
    which.max(lookup_result$model_probability)
  ]
  formatted <- lookup_result[, c(
    "matched_transition_level",
    "matched_context_label",
    "fallback_rank",
    "next_momentum_state",
    "model_probability",
    "empirical_target_probability",
    "predicted_top_share",
    "context_total"
  )]
  formatted$example_id <- example_row$example_id
  formatted$is_top_state <- formatted$next_momentum_state == top_state

  formatted <- formatted[, c(
    "example_id",
    "matched_transition_level",
    "matched_context_label",
    "fallback_rank",
    "next_momentum_state",
    "model_probability",
    "empirical_target_probability",
    "predicted_top_share",
    "context_total",
    "is_top_state"
  )]

  formatted
}

build_stage1_lookup_examples <- function(example_inputs, transition_table) {
  example_results <- lapply(seq_len(nrow(example_inputs)), function(row_index) {
    example_row <- example_inputs[row_index, ]
    lookup_result <- lookup_stage1_transition_probability(
      input_row = example_row,
      transition_table = transition_table
    )

    format_lookup_result(example_row, lookup_result)
  })

  do.call(rbind, example_results)
}

build_stage1_lookup_summary <- function(lookup_examples) {
  matched_rows <- lookup_examples[!is.na(lookup_examples$matched_transition_level), ]

  level_counts <- as.data.frame(table(
    unique(matched_rows[, c("example_id", "matched_transition_level")])$matched_transition_level
  ), stringsAsFactors = FALSE)
  names(level_counts) <- c("summary_item", "count")
  level_counts$summary_group <- "matched_transition_level"
  level_counts$proportion <- round(
    level_counts$count / length(unique(lookup_examples$example_id)),
    4
  )

  top_states <- lookup_examples[lookup_examples$is_top_state %in% TRUE, ]
  top_state_summary <- top_states[, c(
    "example_id",
    "matched_transition_level",
    "next_momentum_state",
    "model_probability",
    "context_total"
  )]
  names(top_state_summary) <- c(
    "summary_item",
    "matched_transition_level",
    "top_state",
    "top_model_probability",
    "context_total"
  )
  top_state_summary$summary_group <- "example_top_state"
  top_state_summary$count <- top_state_summary$context_total
  top_state_summary$proportion <- top_state_summary$top_model_probability
  top_state_summary$value <- paste(
    top_state_summary$matched_transition_level,
    top_state_summary$top_state,
    sep = " -> "
  )

  level_counts$value <- NA_character_
  level_counts <- level_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion",
    "value"
  )]
  top_state_summary <- top_state_summary[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion",
    "value"
  )]

  rbind(level_counts, top_state_summary)
}

save_stage1_lookup_outputs <- function(
  example_inputs,
  lookup_examples,
  lookup_summary,
  example_inputs_path = "outputs/prediction/stage1_v1_transition_lookup_example_inputs.csv",
  lookup_examples_path = "outputs/prediction/stage1_v1_transition_lookup_examples.csv",
  lookup_summary_path = "outputs/prediction/stage1_v1_transition_lookup_summary.csv"
) {
  output_dir <- dirname(lookup_examples_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(example_inputs, example_inputs_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(lookup_examples, lookup_examples_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(lookup_summary, lookup_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    example_inputs_path = example_inputs_path,
    lookup_examples_path = lookup_examples_path,
    lookup_summary_path = lookup_summary_path
  )
}

if (sys.nframe() == 0) {
  transition_table <- load_stage1_v1_transition_table()
  example_inputs <- build_stage1_lookup_example_inputs()
  lookup_examples <- build_stage1_lookup_examples(
    example_inputs,
    transition_table
  )
  lookup_summary <- build_stage1_lookup_summary(lookup_examples)

  output_paths <- save_stage1_lookup_outputs(
    example_inputs,
    lookup_examples,
    lookup_summary
  )

  message("Saved lookup example inputs to: ", output_paths$example_inputs_path)
  message("Saved lookup examples to: ", output_paths$lookup_examples_path)
  message("Saved lookup summary to: ", output_paths$lookup_summary_path)
}
