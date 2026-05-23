#!/usr/bin/env Rscript

# Validate Stage 1 frequency baseline with a chronological train/test split.
# Run from the project root:
# Rscript prediction/11_validate_stage1_frequency_baseline.R

source("prediction/09_build_stage1_frequency_baseline.R")
source("prediction/10_apply_stage1_frequency_baseline.R")

parse_game_date <- function(date_values) {
  as.Date(substr(date_values, 1, 10))
}

create_chronological_split <- function(
  stage1_model_dataset,
  train_proportion = 0.8
) {
  assert_required_columns(stage1_model_dataset, c("date", "game_id"))

  stage1_model_dataset$game_date <- parse_game_date(stage1_model_dataset$date)

  if (any(is.na(stage1_model_dataset$game_date))) {
    stop("Unable to parse at least one game date.")
  }

  unique_dates <- sort(unique(stage1_model_dataset$game_date))

  split_index <- floor(length(unique_dates) * train_proportion)
  split_index <- max(1, min(split_index, length(unique_dates) - 1))

  train_dates <- unique_dates[seq_len(split_index)]

  stage1_model_dataset$validation_split <- ifelse(
    stage1_model_dataset$game_date %in% train_dates,
    "train",
    "test"
  )

  game_dates <- unique(stage1_model_dataset[, c("game_id", "game_date", "validation_split")])

  list(
    dataset = stage1_model_dataset,
    train_game_count = sum(game_dates$validation_split == "train"),
    test_game_count = sum(game_dates$validation_split == "test"),
    train_date_count = length(train_dates),
    test_date_count = length(unique_dates) - length(train_dates),
    train_start_date = min(unique_dates[unique_dates %in% train_dates]),
    train_end_date = max(unique_dates[unique_dates %in% train_dates]),
    test_start_date = min(unique_dates[!(unique_dates %in% train_dates)]),
    test_end_date = max(unique_dates[!(unique_dates %in% train_dates)])
  )
}

build_train_only_top_predictions <- function(train_dataset) {
  frequency_table <- build_all_frequency_tables(train_dataset)
  build_top_prediction_table(frequency_table)
}

create_validation_summary <- function(
  prediction_dataset,
  split_info
) {
  split_counts <- as.data.frame(table(
    prediction_dataset$validation_split
  ), stringsAsFactors = FALSE)
  names(split_counts) <- c("summary_item", "count")
  split_counts$summary_group <- "split_rows"
  split_counts$proportion <- round(split_counts$count / nrow(prediction_dataset), 4)
  split_counts <- split_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  split_accuracy <- do.call(rbind, lapply(
    c("train", "test"),
    function(split_name) {
      split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]

      data.frame(
        summary_group = "accuracy",
        summary_item = paste0(split_name, "_accuracy"),
        count = sum(split_data$is_correct_prediction, na.rm = TRUE),
        proportion = round(mean(split_data$is_correct_prediction, na.rm = TRUE), 4),
        stringsAsFactors = FALSE
      )
    }
  ))

  missing_predictions <- do.call(rbind, lapply(
    c("train", "test"),
    function(split_name) {
      split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]

      data.frame(
        summary_group = "missing_predictions",
        summary_item = split_name,
        count = sum(is.na(split_data$predicted_momentum_state)),
        proportion = round(mean(is.na(split_data$predicted_momentum_state)), 4),
        stringsAsFactors = FALSE
      )
    }
  ))

  used_level_counts <- as.data.frame(table(
    prediction_dataset$validation_split,
    prediction_dataset$used_baseline_level
  ), stringsAsFactors = FALSE)
  names(used_level_counts) <- c(
    "validation_split",
    "used_baseline_level",
    "count"
  )
  used_level_counts$summary_group <- "used_baseline_level"
  used_level_counts$summary_item <- paste(
    used_level_counts$validation_split,
    used_level_counts$used_baseline_level,
    sep = "__"
  )
  used_level_counts$proportion <- NA_real_

  for (split_name in unique(used_level_counts$validation_split)) {
    split_total <- sum(prediction_dataset$validation_split == split_name)
    used_level_counts$proportion[
      used_level_counts$validation_split == split_name
    ] <- round(
      used_level_counts$count[used_level_counts$validation_split == split_name] / split_total,
      4
    )
  }

  used_level_counts <- used_level_counts[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  split_metadata <- data.frame(
    summary_group = "split_metadata",
    summary_item = c(
      "train_game_count",
      "test_game_count",
      "train_date_count",
      "test_date_count",
      "train_start_date",
      "train_end_date",
      "test_start_date",
      "test_end_date"
    ),
    count = c(
      split_info$train_game_count,
      split_info$test_game_count,
      split_info$train_date_count,
      split_info$test_date_count,
      NA,
      NA,
      NA,
      NA
    ),
    proportion = NA_real_,
    value = c(
      NA,
      NA,
      NA,
      NA,
      as.character(split_info$train_start_date),
      as.character(split_info$train_end_date),
      as.character(split_info$test_start_date),
      as.character(split_info$test_end_date)
    ),
    stringsAsFactors = FALSE
  )

  base_summary <- rbind(
    split_counts,
    split_accuracy,
    missing_predictions,
    used_level_counts
  )
  base_summary$value <- NA_character_

  rbind(
    split_metadata[, c("summary_group", "summary_item", "count", "proportion", "value")],
    base_summary[, c("summary_group", "summary_item", "count", "proportion", "value")]
  )
}

create_confusion_matrix <- function(prediction_dataset) {
  confusion_matrix <- as.data.frame(table(
    prediction_dataset$validation_split,
    prediction_dataset$stage1_target_momentum_state,
    prediction_dataset$predicted_momentum_state
  ), stringsAsFactors = FALSE)

  names(confusion_matrix) <- c(
    "validation_split",
    "actual_momentum_state",
    "predicted_momentum_state",
    "count"
  )

  confusion_matrix <- confusion_matrix[confusion_matrix$count > 0, ]
  row.names(confusion_matrix) <- NULL
  confusion_matrix
}

save_validation_outputs <- function(
  prediction_dataset,
  validation_summary,
  confusion_matrix,
  prediction_path = "outputs/prediction/stage1_frequency_baseline_time_split_predictions.csv",
  summary_path = "outputs/prediction/stage1_frequency_baseline_time_split_summary.csv",
  confusion_matrix_path = "outputs/prediction/stage1_frequency_baseline_time_split_confusion_matrix.csv"
) {
  output_dir <- dirname(prediction_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_dataset, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(validation_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(confusion_matrix, confusion_matrix_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    summary_path = summary_path,
    confusion_matrix_path = confusion_matrix_path
  )
}

if (sys.nframe() == 0) {
  stage1_model_dataset <- load_stage1_model_dataset()

  split_info <- create_chronological_split(stage1_model_dataset)
  split_dataset <- split_info$dataset

  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]
  train_top_predictions <- build_train_only_top_predictions(train_dataset)

  prediction_dataset <- apply_stage1_frequency_baseline(
    split_dataset,
    train_top_predictions
  )

  validation_summary <- create_validation_summary(prediction_dataset, split_info)
  confusion_matrix <- create_confusion_matrix(prediction_dataset)

  output_paths <- save_validation_outputs(
    prediction_dataset,
    validation_summary,
    confusion_matrix
  )

  test_dataset <- prediction_dataset[prediction_dataset$validation_split == "test", ]

  message("Saved time-split predictions to: ", output_paths$prediction_path)
  message("Saved time-split summary to: ", output_paths$summary_path)
  message("Saved time-split confusion matrix to: ", output_paths$confusion_matrix_path)
  message("Train games: ", split_info$train_game_count)
  message("Test games: ", split_info$test_game_count)
  message("Test rows: ", nrow(test_dataset))
  message("Test missing predictions: ", sum(is.na(test_dataset$predicted_momentum_state)))
  message("Test accuracy: ", round(mean(test_dataset$is_correct_prediction, na.rm = TRUE), 4))
}
