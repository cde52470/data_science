#!/usr/bin/env Rscript

# Build frequency baseline probability tables for Stage 1 momentum transition.
# Run from the project root:
# Rscript prediction/09_build_stage1_frequency_baseline.R

load_stage1_model_dataset <- function(
  input_path = "data/cleaned/stage1_transition_model_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 model dataset not found: ", input_path)
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

get_frequency_baseline_specs <- function() {
  list(
    list(
      baseline_level = "momentum_baseout",
      group_columns = c(
        "before_momentum_state",
        "current_base_out_state"
      )
    ),
    list(
      baseline_level = "score_momentum_baseout",
      group_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state"
      )
    ),
    list(
      baseline_level = "player_type_context",
      group_columns = c(
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      )
    ),
    list(
      baseline_level = "full_context",
      group_columns = c(
        "before_score_state",
        "before_momentum_state",
        "current_base_out_state",
        "batter_primary_type",
        "pitcher_primary_type"
      )
    )
  )
}

build_frequency_table <- function(
  stage1_model_dataset,
  group_columns,
  baseline_level,
  target_column = "stage1_target_momentum_state"
) {
  required_columns <- c(group_columns, target_column)
  assert_required_columns(stage1_model_dataset, required_columns)

  count_columns <- c(group_columns, target_column)

  target_counts <- aggregate(
    rep(1, nrow(stage1_model_dataset)),
    by = stage1_model_dataset[, count_columns],
    FUN = sum
  )
  names(target_counts)[ncol(target_counts)] <- "target_count"

  group_totals <- aggregate(
    rep(1, nrow(stage1_model_dataset)),
    by = stage1_model_dataset[, group_columns],
    FUN = sum
  )
  names(group_totals)[ncol(group_totals)] <- "group_total"

  frequency_table <- merge(
    target_counts,
    group_totals,
    by = group_columns,
    all.x = TRUE,
    sort = FALSE
  )

  frequency_table$probability <- round(
    frequency_table$target_count / frequency_table$group_total,
    6
  )
  frequency_table$baseline_level <- baseline_level
  frequency_table$group_columns <- paste(group_columns, collapse = " + ")

  output_columns <- c(
    "baseline_level",
    "group_columns",
    group_columns,
    target_column,
    "target_count",
    "group_total",
    "probability"
  )

  frequency_table <- frequency_table[, output_columns]
  frequency_table <- frequency_table[order(
    frequency_table$baseline_level,
    -frequency_table$group_total,
    -frequency_table$probability,
    frequency_table[[target_column]]
  ), ]

  row.names(frequency_table) <- NULL
  frequency_table
}

build_all_frequency_tables <- function(stage1_model_dataset) {
  baseline_specs <- get_frequency_baseline_specs()

  all_tables <- lapply(baseline_specs, function(spec) {
    build_frequency_table(
      stage1_model_dataset = stage1_model_dataset,
      group_columns = spec$group_columns,
      baseline_level = spec$baseline_level
    )
  })

  all_columns <- unique(unlist(lapply(all_tables, names)))

  aligned_tables <- lapply(all_tables, function(table_item) {
    missing_columns <- setdiff(all_columns, names(table_item))

    for (column_name in missing_columns) {
      table_item[[column_name]] <- NA
    }

    table_item[, all_columns]
  })

  do.call(rbind, aligned_tables)
}

build_top_prediction_table <- function(frequency_table) {
  split_keys <- paste(
    frequency_table$baseline_level,
    frequency_table$group_columns,
    apply(
      frequency_table[, setdiff(
        names(frequency_table),
        c(
          "baseline_level",
          "group_columns",
          "stage1_target_momentum_state",
          "target_count",
          "group_total",
          "probability"
        )
      ), drop = FALSE],
      1,
      paste,
      collapse = "||"
    ),
    sep = "||"
  )

  frequency_table$split_key <- split_keys

  top_rows <- do.call(rbind, lapply(split(frequency_table, frequency_table$split_key), function(group_data) {
    group_data[order(-group_data$probability, -group_data$target_count), ][1, ]
  }))

  top_rows$split_key <- NULL
  row.names(top_rows) <- NULL

  top_rows[order(top_rows$baseline_level, -top_rows$group_total), ]
}

create_group_summary <- function(frequency_table) {
  baseline_levels <- unique(frequency_table$baseline_level)

  summary <- do.call(rbind, lapply(baseline_levels, function(level_name) {
    level_table <- frequency_table[frequency_table$baseline_level == level_name, ]
    level_group_columns <- strsplit(
      unique(level_table$group_columns),
      " + ",
      fixed = TRUE
    )[[1]]

    level_groups <- unique(level_table[, c(
      "baseline_level",
      "group_columns",
      level_group_columns,
      "group_total"
    )])

    data.frame(
      baseline_level = level_name,
      group_columns = unique(level_groups$group_columns),
      group_count = nrow(level_groups),
      min_group_total = min(level_groups$group_total),
      median_group_total = as.numeric(median(level_groups$group_total)),
      mean_group_total = round(mean(level_groups$group_total), 2),
      max_group_total = max(level_groups$group_total),
      groups_with_at_least_20_pa = sum(level_groups$group_total >= 20),
      groups_with_at_least_50_pa = sum(level_groups$group_total >= 50),
      groups_with_at_least_100_pa = sum(level_groups$group_total >= 100),
      stringsAsFactors = FALSE
    )
  }))

  row.names(summary) <- NULL
  summary
}

save_frequency_baseline_outputs <- function(
  frequency_table,
  top_prediction_table,
  group_summary,
  probability_path = "outputs/prediction/stage1_frequency_baseline_probabilities.csv",
  top_prediction_path = "outputs/prediction/stage1_frequency_baseline_top_predictions.csv",
  group_summary_path = "outputs/prediction/stage1_frequency_baseline_group_summary.csv"
) {
  output_dir <- dirname(probability_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(frequency_table, probability_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(top_prediction_table, top_prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(group_summary, group_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    probability_path = probability_path,
    top_prediction_path = top_prediction_path,
    group_summary_path = group_summary_path
  )
}

if (sys.nframe() == 0) {
  stage1_model_dataset <- load_stage1_model_dataset()

  frequency_table <- build_all_frequency_tables(stage1_model_dataset)
  top_prediction_table <- build_top_prediction_table(frequency_table)
  group_summary <- create_group_summary(frequency_table)

  output_paths <- save_frequency_baseline_outputs(
    frequency_table,
    top_prediction_table,
    group_summary
  )

  message("Saved Stage 1 frequency probabilities to: ", output_paths$probability_path)
  message("Saved Stage 1 top predictions to: ", output_paths$top_prediction_path)
  message("Saved Stage 1 group summary to: ", output_paths$group_summary_path)
  message("Probability rows: ", nrow(frequency_table))
  message("Top prediction rows: ", nrow(top_prediction_table))
  message("Group summary rows: ", nrow(group_summary))
}
