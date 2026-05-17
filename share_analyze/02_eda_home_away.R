#!/usr/bin/env Rscript

# Exploratory analysis for CPBL 2024 home-away performance patterns.

load_feature_data <- function(
  team_game_path = "data/cleaned/team_game_features.csv",
  summary_path = "data/cleaned/team_home_away_summary.csv"
) {
  if (!file.exists(team_game_path)) {
    stop("Team-game feature file not found: ", team_game_path)
  }

  if (!file.exists(summary_path)) {
    stop("Home-away summary file not found: ", summary_path)
  }

  list(
    team_game = read.csv(team_game_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM"),
    home_away_summary = read.csv(summary_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
  )
}

summarize_home_away_patterns <- function(team_game) {
  home_away_groups <- split(team_game, team_game$home_away_label)

  summary_rows <- lapply(names(home_away_groups), function(label) {
    group_data <- home_away_groups[[label]]

    data.frame(
      home_away_label = label,
      games = nrow(group_data),
      win_rate = mean(group_data$win, na.rm = TRUE),
      avg_runs_scored = mean(group_data$runs_scored, na.rm = TRUE),
      avg_runs_allowed = mean(group_data$runs_allowed, na.rm = TRUE),
      avg_run_diff = mean(group_data$run_diff, na.rm = TRUE),
      avg_offense_pressure = mean(group_data$offense_pressure_score, na.rm = TRUE),
      avg_run_prevention = mean(group_data$run_prevention_score, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, summary_rows)
}

plot_home_away_win_rate <- function(
  home_away_summary,
  output_path = "outputs/eda_home_away/team_home_away_win_rate.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw EDA plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- rbind(
    data.frame(
      team = home_away_summary$team,
      location = "主場",
      win_rate = home_away_summary$home_win_rate,
      stringsAsFactors = FALSE
    ),
    data.frame(
      team = home_away_summary$team,
      location = "客場",
      win_rate = home_away_summary$away_win_rate,
      stringsAsFactors = FALSE
    )
  )

  plot_df$location <- factor(plot_df$location, levels = c("主場", "客場"))

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = team, y = win_rate, fill = location)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75), width = 0.65) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 0.75)) +
    ggplot2::labs(
      title = "各隊主客場勝率比較",
      x = "球隊",
      y = "勝率",
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

plot_home_away_run_diff <- function(
  home_away_summary,
  output_path = "outputs/eda_home_away/team_home_away_run_diff.png"
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required to draw EDA plots.")
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  plot_df <- rbind(
    data.frame(
      team = home_away_summary$team,
      location = "主場",
      avg_run_diff = home_away_summary$home_avg_run_diff,
      stringsAsFactors = FALSE
    ),
    data.frame(
      team = home_away_summary$team,
      location = "客場",
      avg_run_diff = home_away_summary$away_avg_run_diff,
      stringsAsFactors = FALSE
    )
  )

  plot_df$location <- factor(plot_df$location, levels = c("主場", "客場"))

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = team, y = avg_run_diff, fill = location)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray45", linewidth = 0.4) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75), width = 0.65) +
    ggplot2::labs(
      title = "各隊主客場平均分差比較",
      x = "球隊",
      y = "平均分差",
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
  feature_data <- load_feature_data()
  overall_summary <- summarize_home_away_patterns(feature_data$team_game)

  output_dir <- "outputs/eda_home_away"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  overall_summary_path <- file.path(output_dir, "home_away_overall_summary.csv")
  write.csv(overall_summary, overall_summary_path, row.names = FALSE, fileEncoding = "UTF-8")

  win_rate_plot_path <- plot_home_away_win_rate(feature_data$home_away_summary)
  run_diff_plot_path <- plot_home_away_run_diff(feature_data$home_away_summary)

  message("Saved overall summary to: ", overall_summary_path)
  message("Saved win-rate plot to: ", win_rate_plot_path)
  message("Saved run-diff plot to: ", run_diff_plot_path)
}
