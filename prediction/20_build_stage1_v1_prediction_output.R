#!/usr/bin/env Rscript

# Build Stage 1 v1 prediction output using the selected default model.
# Run from the project root:
# Rscript prediction/20_build_stage1_v1_prediction_output.R

source("prediction/18_train_stage1_tree_baseline.R")

get_stage1_v1_model_spec <- function() {
  tree_specs <- get_tree_variant_specs()

  tree_specs[[which(vapply(
    tree_specs,
    function(spec) spec$variant_name == "random_forest_unweighted",
    logical(1)
  ))]]
}

build_stage1_v1_predictions <- function(split_dataset, model, model_spec) {
  probability_matrix <- predict(model, newdata = split_dataset, type = "prob")
  probability_matrix <- as.matrix(probability_matrix)
  predicted_index <- max.col(probability_matrix, ties.method = "first")

  prediction_output <- split_dataset
  prediction_output$stage1_target_momentum_state <- as.character(
    prediction_output$stage1_target_momentum_state
  )
  prediction_output$stage1_v1_predicted_state <- colnames(probability_matrix)[predicted_index]
  prediction_output$stage1_v1_predicted_probability <- round(
    probability_matrix[cbind(seq_len(nrow(probability_matrix)), predicted_index)],
    6
  )
  prediction_output$stage1_v1_model <- model_spec$variant_name
  prediction_output$stage1_v1_model_family <- "random_forest"
  prediction_output$stage1_v1_ntree <- model_spec$ntree
  prediction_output$is_correct_prediction <- (
    prediction_output$stage1_v1_predicted_state ==
      prediction_output$stage1_target_momentum_state
  )

  for (state_name in colnames(probability_matrix)) {
    probability_column <- paste0("stage1_v1_prob_", state_name)
    prediction_output[[probability_column]] <- round(
      probability_matrix[, state_name],
      6
    )
  }

  keep_columns <- c(
    "game_id",
    "season",
    "date",
    "game_date",
    "validation_split",
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
    "pitcher_primary_type",
    "pitcher_sample_size_tier",
    "stage1_target_momentum_state",
    "stage1_v1_predicted_state",
    "stage1_v1_predicted_probability",
    grep("^stage1_v1_prob_", names(prediction_output), value = TRUE),
    "stage1_v1_model",
    "stage1_v1_model_family",
    "stage1_v1_ntree",
    "is_correct_prediction"
  )

  prediction_output[, keep_columns]
}

summarize_stage1_v1_predictions <- function(prediction_output, split_info) {
  split_rows <- as.data.frame(table(
    prediction_output$validation_split
  ), stringsAsFactors = FALSE)
  names(split_rows) <- c("summary_item", "count")
  split_rows$summary_group <- "split_rows"
  split_rows$proportion <- round(split_rows$count / nrow(prediction_output), 4)
  split_rows <- split_rows[, c("summary_group", "summary_item", "count", "proportion")]

  split_accuracy <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[prediction_output$validation_split == split_name, ]

      data.frame(
        summary_group = "accuracy",
        summary_item = paste0(split_name, "_accuracy"),
        count = sum(split_data$is_correct_prediction, na.rm = TRUE),
        proportion = round(mean(split_data$is_correct_prediction, na.rm = TRUE), 4),
        stringsAsFactors = FALSE
      )
    }
  ))

  split_dates <- data.frame(
    summary_group = "date_range",
    summary_item = c(
      "train_start_date",
      "train_end_date",
      "test_start_date",
      "test_end_date"
    ),
    count = NA_integer_,
    proportion = NA_real_,
    value = as.character(c(
      split_info$train_start_date,
      split_info$train_end_date,
      split_info$test_start_date,
      split_info$test_end_date
    )),
    stringsAsFactors = FALSE
  )

  predicted_distribution <- as.data.frame(table(
    prediction_output$validation_split,
    prediction_output$stage1_v1_predicted_state
  ), stringsAsFactors = FALSE)
  names(predicted_distribution) <- c(
    "validation_split",
    "predicted_state",
    "count"
  )
  predicted_distribution$summary_group <- "predicted_distribution"
  predicted_distribution$summary_item <- paste(
    predicted_distribution$validation_split,
    predicted_distribution$predicted_state,
    sep = "__"
  )
  predicted_distribution$proportion <- NA_real_

  for (split_name in unique(predicted_distribution$validation_split)) {
    split_total <- sum(prediction_output$validation_split == split_name)
    predicted_distribution$proportion[
      predicted_distribution$validation_split == split_name
    ] <- round(
      predicted_distribution$count[
        predicted_distribution$validation_split == split_name
      ] / split_total,
      4
    )
  }

  predicted_distribution <- predicted_distribution[, c(
    "summary_group",
    "summary_item",
    "count",
    "proportion"
  )]

  summary_without_value <- rbind(
    split_rows,
    split_accuracy,
    predicted_distribution
  )
  summary_without_value$value <- NA_character_

  rbind(
    summary_without_value[, c(
      "summary_group",
      "summary_item",
      "count",
      "proportion",
      "value"
    )],
    split_dates
  )
}

save_stage1_v1_outputs <- function(
  prediction_output,
  prediction_summary,
  prediction_path = "outputs/prediction/stage1_v1_prediction_output.csv",
  summary_path = "outputs/prediction/stage1_v1_prediction_summary.csv"
) {
  output_dir <- dirname(prediction_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_output, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(prediction_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    summary_path = summary_path
  )
}

if (sys.nframe() == 0) {
  set.seed(20260522)

  stage1_model_dataset <- load_stage1_model_dataset()
  split_info <- create_chronological_split(stage1_model_dataset)
  split_dataset <- prepare_tree_dataset(split_info$dataset)
  model_spec <- get_stage1_v1_model_spec()

  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]
  stage1_v1_model <- train_random_forest_model(train_dataset, model_spec)

  prediction_output <- build_stage1_v1_predictions(
    split_dataset,
    stage1_v1_model,
    model_spec
  )
  prediction_summary <- summarize_stage1_v1_predictions(
    prediction_output,
    split_info
  )

  output_paths <- save_stage1_v1_outputs(
    prediction_output,
    prediction_summary
  )

  message("Saved Stage 1 v1 prediction output to: ", output_paths$prediction_path)
  message("Saved Stage 1 v1 prediction summary to: ", output_paths$summary_path)
  message(
    "Test accuracy: ",
    prediction_summary$proportion[
      prediction_summary$summary_group == "accuracy" &
        prediction_summary$summary_item == "test_accuracy"
    ]
  )
}
