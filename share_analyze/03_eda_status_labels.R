#!/usr/bin/env Rscript

# Exploratory analysis for semantic status labels by home-away context.

load_team_game_features <- function(
  path = "data/cleaned/team_game_features.csv"
) {
  if (!file.exists(path)) {
    stop("Team-game feature file not found: ", path)
  }

  read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
}

summarize_label_by_home_away <- function(team_game_df, label_column) {
  if (!label_column %in% names(team_game_df)) {
    stop("Label column not found: ", label_column)
  }

  count_df <- as.data.frame(
    table(
      label = team_game_df[[label_column]],
      home_away_label = team_game_df$home_away_label
    ),
    stringsAsFactors = FALSE
  )
  names(count_df) <- c(label_column, "home_away_label", "count")

  total_by_location <- aggregate(
    count ~ home_away_label,
    data = count_df,
    FUN = sum
  )
  names(total_by_location)[2] <- "total"

  summary_df <- merge(count_df, total_by_location, by = "home_away_label", all.x = TRUE)
  summary_df$proportion <- ifelse(summary_df$total > 0, summary_df$count / summary_df$total, 0)
  summary_df <- summary_df[summary_df$count > 0, ]
  summary_df[order(summary_df$home_away_label, summary_df[[label_column]]), ]
}

plot_label_distribution <- function(summary_df, label_column, output_path) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw EDA plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  summary_df$home_away_label <- factor(summary_df$home_away_label, levels = c("主場", "客場"))

  p <- ggplot2::ggplot(
    summary_df,
    ggplot2::aes(x = .data[[label_column]], y = proportion, fill = home_away_label)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75), width = 0.65) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(
      title = paste0(label_column, " 主客場分布"),
      x = "狀態標籤",
      y = "比例",
      fill = "場地"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 25, hjust = 1),
      panel.grid.minor = ggplot2::element_blank()
    )

  ggplot2::ggsave(output_path, p, width = 9, height = 5, dpi = 150)
  output_path
}

if (sys.nframe() == 0) {
  team_game <- load_team_game_features()
  output_dir <- "outputs/eda_status_labels"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  label_columns <- c(
    "offense_label",
    "defense_label",
    "game_flow_label",
    "scoring_level",
    "allowing_level"
  )

  for (label_column in label_columns) {
    summary_df <- summarize_label_by_home_away(team_game, label_column)
    csv_path <- file.path(output_dir, paste0(label_column, "_by_home_away.csv"))
    plot_path <- file.path(output_dir, paste0(label_column, "_by_home_away.png"))

    write.csv(summary_df, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
    plot_label_distribution(summary_df, label_column, plot_path)

    message("Saved summary to: ", csv_path)
    message("Saved plot to: ", plot_path)
  }
}
