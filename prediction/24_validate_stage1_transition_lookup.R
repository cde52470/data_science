#!/usr/bin/env Rscript

# Validate Stage 1 v1 transition lookup on real test rows.
# Run from the project root:
# Rscript prediction/24_validate_stage1_transition_lookup.R

source("prediction/23_build_stage1_transition_lookup.R")

validate_one_lookup_row <- function(input_row, transition_table) {
  lookup_result <- lookup_stage1_transition_probability(
    input_row = input_row,
    transition_table = transition_table
  )

  if (nrow(lookup_result) == 0) {
    return(data.frame(
      game_id = input_row$game_id,
      date = input_row$date,
      inning = input_row$inning,
      half_inning = input_row$half_inning,
      batting_team = input_row$batting_team,
      fielding_team = input_row$fielding_team,
      batter_name = input_row$batter_name,
      pitcher_name = input_row$pitcher_name,
      before_score_state = input_row$before_score_state,
      before_momentum_state = input_row$before_momentum_state,
      current_base_out_state = input_row$current_base_out_state,
      batter_primary_type = input_row$batter_primary_type,
      pitcher_primary_type = input_row$pitcher_primary_type,
      stage1_target_momentum_state = input_row$stage1_target_momentum_state,
      stage1_v1_predicted_state = input_row$stage1_v1_predicted_state,
      lookup_predicted_state = NA_character_,
      lookup_predicted_probability = NA_real_,
      matched_transition_level = NA_character_,
      matched_context_label = NA_character_,
      fallback_rank = NA_integer_,
      context_total = NA_integer_,
      lookup_is_correct = NA,
      original_model_is_correct = input_row$is_correct_prediction,
      stringsAsFactors = FALSE
    ))
  }

  top_row <- lookup_result[which.max(lookup_result$model_probability), ]

  data.frame(
    game_id = input_row$game_id,
    date = input_row$date,
    inning = input_row$inning,
    half_inning = input_row$half_inning,
    batting_team = input_row$batting_team,
    fielding_team = input_row$fielding_team,
    batter_name = input_row$batter_name,
    pitcher_name = input_row$pitcher_name,
    before_score_state = input_row$before_score_state,
    before_momentum_state = input_row$before_momentum_state,
    current_base_out_state = input_row$current_base_out_state,
    batter_primary_type = input_row$batter_primary_type,
    pitcher_primary_type = input_row$pitcher_primary_type,
    stage1_target_momentum_state = input_row$stage1_target_momentum_state,
    stage1_v1_predicted_state = input_row$stage1_v1_predicted_state,
    lookup_predicted_state = top_row$next_momentum_state,
    lookup_predicted_probability = top_row$model_probability,
    matched_transition_level = top_row$matched_transition_level,
    matched_context_label = top_row$matched_context_label,
    fallback_rank = top_row$fallback_rank,
    context_total = top_row$context_total,
    lookup_is_correct = top_row$next_momentum_state ==
      input_row$stage1_target_momentum_state,
    original_model_is_correct = input_row$is_correct_prediction,
    stringsAsFactors = FALSE
  )
}

validate_stage1_lookup_on_test_rows <- function(prediction_output, transition_table) {
  test_rows <- prediction_output[prediction_output$validation_split == "test", ]

  lookup_rows <- lapply(seq_len(nrow(test_rows)), function(row_index) {
    validate_one_lookup_row(test_rows[row_index, ], transition_table)
  })

  do.call(rbind, lookup_rows)
}

build_lookup_validation_summary <- function(validation_rows) {
  total_rows <- nrow(validation_rows)
  matched_rows <- validation_rows[!is.na(validation_rows$lookup_predicted_state), ]

  summary_rows <- data.frame(
    summary_group = c(
      "coverage",
      "accuracy",
      "accuracy",
      "agreement"
    ),
    summary_item = c(
      "lookup_coverage",
      "lookup_accuracy",
      "original_model_accuracy",
      "lookup_matches_original_prediction"
    ),
    count = c(
      nrow(matched_rows),
      sum(matched_rows$lookup_is_correct, na.rm = TRUE),
      sum(validation_rows$original_model_is_correct, na.rm = TRUE),
      sum(
        validation_rows$lookup_predicted_state ==
          validation_rows$stage1_v1_predicted_state,
        na.rm = TRUE
      )
    ),
    proportion = c(
      round(nrow(matched_rows) / total_rows, 4),
      round(mean(matched_rows$lookup_is_correct, na.rm = TRUE), 4),
      round(mean(validation_rows$original_model_is_correct, na.rm = TRUE), 4),
      round(mean(
        validation_rows$lookup_predicted_state ==
          validation_rows$stage1_v1_predicted_state,
        na.rm = TRUE
      ), 4)
    ),
    stringsAsFactors = FALSE
  )

  level_counts <- as.data.frame(table(
    matched_rows$matched_transition_level
  ), stringsAsFactors = FALSE)
  names(level_counts) <- c("summary_item", "count")
  level_counts$summary_group <- "matched_transition_level"
  level_counts$proportion <- round(level_counts$count / total_rows, 4)

  context_rows <- data.frame(
    summary_group = "context_total",
    summary_item = c("median_context_total", "mean_context_total"),
    count = c(
      round(median(matched_rows$context_total, na.rm = TRUE), 0),
      round(mean(matched_rows$context_total, na.rm = TRUE), 0)
    ),
    proportion = NA_real_,
    stringsAsFactors = FALSE
  )

  rbind(summary_rows, level_counts, context_rows)
}

build_lookup_level_metrics <- function(validation_rows) {
  matched_rows <- validation_rows[!is.na(validation_rows$lookup_predicted_state), ]

  do.call(rbind, lapply(
    sort(unique(matched_rows$matched_transition_level)),
    function(level_name) {
      level_rows <- matched_rows[matched_rows$matched_transition_level == level_name, ]

      data.frame(
        matched_transition_level = level_name,
        row_count = nrow(level_rows),
        row_share = round(nrow(level_rows) / nrow(validation_rows), 4),
        lookup_accuracy = round(mean(level_rows$lookup_is_correct, na.rm = TRUE), 4),
        original_model_accuracy = round(mean(
          level_rows$original_model_is_correct,
          na.rm = TRUE
        ), 4),
        lookup_model_agreement = round(mean(
          level_rows$lookup_predicted_state ==
            level_rows$stage1_v1_predicted_state,
          na.rm = TRUE
        ), 4),
        median_context_total = round(median(level_rows$context_total, na.rm = TRUE), 0),
        stringsAsFactors = FALSE
      )
    }
  ))
}

build_lookup_class_metrics <- function(validation_rows) {
  matched_rows <- validation_rows[!is.na(validation_rows$lookup_predicted_state), ]
  classes <- sort(unique(matched_rows$stage1_target_momentum_state))

  do.call(rbind, lapply(classes, function(class_name) {
    actual_positive <- matched_rows$stage1_target_momentum_state == class_name
    predicted_positive <- matched_rows$lookup_predicted_state == class_name

    true_positive <- sum(actual_positive & predicted_positive, na.rm = TRUE)
    false_positive <- sum(!actual_positive & predicted_positive, na.rm = TRUE)
    false_negative <- sum(actual_positive & !predicted_positive, na.rm = TRUE)

    precision <- ifelse(
      true_positive + false_positive == 0,
      NA_real_,
      true_positive / (true_positive + false_positive)
    )
    recall <- ifelse(
      true_positive + false_negative == 0,
      NA_real_,
      true_positive / (true_positive + false_negative)
    )
    f1_score <- ifelse(
      is.na(precision) | is.na(recall) | precision + recall == 0,
      NA_real_,
      2 * precision * recall / (precision + recall)
    )

    data.frame(
      class = class_name,
      support = sum(actual_positive, na.rm = TRUE),
      predicted_count = sum(predicted_positive, na.rm = TRUE),
      precision = round(precision, 4),
      recall = round(recall, 4),
      f1_score = round(f1_score, 4),
      stringsAsFactors = FALSE
    )
  }))
}

save_lookup_validation_outputs <- function(
  validation_rows,
  validation_summary,
  level_metrics,
  class_metrics,
  validation_rows_path = "outputs/prediction/stage1_v1_transition_lookup_validation_rows.csv",
  validation_summary_path = "outputs/prediction/stage1_v1_transition_lookup_validation_summary.csv",
  level_metrics_path = "outputs/prediction/stage1_v1_transition_lookup_level_metrics.csv",
  class_metrics_path = "outputs/prediction/stage1_v1_transition_lookup_class_metrics.csv"
) {
  output_dir <- dirname(validation_rows_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(validation_rows, validation_rows_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(validation_summary, validation_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(level_metrics, level_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    validation_rows_path = validation_rows_path,
    validation_summary_path = validation_summary_path,
    level_metrics_path = level_metrics_path,
    class_metrics_path = class_metrics_path
  )
}

if (sys.nframe() == 0) {
  prediction_output <- load_stage1_v1_prediction_output()
  transition_table <- load_stage1_v1_transition_table()

  validation_rows <- validate_stage1_lookup_on_test_rows(
    prediction_output,
    transition_table
  )
  validation_summary <- build_lookup_validation_summary(validation_rows)
  level_metrics <- build_lookup_level_metrics(validation_rows)
  class_metrics <- build_lookup_class_metrics(validation_rows)

  output_paths <- save_lookup_validation_outputs(
    validation_rows,
    validation_summary,
    level_metrics,
    class_metrics
  )

  message("Saved lookup validation rows to: ", output_paths$validation_rows_path)
  message("Saved lookup validation summary to: ", output_paths$validation_summary_path)
  message("Saved lookup level metrics to: ", output_paths$level_metrics_path)
  message("Saved lookup class metrics to: ", output_paths$class_metrics_path)
}
