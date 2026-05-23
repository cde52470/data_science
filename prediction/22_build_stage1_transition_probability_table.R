#!/usr/bin/env Rscript

# Build Stage 1 v1 transition probability tables.
# Run from the project root:
# Rscript prediction/22_build_stage1_transition_probability_table.R

source("prediction/21_analyze_stage1_v1_prediction_patterns.R")

get_transition_table_specs <- function() {
  list(
    list(
      transition_level = "state_baseout",
      context_columns = c(
        "before_momentum_state",
        "current_base_out_state"
      ),
      minimum_context_rows = 20
    ),
    list(
      transition_level = "score_state_baseout",
      context_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state"
      ),
      minimum_context_rows = 15
    ),
    list(
      transition_level = "state_baseout_player_type",
      context_columns = c(
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_context_rows = 10
    ),
    list(
      transition_level = "full_context",
      context_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_context_rows = 8
    )
  )
}

get_stage1_state_levels <- function(prediction_output) {
  sort(unique(c(
    prediction_output$stage1_target_momentum_state,
    prediction_output$stage1_v1_predicted_state
  )))
}

get_probability_column_name <- function(state_name) {
  paste0("stage1_v1_prob_", state_name)
}

build_one_transition_table <- function(
  prediction_output,
  transition_level,
  context_columns,
  minimum_context_rows,
  split_name = "test"
) {
  required_columns <- c(
    "validation_split",
    context_columns,
    "stage1_target_momentum_state",
    "stage1_v1_predicted_state"
  )
  assert_required_columns(prediction_output, required_columns)

  split_data <- prediction_output[prediction_output$validation_split == split_name, ]
  state_levels <- get_stage1_state_levels(split_data)
  probability_columns <- vapply(
    state_levels,
    get_probability_column_name,
    character(1)
  )
  assert_required_columns(split_data, probability_columns)

  context_totals <- aggregate(
    rep(1, nrow(split_data)),
    by = split_data[, context_columns, drop = FALSE],
    FUN = sum
  )
  names(context_totals)[ncol(context_totals)] <- "context_total"

  model_probability_rows <- lapply(state_levels, function(state_name) {
    probability_column <- get_probability_column_name(state_name)
    state_probability <- aggregate(
      split_data[[probability_column]],
      by = split_data[, context_columns, drop = FALSE],
      FUN = mean
    )
    names(state_probability)[ncol(state_probability)] <- "model_probability"
    state_probability$next_momentum_state <- state_name
    state_probability
  })
  model_probabilities <- do.call(rbind, model_probability_rows)

  empirical_counts <- aggregate(
    rep(1, nrow(split_data)),
    by = split_data[, c(context_columns, "stage1_target_momentum_state"), drop = FALSE],
    FUN = sum
  )
  names(empirical_counts)[ncol(empirical_counts)] <- "target_count"
  names(empirical_counts)[
    names(empirical_counts) == "stage1_target_momentum_state"
  ] <- "next_momentum_state"

  predicted_counts <- aggregate(
    rep(1, nrow(split_data)),
    by = split_data[, c(context_columns, "stage1_v1_predicted_state"), drop = FALSE],
    FUN = sum
  )
  names(predicted_counts)[ncol(predicted_counts)] <- "predicted_count"
  names(predicted_counts)[
    names(predicted_counts) == "stage1_v1_predicted_state"
  ] <- "next_momentum_state"

  transition_table <- merge(
    model_probabilities,
    context_totals,
    by = context_columns,
    all.x = TRUE,
    sort = FALSE
  )
  transition_table <- merge(
    transition_table,
    empirical_counts,
    by = c(context_columns, "next_momentum_state"),
    all.x = TRUE,
    sort = FALSE
  )
  transition_table <- merge(
    transition_table,
    predicted_counts,
    by = c(context_columns, "next_momentum_state"),
    all.x = TRUE,
    sort = FALSE
  )

  transition_table$target_count[is.na(transition_table$target_count)] <- 0
  transition_table$predicted_count[is.na(transition_table$predicted_count)] <- 0
  transition_table <- transition_table[
    transition_table$context_total >= minimum_context_rows,
  ]

  transition_table$transition_level <- transition_level
  transition_table$validation_split <- split_name
  transition_table$context_columns <- paste(context_columns, collapse = " + ")
  transition_table$context_label <- apply(
    transition_table[, context_columns, drop = FALSE],
    1,
    paste,
    collapse = " | "
  )
  transition_table$empirical_target_probability <- round(
    transition_table$target_count / transition_table$context_total,
    6
  )
  transition_table$model_probability <- round(
    transition_table$model_probability,
    6
  )
  transition_table$predicted_top_share <- round(
    transition_table$predicted_count / transition_table$context_total,
    6
  )
  transition_table$probability_gap_model_minus_empirical <- round(
    transition_table$model_probability -
      transition_table$empirical_target_probability,
    6
  )

  output_columns <- c(
    "validation_split",
    "transition_level",
    "context_columns",
    "context_label",
    "next_momentum_state",
    "context_total",
    "model_probability",
    "empirical_target_probability",
    "predicted_top_share",
    "target_count",
    "predicted_count",
    "probability_gap_model_minus_empirical"
  )

  transition_table <- transition_table[, output_columns]
  transition_table[order(
    transition_table$transition_level,
    transition_table$context_label,
    -transition_table$model_probability,
    transition_table$next_momentum_state
  ), ]
}

build_all_transition_tables <- function(prediction_output) {
  specs <- get_transition_table_specs()

  do.call(rbind, lapply(specs, function(spec) {
    build_one_transition_table(
      prediction_output = prediction_output,
      transition_level = spec$transition_level,
      context_columns = spec$context_columns,
      minimum_context_rows = spec$minimum_context_rows
    )
  }))
}

build_transition_table_index <- function(transition_table) {
  context_groups <- unique(transition_table[, c(
    "validation_split",
    "transition_level",
    "context_columns",
    "context_label",
    "context_total"
  )])

  top_rows <- do.call(rbind, lapply(
    split(transition_table, paste(
      transition_table$transition_level,
      transition_table$context_label,
      sep = "__"
    )),
    function(group_data) {
      group_data[which.max(group_data$model_probability), ]
    }
  ))

  index <- merge(
    context_groups,
    top_rows[, c(
      "transition_level",
      "context_label",
      "next_momentum_state",
      "model_probability",
      "empirical_target_probability",
      "predicted_top_share"
    )],
    by = c("transition_level", "context_label"),
    all.x = TRUE,
    sort = FALSE
  )
  names(index)[names(index) == "next_momentum_state"] <- "top_model_next_state"
  names(index)[names(index) == "model_probability"] <- "top_model_probability"
  names(index)[names(index) == "empirical_target_probability"] <- "top_state_empirical_probability"
  names(index)[names(index) == "predicted_top_share"] <- "top_state_predicted_share"

  index[order(index$transition_level, -index$context_total), ]
}

build_transition_table_summary <- function(transition_table, transition_index) {
  level_summary <- aggregate(
    transition_index$context_total,
    by = list(transition_level = transition_index$transition_level),
    FUN = length
  )
  names(level_summary)[names(level_summary) == "x"] <- "context_group_count"

  median_rows <- aggregate(
    transition_index$context_total,
    by = list(transition_level = transition_index$transition_level),
    FUN = median
  )
  names(median_rows)[names(median_rows) == "x"] <- "median_context_rows"

  mean_top_probability <- aggregate(
    transition_index$top_model_probability,
    by = list(transition_level = transition_index$transition_level),
    FUN = mean
  )
  names(mean_top_probability)[names(mean_top_probability) == "x"] <- "avg_top_model_probability"

  summary <- merge(level_summary, median_rows, by = "transition_level", all = TRUE)
  summary <- merge(summary, mean_top_probability, by = "transition_level", all = TRUE)

  summary$transition_rows <- as.numeric(table(
    transition_table$transition_level
  )[summary$transition_level])
  summary$median_context_rows <- round(summary$median_context_rows, 2)
  summary$avg_top_model_probability <- round(summary$avg_top_model_probability, 4)

  summary[, c(
    "transition_level",
    "context_group_count",
    "transition_rows",
    "median_context_rows",
    "avg_top_model_probability"
  )]
}

save_transition_table_outputs <- function(
  transition_table,
  transition_index,
  transition_summary,
  transition_table_path = "outputs/prediction/stage1_v1_transition_probability_table.csv",
  transition_index_path = "outputs/prediction/stage1_v1_transition_probability_index.csv",
  transition_summary_path = "outputs/prediction/stage1_v1_transition_probability_summary.csv"
) {
  output_dir <- dirname(transition_table_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(transition_table, transition_table_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(transition_index, transition_index_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(transition_summary, transition_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    transition_table_path = transition_table_path,
    transition_index_path = transition_index_path,
    transition_summary_path = transition_summary_path
  )
}

if (sys.nframe() == 0) {
  prediction_output <- load_stage1_v1_prediction_output()
  pattern_dataset <- prepare_pattern_dataset(prediction_output)

  transition_table <- build_all_transition_tables(pattern_dataset)
  transition_index <- build_transition_table_index(transition_table)
  transition_summary <- build_transition_table_summary(
    transition_table,
    transition_index
  )

  output_paths <- save_transition_table_outputs(
    transition_table,
    transition_index,
    transition_summary
  )

  message("Saved transition probability table to: ", output_paths$transition_table_path)
  message("Saved transition probability index to: ", output_paths$transition_index_path)
  message("Saved transition probability summary to: ", output_paths$transition_summary_path)
}
