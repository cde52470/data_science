#!/usr/bin/env Rscript

# Build Stage 1 scoring to Stage 2 win bridge prediction output.
# Run from the project root:
# Rscript prediction/39_build_stage1_scoring_stage2_win_bridge_output.R

load_stage1_stage2_scoring_bridge_dataset <- function(
  input_path = "data/cleaned/stage1_stage2_scoring_bridge_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1/Stage 2 scoring bridge dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

assert_required_columns <- function(dataset, required_columns) {
  missing_columns <- setdiff(required_columns, names(dataset))

  if (length(missing_columns) > 0) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }

  invisible(TRUE)
}

build_bridge_win_probability_table <- function(train_bridge_dataset) {
  required_columns <- c(
    "stage1_scoring_chance_state",
    "stage2_inning_phase",
    "stage2_team_win"
  )
  assert_required_columns(train_bridge_dataset, required_columns)

  chance_phase <- aggregate(
    as.integer(train_bridge_dataset$stage2_team_win),
    by = train_bridge_dataset[, c(
      "stage1_scoring_chance_state",
      "stage2_inning_phase"
    ), drop = FALSE],
    FUN = mean
  )
  names(chance_phase)[ncol(chance_phase)] <- "bridge_win_probability"

  chance_phase_counts <- aggregate(
    as.integer(train_bridge_dataset$stage2_team_win),
    by = train_bridge_dataset[, c(
      "stage1_scoring_chance_state",
      "stage2_inning_phase"
    ), drop = FALSE],
    FUN = length
  )
  names(chance_phase_counts)[ncol(chance_phase_counts)] <- "bridge_train_rows"
  chance_phase <- merge(
    chance_phase,
    chance_phase_counts,
    by = c("stage1_scoring_chance_state", "stage2_inning_phase"),
    all.x = TRUE,
    sort = FALSE
  )
  chance_phase$bridge_lookup_level <- "chance_phase"

  chance_only <- aggregate(
    as.integer(train_bridge_dataset$stage2_team_win),
    by = list(
      stage1_scoring_chance_state =
        train_bridge_dataset$stage1_scoring_chance_state
    ),
    FUN = mean
  )
  names(chance_only)[ncol(chance_only)] <- "bridge_win_probability"
  chance_only_counts <- aggregate(
    as.integer(train_bridge_dataset$stage2_team_win),
    by = list(
      stage1_scoring_chance_state =
        train_bridge_dataset$stage1_scoring_chance_state
    ),
    FUN = length
  )
  names(chance_only_counts)[ncol(chance_only_counts)] <- "bridge_train_rows"
  chance_only <- merge(
    chance_only,
    chance_only_counts,
    by = "stage1_scoring_chance_state",
    all.x = TRUE,
    sort = FALSE
  )
  chance_only$bridge_lookup_level <- "chance_only"

  phase_only <- aggregate(
    as.integer(train_bridge_dataset$stage2_team_win),
    by = list(stage2_inning_phase = train_bridge_dataset$stage2_inning_phase),
    FUN = mean
  )
  names(phase_only)[ncol(phase_only)] <- "bridge_win_probability"
  phase_only_counts <- aggregate(
    as.integer(train_bridge_dataset$stage2_team_win),
    by = list(stage2_inning_phase = train_bridge_dataset$stage2_inning_phase),
    FUN = length
  )
  names(phase_only_counts)[ncol(phase_only_counts)] <- "bridge_train_rows"
  phase_only <- merge(
    phase_only,
    phase_only_counts,
    by = "stage2_inning_phase",
    all.x = TRUE,
    sort = FALSE
  )
  phase_only$bridge_lookup_level <- "phase_only"

  list(
    chance_phase = chance_phase,
    chance_only = chance_only,
    phase_only = phase_only,
    global_win_probability = mean(train_bridge_dataset$stage2_team_win, na.rm = TRUE),
    global_train_rows = nrow(train_bridge_dataset)
  )
}

lookup_bridge_win_probability <- function(
  scoring_chance_state,
  inning_phase,
  bridge_tables
) {
  chance_phase_match <- bridge_tables$chance_phase[
    bridge_tables$chance_phase$stage1_scoring_chance_state == scoring_chance_state &
      bridge_tables$chance_phase$stage2_inning_phase == inning_phase,
  ]
  if (nrow(chance_phase_match) > 0) {
    return(list(
      win_probability = chance_phase_match$bridge_win_probability[1],
      train_rows = chance_phase_match$bridge_train_rows[1],
      lookup_level = "chance_phase"
    ))
  }

  chance_match <- bridge_tables$chance_only[
    bridge_tables$chance_only$stage1_scoring_chance_state == scoring_chance_state,
  ]
  if (nrow(chance_match) > 0) {
    return(list(
      win_probability = chance_match$bridge_win_probability[1],
      train_rows = chance_match$bridge_train_rows[1],
      lookup_level = "chance_only"
    ))
  }

  phase_match <- bridge_tables$phase_only[
    bridge_tables$phase_only$stage2_inning_phase == inning_phase,
  ]
  if (nrow(phase_match) > 0) {
    return(list(
      win_probability = phase_match$bridge_win_probability[1],
      train_rows = phase_match$bridge_train_rows[1],
      lookup_level = "phase_only"
    ))
  }

  list(
    win_probability = bridge_tables$global_win_probability,
    train_rows = bridge_tables$global_train_rows,
    lookup_level = "global"
  )
}

build_stage1_scoring_stage2_win_bridge_output <- function(bridge_dataset) {
  required_columns <- c(
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
    "batter_name",
    "pitcher_name",
    "current_base_out_state",
    "score_diff_before",
    "run_expectancy_before",
    "batter_primary_type",
    "pitcher_primary_type",
    "stage1_scoring_probability",
    "stage1_scoring_chance_state",
    "stage2_inning_phase",
    "stage2_combined_state",
    "stage2_momentum_state",
    "stage2_run_diff_now",
    "stage2_team_win"
  )
  assert_required_columns(bridge_dataset, required_columns)

  train_bridge <- bridge_dataset[bridge_dataset$validation_split == "train", ]
  bridge_tables <- build_bridge_win_probability_table(train_bridge)

  lookup_results <- lapply(seq_len(nrow(bridge_dataset)), function(row_index) {
    lookup_bridge_win_probability(
      scoring_chance_state =
        bridge_dataset$stage1_scoring_chance_state[row_index],
      inning_phase = bridge_dataset$stage2_inning_phase[row_index],
      bridge_tables = bridge_tables
    )
  })

  output <- bridge_dataset[, required_columns]
  output$bridge_win_probability <- round(vapply(
    lookup_results,
    function(result) result$win_probability,
    numeric(1)
  ), 6)
  output$bridge_train_rows <- vapply(
    lookup_results,
    function(result) result$train_rows,
    numeric(1)
  )
  output$bridge_lookup_level <- vapply(
    lookup_results,
    function(result) result$lookup_level,
    character(1)
  )
  output$bridge_predicted_team_win <- output$bridge_win_probability >= 0.5
  output$is_correct_bridge_win_prediction <- (
    output$bridge_predicted_team_win == as.logical(output$stage2_team_win)
  )

  output[order(
    output$game_id,
    output$inning,
    output$half_inning,
    output$pa_order
  ), ]
}

calculate_bridge_win_metrics <- function(prediction_output) {
  train_win_rate <- mean(
    as.logical(prediction_output$stage2_team_win[
      prediction_output$validation_split == "train"
    ]),
    na.rm = TRUE
  )

  bridge_metrics <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[
        prediction_output$validation_split == split_name,
      ]
      actual <- as.logical(split_data$stage2_team_win)
      predicted <- as.logical(split_data$bridge_predicted_team_win)
      probability <- split_data$bridge_win_probability

      data.frame(
        model_name = "scoring_chance_phase_bridge",
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 6),
        brier_score = round(mean((probability - as.integer(actual)) ^ 2), 6),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
        mean_predicted_win_probability = round(mean(probability, na.rm = TRUE), 6),
        predicted_win_rate = round(mean(predicted, na.rm = TRUE), 6),
        stringsAsFactors = FALSE
      )
    }
  ))

  global_metrics <- do.call(rbind, lapply(
    sort(unique(prediction_output$validation_split)),
    function(split_name) {
      split_data <- prediction_output[
        prediction_output$validation_split == split_name,
      ]
      actual <- as.logical(split_data$stage2_team_win)
      probability <- rep(train_win_rate, nrow(split_data))
      predicted <- probability >= 0.5

      data.frame(
        model_name = "global_train_win_rate",
        validation_split = split_name,
        row_count = nrow(split_data),
        accuracy = round(mean(actual == predicted, na.rm = TRUE), 6),
        brier_score = round(mean((probability - as.integer(actual)) ^ 2), 6),
        actual_win_rate = round(mean(actual, na.rm = TRUE), 6),
        mean_predicted_win_probability = round(mean(probability), 6),
        predicted_win_rate = round(mean(predicted), 6),
        stringsAsFactors = FALSE
      )
    }
  ))

  rbind(bridge_metrics, global_metrics)
}

summarize_bridge_lookup_levels <- function(prediction_output) {
  lookup_counts <- as.data.frame(table(
    prediction_output$validation_split,
    prediction_output$bridge_lookup_level
  ), stringsAsFactors = FALSE)
  names(lookup_counts) <- c("validation_split", "bridge_lookup_level", "row_count")

  lookup_counts$proportion <- NA_real_
  for (split_name in unique(lookup_counts$validation_split)) {
    split_total <- sum(prediction_output$validation_split == split_name)
    lookup_counts$proportion[
      lookup_counts$validation_split == split_name
    ] <- round(
      lookup_counts$row_count[lookup_counts$validation_split == split_name] /
        split_total,
      6
    )
  }

  lookup_counts
}

summarize_bridge_win_by_state <- function(prediction_output) {
  aggregate(
    cbind(
      row_count = rep(1, nrow(prediction_output)),
      actual_win_rate = as.integer(prediction_output$stage2_team_win),
      mean_predicted_win_probability = prediction_output$bridge_win_probability
    ),
    by = list(
      validation_split = prediction_output$validation_split,
      scoring_chance_state = prediction_output$stage1_scoring_chance_state,
      inning_phase = prediction_output$stage2_inning_phase
    ),
    FUN = function(values) {
      if (all(values == 1)) {
        length(values)
      } else {
        round(mean(values, na.rm = TRUE), 6)
      }
    }
  )
}

save_stage1_scoring_stage2_win_bridge_outputs <- function(
  prediction_output,
  metrics,
  lookup_summary,
  state_summary,
  prediction_path = "outputs/prediction/stage1_scoring_stage2_win_bridge_output.csv",
  metrics_path = "outputs/prediction/stage1_scoring_stage2_win_bridge_metrics.csv",
  lookup_summary_path = "outputs/prediction/stage1_scoring_stage2_win_bridge_lookup_summary.csv",
  state_summary_path = "outputs/prediction/stage1_scoring_stage2_win_bridge_state_summary.csv"
) {
  output_dir <- dirname(prediction_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(prediction_output, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(metrics, metrics_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(lookup_summary, lookup_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(state_summary, state_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    prediction_path = prediction_path,
    metrics_path = metrics_path,
    lookup_summary_path = lookup_summary_path,
    state_summary_path = state_summary_path
  )
}

if (sys.nframe() == 0) {
  bridge_dataset <- load_stage1_stage2_scoring_bridge_dataset()
  prediction_output <- build_stage1_scoring_stage2_win_bridge_output(
    bridge_dataset
  )
  metrics <- calculate_bridge_win_metrics(prediction_output)
  lookup_summary <- summarize_bridge_lookup_levels(prediction_output)
  state_summary <- summarize_bridge_win_by_state(prediction_output)

  output_paths <- save_stage1_scoring_stage2_win_bridge_outputs(
    prediction_output,
    metrics,
    lookup_summary,
    state_summary
  )

  message("Saved Stage 1 scoring / Stage 2 win bridge output to: ", output_paths$prediction_path)
  message("Saved bridge win metrics to: ", output_paths$metrics_path)
  message("Saved bridge lookup summary to: ", output_paths$lookup_summary_path)
  message("Saved bridge state summary to: ", output_paths$state_summary_path)
  message("Rows: ", nrow(prediction_output))
  message("Columns: ", ncol(prediction_output))
}
