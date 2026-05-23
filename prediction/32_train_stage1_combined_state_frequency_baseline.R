#!/usr/bin/env Rscript

# Train and validate Stage 1 v2 combined_state frequency baseline.
# Run from the project root:
# Rscript prediction/32_train_stage1_combined_state_frequency_baseline.R

source("prediction/11_validate_stage1_frequency_baseline.R")

load_stage1_combined_state_model_dataset <- function(
  input_path = "data/cleaned/stage1_combined_state_model_dataset.csv"
) {
  if (!file.exists(input_path)) {
    stop("Stage 1 combined-state model dataset not found: ", input_path)
  }

  read.csv(input_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

get_combined_state_frequency_specs <- function() {
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
      minimum_group_total = 20
    ),
    list(
      baseline_level = "baseout_only",
      group_columns = c(
        "current_base_out_state"
      ),
      minimum_group_total = 1
    )
  )
}

build_combined_frequency_table <- function(
  dataset,
  group_columns,
  baseline_level,
  target_column = "stage1_target_combined_state"
) {
  required_columns <- c(group_columns, target_column)
  assert_required_columns(dataset, required_columns)

  count_columns <- c(group_columns, target_column)
  target_counts <- aggregate(
    rep(1, nrow(dataset)),
    by = dataset[, count_columns, drop = FALSE],
    FUN = sum
  )
  names(target_counts)[ncol(target_counts)] <- "target_count"

  group_totals <- aggregate(
    rep(1, nrow(dataset)),
    by = dataset[, group_columns, drop = FALSE],
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

  frequency_table[order(
    frequency_table$baseline_level,
    -frequency_table$group_total,
    -frequency_table$probability,
    frequency_table[[target_column]]
  ), ]
}

build_all_combined_frequency_tables <- function(train_dataset) {
  tables <- lapply(get_combined_state_frequency_specs(), function(spec) {
    build_combined_frequency_table(
      dataset = train_dataset,
      group_columns = spec$group_columns,
      baseline_level = spec$baseline_level
    )
  })

  all_columns <- unique(unlist(lapply(tables, names)))
  aligned_tables <- lapply(tables, function(table_item) {
    missing_columns <- setdiff(all_columns, names(table_item))
    for (column_name in missing_columns) {
      table_item[[column_name]] <- NA
    }
    table_item[, all_columns]
  })

  do.call(rbind, aligned_tables)
}

build_combined_top_prediction_table <- function(frequency_table) {
  metadata_columns <- c(
    "baseline_level",
    "group_columns",
    "stage1_target_combined_state",
    "target_count",
    "group_total",
    "probability"
  )
  context_columns <- setdiff(names(frequency_table), metadata_columns)

  frequency_table$split_key <- paste(
    frequency_table$baseline_level,
    frequency_table$group_columns,
    apply(frequency_table[, context_columns, drop = FALSE], 1, paste, collapse = "||"),
    sep = "||"
  )

  top_rows <- do.call(rbind, lapply(
    split(frequency_table, frequency_table$split_key),
    function(group_data) {
      group_data[order(-group_data$probability, -group_data$target_count), ][1, ]
    }
  ))
  top_rows$split_key <- NULL
  row.names(top_rows) <- NULL

  top_rows[order(top_rows$baseline_level, -top_rows$group_total), ]
}

make_combined_context_key <- function(dataset, group_columns) {
  assert_required_columns(dataset, group_columns)

  apply(dataset[, group_columns, drop = FALSE], 1, paste, collapse = "||")
}

prepare_combined_prediction_lookup <- function(top_prediction_table, spec) {
  group_columns <- spec$group_columns
  required_columns <- c(
    "baseline_level",
    group_columns,
    "stage1_target_combined_state",
    "probability",
    "group_total"
  )
  assert_required_columns(top_prediction_table, required_columns)

  lookup <- top_prediction_table[
    top_prediction_table$baseline_level == spec$baseline_level &
      top_prediction_table$group_total >= spec$minimum_group_total,
    required_columns
  ]
  lookup$context_key <- make_combined_context_key(lookup, group_columns)
  lookup <- lookup[, c(
    "context_key",
    "stage1_target_combined_state",
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

apply_combined_one_fallback_level <- function(prediction_dataset, top_prediction_table, spec) {
  lookup <- prepare_combined_prediction_lookup(top_prediction_table, spec)
  prediction_dataset$context_key <- make_combined_context_key(
    prediction_dataset,
    spec$group_columns
  )

  merged <- merge(
    prediction_dataset,
    lookup,
    by = "context_key",
    all.x = TRUE,
    sort = FALSE
  )

  has_prediction <- is.na(merged$predicted_combined_state) &
    !is.na(merged$candidate_prediction)

  merged$predicted_combined_state[has_prediction] <- merged$candidate_prediction[has_prediction]
  merged$predicted_probability[has_prediction] <- merged$candidate_probability[has_prediction]
  merged$used_baseline_level[has_prediction] <- spec$baseline_level
  merged$used_group_total[has_prediction] <- merged$candidate_group_total[has_prediction]

  merged$candidate_prediction <- NULL
  merged$candidate_probability <- NULL
  merged$candidate_group_total <- NULL
  merged$context_key <- NULL

  merged
}

apply_combined_state_frequency_baseline <- function(dataset, top_prediction_table) {
  prediction_dataset <- dataset
  prediction_dataset$row_id <- seq_len(nrow(prediction_dataset))
  prediction_dataset$predicted_combined_state <- NA_character_
  prediction_dataset$predicted_probability <- NA_real_
  prediction_dataset$used_baseline_level <- NA_character_
  prediction_dataset$used_group_total <- NA_integer_

  for (spec in get_combined_state_frequency_specs()) {
    prediction_dataset <- apply_combined_one_fallback_level(
      prediction_dataset,
      top_prediction_table,
      spec
    )
    prediction_dataset <- prediction_dataset[order(prediction_dataset$row_id), ]
  }

  prediction_dataset$is_correct_prediction <- (
    prediction_dataset$predicted_combined_state ==
      prediction_dataset$stage1_target_combined_state
  )

  prediction_dataset <- prediction_dataset[order(prediction_dataset$row_id), ]
  prediction_dataset$row_id <- NULL
  row.names(prediction_dataset) <- NULL

  prediction_dataset
}

create_combined_group_summary <- function(frequency_table) {
  do.call(rbind, lapply(unique(frequency_table$baseline_level), function(level_name) {
    level_table <- frequency_table[frequency_table$baseline_level == level_name, ]
    group_columns <- strsplit(unique(level_table$group_columns), " + ", fixed = TRUE)[[1]]
    level_groups <- unique(level_table[, c(
      "baseline_level",
      "group_columns",
      group_columns,
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
}

create_combined_frequency_validation_summary <- function(prediction_dataset, split_info) {
  split_counts <- as.data.frame(table(
    prediction_dataset$validation_split
  ), stringsAsFactors = FALSE)
  names(split_counts) <- c("summary_item", "count")
  split_counts$summary_group <- "split_rows"
  split_counts$proportion <- round(split_counts$count / nrow(prediction_dataset), 4)

  accuracy <- do.call(rbind, lapply(c("train", "test"), function(split_name) {
    split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]
    data.frame(
      summary_group = "accuracy",
      summary_item = paste0(split_name, "_accuracy"),
      count = sum(split_data$is_correct_prediction, na.rm = TRUE),
      proportion = round(mean(split_data$is_correct_prediction, na.rm = TRUE), 4),
      stringsAsFactors = FALSE
    )
  }))

  missing_predictions <- do.call(rbind, lapply(c("train", "test"), function(split_name) {
    split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]
    data.frame(
      summary_group = "missing_predictions",
      summary_item = split_name,
      count = sum(is.na(split_data$predicted_combined_state)),
      proportion = round(mean(is.na(split_data$predicted_combined_state)), 4),
      stringsAsFactors = FALSE
    )
  }))

  used_level_counts <- as.data.frame(table(
    prediction_dataset$validation_split,
    prediction_dataset$used_baseline_level
  ), stringsAsFactors = FALSE)
  names(used_level_counts) <- c("validation_split", "used_baseline_level", "count")
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
      used_level_counts$count[
        used_level_counts$validation_split == split_name
      ] / split_total,
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
      "train_start_date",
      "train_end_date",
      "test_start_date",
      "test_end_date"
    ),
    count = NA_integer_,
    proportion = NA_real_,
    value = c(
      as.character(split_info$train_start_date),
      as.character(split_info$train_end_date),
      as.character(split_info$test_start_date),
      as.character(split_info$test_end_date)
    ),
    stringsAsFactors = FALSE
  )

  summary_without_value <- rbind(
    split_counts[, c("summary_group", "summary_item", "count", "proportion")],
    accuracy[, c("summary_group", "summary_item", "count", "proportion")],
    missing_predictions[, c("summary_group", "summary_item", "count", "proportion")],
    used_level_counts
  )
  summary_without_value$value <- NA_character_

  rbind(
    split_metadata,
    summary_without_value[, c("summary_group", "summary_item", "count", "proportion", "value")]
  )
}

create_combined_class_metrics <- function(prediction_dataset, split_name = "test") {
  split_data <- prediction_dataset[prediction_dataset$validation_split == split_name, ]
  classes <- sort(unique(split_data$stage1_target_combined_state))

  do.call(rbind, lapply(classes, function(class_name) {
    actual_positive <- split_data$stage1_target_combined_state == class_name
    predicted_positive <- split_data$predicted_combined_state == class_name

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
      validation_split = split_name,
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

save_combined_state_frequency_outputs <- function(
  frequency_table,
  top_prediction_table,
  group_summary,
  prediction_dataset,
  validation_summary,
  class_metrics,
  probability_path = "outputs/prediction/stage1_combined_state_frequency_probabilities.csv",
  top_prediction_path = "outputs/prediction/stage1_combined_state_frequency_top_predictions.csv",
  group_summary_path = "outputs/prediction/stage1_combined_state_frequency_group_summary.csv",
  prediction_path = "outputs/prediction/stage1_combined_state_frequency_predictions.csv",
  validation_summary_path = "outputs/prediction/stage1_combined_state_frequency_validation_summary.csv",
  class_metrics_path = "outputs/prediction/stage1_combined_state_frequency_class_metrics.csv"
) {
  output_dir <- dirname(probability_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(frequency_table, probability_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(top_prediction_table, top_prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(group_summary, group_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(prediction_dataset, prediction_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(validation_summary, validation_summary_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(class_metrics, class_metrics_path, row.names = FALSE, fileEncoding = "UTF-8")

  list(
    probability_path = probability_path,
    top_prediction_path = top_prediction_path,
    group_summary_path = group_summary_path,
    prediction_path = prediction_path,
    validation_summary_path = validation_summary_path,
    class_metrics_path = class_metrics_path
  )
}

if (sys.nframe() == 0) {
  combined_dataset <- load_stage1_combined_state_model_dataset()
  split_info <- create_chronological_split(combined_dataset)
  split_dataset <- split_info$dataset
  train_dataset <- split_dataset[split_dataset$validation_split == "train", ]

  frequency_table <- build_all_combined_frequency_tables(train_dataset)
  top_prediction_table <- build_combined_top_prediction_table(frequency_table)
  group_summary <- create_combined_group_summary(frequency_table)
  prediction_dataset <- apply_combined_state_frequency_baseline(
    split_dataset,
    top_prediction_table
  )
  validation_summary <- create_combined_frequency_validation_summary(
    prediction_dataset,
    split_info
  )
  class_metrics <- create_combined_class_metrics(prediction_dataset)

  output_paths <- save_combined_state_frequency_outputs(
    frequency_table,
    top_prediction_table,
    group_summary,
    prediction_dataset,
    validation_summary,
    class_metrics
  )

  message("Saved Stage 1 combined-state frequency probabilities to: ", output_paths$probability_path)
  message("Saved Stage 1 combined-state top predictions to: ", output_paths$top_prediction_path)
  message("Saved Stage 1 combined-state group summary to: ", output_paths$group_summary_path)
  message("Saved Stage 1 combined-state predictions to: ", output_paths$prediction_path)
  message("Saved Stage 1 combined-state validation summary to: ", output_paths$validation_summary_path)
  message("Saved Stage 1 combined-state class metrics to: ", output_paths$class_metrics_path)
}
