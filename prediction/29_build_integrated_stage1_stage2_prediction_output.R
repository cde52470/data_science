#!/usr/bin/env Rscript

# Build integrated Stage 1 + Stage 2 prediction output.
# Run from the project root:
# Rscript prediction/29_build_integrated_stage1_stage2_prediction_output.R

source("prediction/09_build_stage1_frequency_baseline.R")

load_stage1_v1_prediction_output <- function(
  input_path = "outputs/prediction/stage1_v1_prediction_output.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 v1 prediction output not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_stage2_win_frequency_table <- function(
  input_path = "outputs/prediction/stage2_combined_state_win_frequency_table.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 2 combined state win frequency table not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

load_stage2_frequency_predictions <- function(
  input_path = "outputs/prediction/stage2_win_frequency_predictions.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 2 frequency predictions not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_stage1_momentum_states <- function(stage1_predictions) {
  probability_columns <- grep(
    "^stage1_v1_prob_",
    names(stage1_predictions),
    value = TRUE
  )

  sub("^stage1_v1_prob_", "", probability_columns)
}

derive_inning_phase <- function(inning_values) {
  ifelse(
    inning_values <= 3,
    "early",
    ifelse(
      inning_values <= 6,
      "middle",
      ifelse(inning_values <= 9, "late", "extra")
    )
  )
}

build_stage2_fallback_tables <- function(stage2_frequency_predictions) {
  train_rows <- stage2_frequency_predictions[
    stage2_frequency_predictions$validation_split == "train",
  ]
  train_rows$team_win <- as.logical(train_rows$team_win)

  score_momentum_table <- aggregate(
    as.integer(train_rows$team_win),
    by = train_rows[, c("score_state", "momentum_state"), drop = FALSE],
    FUN = mean
  )
  names(score_momentum_table)[ncol(score_momentum_table)] <- "score_momentum_win_probability"

  score_momentum_counts <- aggregate(
    as.integer(train_rows$team_win),
    by = train_rows[, c("score_state", "momentum_state"), drop = FALSE],
    FUN = length
  )
  names(score_momentum_counts)[ncol(score_momentum_counts)] <- "score_momentum_train_rows"
  score_momentum_table <- merge(
    score_momentum_table,
    score_momentum_counts,
    by = c("score_state", "momentum_state"),
    all.x = TRUE,
    sort = FALSE
  )

  momentum_table <- aggregate(
    as.integer(train_rows$team_win),
    by = list(momentum_state = train_rows$momentum_state),
    FUN = mean
  )
  names(momentum_table)[ncol(momentum_table)] <- "momentum_win_probability"

  momentum_counts <- aggregate(
    as.integer(train_rows$team_win),
    by = list(momentum_state = train_rows$momentum_state),
    FUN = length
  )
  names(momentum_counts)[ncol(momentum_counts)] <- "momentum_train_rows"
  momentum_table <- merge(
    momentum_table,
    momentum_counts,
    by = "momentum_state",
    all.x = TRUE,
    sort = FALSE
  )

  list(
    score_momentum_table = score_momentum_table,
    momentum_table = momentum_table,
    global_train_win_rate = mean(train_rows$team_win, na.rm = TRUE),
    global_train_rows = nrow(train_rows)
  )
}

lookup_stage2_win_probability <- function(
  score_state,
  momentum_state,
  event_signal,
  stage2_win_table,
  fallback_tables
) {
  proxy_combined_state <- paste(
    score_state,
    momentum_state,
    event_signal,
    sep = "__"
  )

  combined_match <- stage2_win_table[
    stage2_win_table$combined_state == proxy_combined_state,
  ]
  if (nrow(combined_match) > 0) {
    return(list(
      proxy_combined_state = proxy_combined_state,
      stage2_win_probability = combined_match$combined_state_win_probability[1],
      stage2_train_rows = combined_match$combined_state_train_rows[1],
      stage2_lookup_level = "combined_state"
    ))
  }

  score_momentum_match <- fallback_tables$score_momentum_table[
    fallback_tables$score_momentum_table$score_state == score_state &
      fallback_tables$score_momentum_table$momentum_state == momentum_state,
  ]
  if (nrow(score_momentum_match) > 0) {
    return(list(
      proxy_combined_state = proxy_combined_state,
      stage2_win_probability = score_momentum_match$score_momentum_win_probability[1],
      stage2_train_rows = score_momentum_match$score_momentum_train_rows[1],
      stage2_lookup_level = "score_momentum"
    ))
  }

  momentum_match <- fallback_tables$momentum_table[
    fallback_tables$momentum_table$momentum_state == momentum_state,
  ]
  if (nrow(momentum_match) > 0) {
    return(list(
      proxy_combined_state = proxy_combined_state,
      stage2_win_probability = momentum_match$momentum_win_probability[1],
      stage2_train_rows = momentum_match$momentum_train_rows[1],
      stage2_lookup_level = "momentum_state"
    ))
  }

  list(
    proxy_combined_state = proxy_combined_state,
    stage2_win_probability = fallback_tables$global_train_win_rate,
    stage2_train_rows = fallback_tables$global_train_rows,
    stage2_lookup_level = "global"
  )
}

build_integrated_one_row <- function(
  input_row,
  momentum_states,
  stage2_win_table,
  fallback_tables
) {
  path_rows <- lapply(momentum_states, function(momentum_state) {
    probability_column <- paste0("stage1_v1_prob_", momentum_state)
    stage1_probability <- as.numeric(input_row[[probability_column]])
    stage2_lookup <- lookup_stage2_win_probability(
      score_state = input_row$before_score_state,
      momentum_state = momentum_state,
      event_signal = input_row$before_event_signal,
      stage2_win_table = stage2_win_table,
      fallback_tables = fallback_tables
    )

    data.frame(
      next_momentum_state = momentum_state,
      stage1_momentum_probability = stage1_probability,
      stage2_proxy_combined_state = stage2_lookup$proxy_combined_state,
      stage2_win_probability = stage2_lookup$stage2_win_probability,
      stage2_train_rows = stage2_lookup$stage2_train_rows,
      stage2_lookup_level = stage2_lookup$stage2_lookup_level,
      weighted_win_probability = stage1_probability *
        stage2_lookup$stage2_win_probability,
      stringsAsFactors = FALSE
    )
  })

  path_table <- do.call(rbind, path_rows)
  top_path <- path_table[which.max(path_table$weighted_win_probability), ]
  top_stage1 <- path_table[which.max(path_table$stage1_momentum_probability), ]

  data.frame(
    game_id = input_row$game_id,
    season = input_row$season,
    date = input_row$date,
    game_date = input_row$game_date,
    validation_split = input_row$validation_split,
    stadium = input_row$stadium,
    inning = input_row$inning,
    inning_phase = derive_inning_phase(as.integer(input_row$inning)),
    half_inning = input_row$half_inning,
    batting_team = input_row$batting_team,
    fielding_team = input_row$fielding_team,
    is_home_batting = input_row$is_home_batting,
    pa_order = input_row$pa_order,
    batter_name = input_row$batter_name,
    pitcher_name = input_row$pitcher_name,
    before_score_state = input_row$before_score_state,
    before_momentum_state = input_row$before_momentum_state,
    before_event_signal = input_row$before_event_signal,
    current_base_out_state = input_row$current_base_out_state,
    outs_before = input_row$outs_before,
    bases_before = input_row$bases_before,
    score_diff_before = input_row$score_diff_before,
    run_expectancy_before = input_row$run_expectancy_before,
    batter_primary_type = input_row$batter_primary_type,
    pitcher_primary_type = input_row$pitcher_primary_type,
    stage1_target_momentum_state = input_row$stage1_target_momentum_state,
    stage1_v1_predicted_state = input_row$stage1_v1_predicted_state,
    stage1_v1_predicted_probability = input_row$stage1_v1_predicted_probability,
    integrated_expected_win_probability = sum(path_table$weighted_win_probability),
    top_integrated_next_momentum_state = top_path$next_momentum_state,
    top_integrated_stage1_probability = top_path$stage1_momentum_probability,
    top_integrated_stage2_win_probability = top_path$stage2_win_probability,
    top_integrated_weighted_win_probability = top_path$weighted_win_probability,
    top_integrated_proxy_combined_state = top_path$stage2_proxy_combined_state,
    top_integrated_stage2_lookup_level = top_path$stage2_lookup_level,
    top_stage1_proxy_combined_state = top_stage1$stage2_proxy_combined_state,
    top_stage1_stage2_win_probability = top_stage1$stage2_win_probability,
    min_stage2_train_rows = min(path_table$stage2_train_rows, na.rm = TRUE),
    weighted_avg_stage2_train_rows = sum(
      path_table$stage1_momentum_probability * path_table$stage2_train_rows
    ),
    integrated_model_note = "stage1_momentum_to_stage2_proxy_combined_state",
    stringsAsFactors = FALSE
  )
}

build_integrated_prediction_output <- function(
  stage1_predictions,
  stage2_win_table,
  fallback_tables
) {
  momentum_states <- get_stage1_momentum_states(stage1_predictions)

  integrated_rows <- lapply(seq_len(nrow(stage1_predictions)), function(row_index) {
    build_integrated_one_row(
      input_row = stage1_predictions[row_index, ],
      momentum_states = momentum_states,
      stage2_win_table = stage2_win_table,
      fallback_tables = fallback_tables
    )
  })

  integrated_output <- do.call(rbind, integrated_rows)
  integrated_output$integrated_expected_win_probability <- round(
    integrated_output$integrated_expected_win_probability,
    6
  )
  integrated_output$top_integrated_weighted_win_probability <- round(
    integrated_output$top_integrated_weighted_win_probability,
    6
  )
  integrated_output$weighted_avg_stage2_train_rows <- round(
    integrated_output$weighted_avg_stage2_train_rows,
    2
  )

  integrated_output
}

build_integrated_prediction_summary <- function(integrated_output) {
  split_summary <- do.call(rbind, lapply(
    sort(unique(integrated_output$validation_split)),
    function(split_name) {
      split_data <- integrated_output[integrated_output$validation_split == split_name, ]
      data.frame(
        summary_group = "win_probability",
        summary_item = paste0(split_name, "_avg_expected_win_probability"),
        count = nrow(split_data),
        value = round(mean(split_data$integrated_expected_win_probability), 4),
        stringsAsFactors = FALSE
      )
    }
  ))

  phase_summary <- aggregate(
    integrated_output$integrated_expected_win_probability,
    by = integrated_output[, c("validation_split", "inning_phase"), drop = FALSE],
    FUN = mean
  )
  names(phase_summary)[ncol(phase_summary)] <- "value"
  phase_summary$summary_group <- "inning_phase_avg_win_probability"
  phase_summary$summary_item <- paste(
    phase_summary$validation_split,
    phase_summary$inning_phase,
    sep = "__"
  )
  phase_summary$count <- as.numeric(table(
    paste(integrated_output$validation_split, integrated_output$inning_phase, sep = "__")
  )[phase_summary$summary_item])
  phase_summary$value <- round(phase_summary$value, 4)
  phase_summary <- phase_summary[, c("summary_group", "summary_item", "count", "value")]

  lookup_summary <- as.data.frame(table(
    integrated_output$top_integrated_stage2_lookup_level
  ), stringsAsFactors = FALSE)
  names(lookup_summary) <- c("summary_item", "count")
  lookup_summary$summary_group <- "top_path_stage2_lookup_level"
  lookup_summary$value <- round(lookup_summary$count / nrow(integrated_output), 4)
  lookup_summary <- lookup_summary[, c("summary_group", "summary_item", "count", "value")]

  rbind(split_summary, phase_summary, lookup_summary)
}

save_integrated_prediction_outputs <- function(
  integrated_output,
  integrated_summary,
  output_path = "outputs/prediction/stage1_stage2_integrated_prediction_output.csv",
  summary_path = "outputs/prediction/stage1_stage2_integrated_prediction_summary.csv"
) {
  output_dir <- dirname(output_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(integrated_output, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(integrated_summary, summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    output_path = output_path,
    summary_path = summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_predictions <- load_stage1_v1_prediction_output()
  stage2_win_table <- load_stage2_win_frequency_table()
  stage2_frequency_predictions <- load_stage2_frequency_predictions()
  fallback_tables <- build_stage2_fallback_tables(stage2_frequency_predictions)

  integrated_output <- build_integrated_prediction_output(
    stage1_predictions,
    stage2_win_table,
    fallback_tables
  )
  integrated_summary <- build_integrated_prediction_summary(integrated_output)

  output_paths <- save_integrated_prediction_outputs(
    integrated_output,
    integrated_summary
  )

  message("Saved integrated prediction output to: ", output_paths$output_path)
  message("Saved integrated prediction summary to: ", output_paths$summary_path)
}
