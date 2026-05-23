#!/usr/bin/env Rscript

# Apply Stage 1 frequency baseline with fallback levels.
# Run from the project root:
# Rscript prediction/10_apply_stage1_frequency_baseline.R

load_stage1_model_dataset <- function(
  input_path = "data/cleaned/stage1_transition_model_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 model dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_stage1_top_prediction_table <- function(
  input_path = "outputs/prediction/stage1_frequency_baseline_top_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 top prediction table not found: ", input_path)
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

get_fallback_specs <- function() {
  list(
    list(
      baseline_level = "full_context",
      group_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_group_total = 50
    ),
    list(
      baseline_level = "player_type_context",
      group_columns = c(
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_group_total = 50
    ),
    list(
      baseline_level = "score_momentum_baseout",
      group_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state"
      ),
      minimum_group_total = 50
    ),
    list(
      baseline_level = "momentum_baseout",
      group_columns = c(
        "before_momentum_state",
        "current_base_out_state"
      ),
      minimum_group_total = 1
    )
  )
}

make_context_key <- function(dataset, group_columns) {
  assert_required_columns(dataset, group_columns)

  apply(
    dataset[, group_columns, drop = FALSE],
    1,
    function(row_values) {
      paste(row_values, collapse = "||")
    }
  )
}

prepare_prediction_lookup <- function(top_prediction_table, spec) {
  group_columns <- spec$group_columns
  baseline_level <- spec$baseline_level
  minimum_group_total <- spec$minimum_group_total

  required_columns <- c(
    "baseline_level",
    group_columns,
    "stage1_target_momentum_state",
    "probability",
    "group_total"
  )
  assert_required_columns(top_prediction_table, required_columns)

  lookup <- top_prediction_table[
    top_prediction_table$baseline_level == baseline_level &
      top_prediction_table$group_total >= minimum_group_total,
    required_columns
  ]

  lookup$context_key <- make_context_key(lookup, group_columns)
  lookup <- lookup[, c(
    "context_key",
    "stage1_target_momentum_state",
    "probability",
    "group_total"
  )]

  names(lookup) <- c(
    "context_key",
    "candidate_prediction",
    "candidate_probability",
    "candidate_group_total"
  )

  lookup
}

apply_one_fallback_level <- function(prediction_dataset, top_prediction_table, spec) {
  group_columns <- spec$group_columns
  baseline_level <- spec$baseline_level

  lookup <- prepare_prediction_lookup(top_prediction_table, spec)
  prediction_dataset$context_key <- make_context_key(prediction_dataset, group_columns)

  merged <- merge(
    prediction_dataset,
    lookup,
    by = "context_key",
    all.x = TRUE,
    sort = FALSE
  )

  has_prediction <- is.na(merged$predicted_momentum_state) &
    !is.na(merged$candidate_prediction)

  merged$predicted_momentum_state[has_prediction] <- merged$candidate_prediction[has_prediction]
  merged$predicted_probability[has_prediction] <- merged$candidate_probability[has_prediction]
  merged$used_baseline_level[has_prediction] <- baseline_level
  merged$used_group_total[has_prediction] <- merged$candidate_group_total[has_prediction]

  merged$candidate_prediction <- NULL
  merged$candidate_probability <- NULL
  merged$candidate_group_total <- NULL
  merged$context_key <- NULL

  merged
}

apply_stage1_frequency_baseline <- function(
  stage1_model_dataset,
  top_prediction_table
) {
  required_columns <- c(
    "game_id",
    "inning",
    "half_inning",
    "batting_team",
    "pa_order",
    "stage1_target_momentum_state"
  )
  assert_required_columns(stage1_model_dataset, required_columns)

  prediction_dataset <- stage1_model_dataset
  prediction_dataset$row_id <- seq_len(nrow(prediction_dataset))
  prediction_dataset$predicted_momentum_state <- NA_character_
  prediction_dataset$predicted_probability <- NA_real_
  prediction_dataset$used_baseline_level <- NA_character_
  prediction_dataset$used_group_total <- NA_integer_

  fallback_specs <- get_fallback_specs()

  for (spec in fallback_specs) {
    prediction_dataset <- apply_one_fallback_level(
      prediction_dataset,
      top_prediction_table,
      spec
    )

    prediction_dataset <- prediction_dataset[order(prediction_dataset$row_id), ]
  }

  prediction_dataset$is_correct_prediction <- (
    prediction_dataset$predicted_momentum_state ==
      prediction_dataset$stage1_target_momentum_state
  )

  prediction_dataset <- prediction_dataset[order(prediction_dataset$row_id), ]
  prediction_dataset$row_id <- NULL
  row.names(prediction_dataset) <- NULL

  prediction_dataset
}

create_prediction_summary <- function(prediction_dataset) {
  metadata <- data.frame(
    summary_group = "metadata",
    summary_item = c("rows", "missing_predictions"),
    count = c(
      nrow(prediction_dataset),
      sum(is.na(prediction_dataset$predicted_momentum_state))
    ),
    proportion = c(
      NA_real_,
      round(mean(is.na(prediction_dataset$predicted_momentum_state)), 4)
    ),
    stringsAsFactors = FALSE
  )

  accuracy <- data.frame(
    summary_group = "accuracy",
    summary_item = "overall_accuracy",
    count = sum(prediction_dataset$is_correct_prediction, na.rm = TRUE),
    proportion = round(mean(prediction_dataset$is_correct_prediction, na.rm = TRUE), 4),
    stringsAsFactors = FALSE
  )

  used_level_counts <- as.data.frame(table(
    prediction_dataset$used_baseline_level
  ), stringsAsFactors = FALSE)
  names(used_level_counts) <- c("summary_item", "count")
  used_level_counts$summary_group <- "used_baseline_level"
  used_level_counts$proportion <- round(
    used_level_counts$count / nrow(prediction_dataset),
    4
  )
  used_level_counts <- used_level_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  prediction_counts <- as.data.frame(table(
    prediction_dataset$predicted_momentum_state
  ), stringsAsFactors = FALSE)
  names(prediction_counts) <- c("summary_item", "count")
  prediction_counts$summary_group <- "predicted_distribution"
  prediction_counts$proportion <- round(
    prediction_counts$count / nrow(prediction_dataset),
    4
  )
  prediction_counts <- prediction_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  rbind(metadata, accuracy, used_level_counts, prediction_counts)
}

save_stage1_frequency_baseline_predictions <- function(
  prediction_dataset,
  summary,
  prediction_path = "outputs/prediction/stage1_frequency_baseline_predictions.csv",
  summary_path = "outputs/prediction/stage1_frequency_baseline_prediction_summary.csv"
) {
  output_dir <- dirname(prediction_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_dataset, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    summary_path = summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_model_dataset <- load_stage1_model_dataset()
  top_prediction_table <- load_stage1_top_prediction_table()

  prediction_dataset <- apply_stage1_frequency_baseline(
    stage1_model_dataset,
    top_prediction_table
  )
  summary <- create_prediction_summary(prediction_dataset)

  output_paths <- save_stage1_frequency_baseline_predictions(
    prediction_dataset,
    summary
  )

  message("Saved Stage 1 frequency baseline predictions to: ", output_paths$prediction_path)
  message("Saved Stage 1 frequency baseline prediction summary to: ", output_paths$summary_path)
  message("Rows: ", nrow(prediction_dataset))
  message("Missing predictions: ", sum(is.na(prediction_dataset$predicted_momentum_state)))
  message("Accuracy: ", round(mean(prediction_dataset$is_correct_prediction, na.rm = TRUE), 4))
}
