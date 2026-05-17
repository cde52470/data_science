#!/usr/bin/env Rscript

# Build a team-game-level dataset from CPBL 2024 open data.
# Each game becomes two rows: one for the away team and one for the home team.

load_cpbl_data <- function(
  raw_path = "data/raw/CPBL-2024-OpenData/CPBL-2024-OpenData.json",
  cleaned_path = "data/cleaned/cpbl_games_cleaned.csv"
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required. Please install it before running this script.")
  }

  if (!file.exists(raw_path)) {
    stop("Raw data file not found: ", raw_path)
  }

  if (!file.exists(cleaned_path)) {
    stop("Cleaned data file not found: ", cleaned_path)
  }

  raw_games <- jsonlite::fromJSON(raw_path, simplifyVector = FALSE)
  cleaned_games <- read.csv(cleaned_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")

  list(
    raw_games = raw_games,
    cleaned_games = cleaned_games
  )
}

sum_scores <- function(scores) {
  sum(as.numeric(unlist(scores)), na.rm = TRUE)
}

build_team_game_base <- function(raw_games) {
  rows <- vector("list", length(raw_games) * 2)
  row_index <- 1

  for (game in raw_games) {
    away_runs <- sum_scores(game$awayScores)
    home_runs <- sum_scores(game$homeScores)
    game_id <- paste0(game$seasonId, "-", game$seq)

    rows[[row_index]] <- data.frame(
      game_id = game_id,
      season = game$season,
      seq = game$seq,
      date = game$date,
      stadium = game$stadium,
      team = game$awayTeam,
      opponent = game$homeTeam,
      is_home = FALSE,
      runs_scored = away_runs,
      runs_allowed = home_runs,
      run_diff = away_runs - home_runs,
      win = away_runs > home_runs,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1

    rows[[row_index]] <- data.frame(
      game_id = game_id,
      season = game$season,
      seq = game$seq,
      date = game$date,
      stadium = game$stadium,
      team = game$homeTeam,
      opponent = game$awayTeam,
      is_home = TRUE,
      runs_scored = home_runs,
      runs_allowed = away_runs,
      run_diff = home_runs - away_runs,
      win = home_runs > away_runs,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1
  }

  do.call(rbind, rows)
}

add_game_result_labels <- function(team_game_df) {
  team_game_df$home_away_label <- ifelse(team_game_df$is_home, "主場", "客場")

  team_game_df$result_label <- ifelse(
    team_game_df$win,
    "勝",
    ifelse(team_game_df$run_diff == 0, "和局", "敗")
  )

  team_game_df$run_diff_label <- ifelse(
    team_game_df$run_diff >= 5,
    "大勝",
    ifelse(
      team_game_df$run_diff > 0,
      "小勝",
      ifelse(
        team_game_df$run_diff == 0,
        "平手",
        ifelse(team_game_df$run_diff <= -5, "大敗", "小敗")
      )
    )
  )

  team_game_df$scoring_level <- ifelse(
    team_game_df$runs_scored >= 6,
    "高得分",
    ifelse(team_game_df$runs_scored >= 3, "中等得分", "低得分")
  )

  team_game_df$allowing_level <- ifelse(
    team_game_df$runs_allowed >= 6,
    "高失分",
    ifelse(team_game_df$runs_allowed >= 3, "中等失分", "低失分")
  )

  team_game_df
}

add_game_flow_features <- function(team_game_df, raw_games) {
  flow_rows <- vector("list", length(raw_games) * 2)
  row_index <- 1

  for (game in raw_games) {
    away_scores <- as.numeric(unlist(game$awayScores))
    home_scores <- as.numeric(unlist(game$homeScores))
    game_id <- paste0(game$seasonId, "-", game$seq)

    away_cumulative <- cumsum(away_scores)
    home_cumulative <- cumsum(home_scores)
    away_after_3 <- if (length(away_cumulative) >= 3) away_cumulative[3] else tail(away_cumulative, 1)
    home_after_3 <- if (length(home_cumulative) >= 3) home_cumulative[3] else tail(home_cumulative, 1)
    away_after_6 <- if (length(away_cumulative) >= 6) away_cumulative[6] else tail(away_cumulative, 1)
    home_after_6 <- if (length(home_cumulative) >= 6) home_cumulative[6] else tail(home_cumulative, 1)
    first_away_inning <- which(away_scores > 0)[1]
    first_home_inning <- which(home_scores > 0)[1]

    away_scored_first <- !is.na(first_away_inning) &&
      (is.na(first_home_inning) || first_away_inning < first_home_inning)
    home_scored_first <- !is.na(first_home_inning) &&
      (is.na(first_away_inning) || first_home_inning < first_away_inning)

    flow_rows[[row_index]] <- data.frame(
      game_id = game_id,
      team = game$awayTeam,
      early_runs = sum(away_scores[1:3], na.rm = TRUE),
      middle_runs = sum(away_scores[4:6], na.rm = TRUE),
      late_runs = sum(away_scores[7:9], na.rm = TRUE),
      scored_first = away_scored_first,
      led_after_3 = away_after_3 > home_after_3,
      led_after_6 = away_after_6 > home_after_6,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1

    flow_rows[[row_index]] <- data.frame(
      game_id = game_id,
      team = game$homeTeam,
      early_runs = sum(home_scores[1:3], na.rm = TRUE),
      middle_runs = sum(home_scores[4:6], na.rm = TRUE),
      late_runs = sum(home_scores[7:9], na.rm = TRUE),
      scored_first = home_scored_first,
      led_after_3 = home_after_3 > away_after_3,
      led_after_6 = home_after_6 > away_after_6,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1
  }

  flow_df <- do.call(rbind, flow_rows)
  team_game_df <- merge(team_game_df, flow_df, by = c("game_id", "team"), all.x = TRUE)

  team_game_df$game_flow_label <- ifelse(
    team_game_df$win & team_game_df$led_after_3 & team_game_df$led_after_6,
    "全場壓制型",
    ifelse(
      team_game_df$win & !team_game_df$led_after_6 & team_game_df$late_runs > 0,
      "後段逆轉型",
      ifelse(
        team_game_df$win & team_game_df$led_after_3,
        "前段領先型",
        ifelse(
          !team_game_df$win & !team_game_df$led_after_3 & !team_game_df$led_after_6,
          "被壓制型",
          ifelse(team_game_df$late_runs > team_game_df$early_runs, "後段追分型", "拉鋸型")
        )
      )
    )
  )

  team_game_df
}

# Offensive features based on batting box scores and scoring patterns.
add_offense_features <- function(team_game_df, raw_games) {
  offense_rows <- vector("list", length(raw_games) * 2)
  row_index <- 1

  for (game in raw_games) {
    game_id <- paste0(game$seasonId, "-", game$seq)

    away_ab <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "AB")), na.rm = TRUE)
    away_h <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "H")), na.rm = TRUE)
    away_bb <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "BB")), na.rm = TRUE)
    away_so <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "SO")), na.rm = TRUE)
    away_double <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "2B")), na.rm = TRUE)
    away_triple <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "3B")), na.rm = TRUE)
    away_hr <- sum(as.numeric(sapply(game$awayBatterBox, "[[", "HR")), na.rm = TRUE)
    away_runs <- sum_scores(game$awayScores)
    away_extra_base_hits <- away_double + away_triple + away_hr
    away_power_score <- away_double + (2 * away_triple) + (3 * away_hr)
    away_run_per_hit <- ifelse(away_h > 0, away_runs / away_h, 0)
    away_offense_pressure_score <- away_runs + away_bb + away_extra_base_hits - (0.5 * away_so)

    offense_rows[[row_index]] <- data.frame(
      game_id = game_id,
      team = game$awayTeam,
      AB = away_ab,
      H = away_h,
      BB = away_bb,
      SO = away_so,
      double = away_double,
      triple = away_triple,
      HR = away_hr,
      extra_base_hits = away_extra_base_hits,
      power_score = away_power_score,
      run_per_hit = away_run_per_hit,
      offense_pressure_score = away_offense_pressure_score,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1

    home_ab <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "AB")), na.rm = TRUE)
    home_h <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "H")), na.rm = TRUE)
    home_bb <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "BB")), na.rm = TRUE)
    home_so <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "SO")), na.rm = TRUE)
    home_double <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "2B")), na.rm = TRUE)
    home_triple <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "3B")), na.rm = TRUE)
    home_hr <- sum(as.numeric(sapply(game$homeBatterBox, "[[", "HR")), na.rm = TRUE)
    home_runs <- sum_scores(game$homeScores)
    home_extra_base_hits <- home_double + home_triple + home_hr
    home_power_score <- home_double + (2 * home_triple) + (3 * home_hr)
    home_run_per_hit <- ifelse(home_h > 0, home_runs / home_h, 0)
    home_offense_pressure_score <- home_runs + home_bb + home_extra_base_hits - (0.5 * home_so)

    offense_rows[[row_index]] <- data.frame(
      game_id = game_id,
      team = game$homeTeam,
      AB = home_ab,
      H = home_h,
      BB = home_bb,
      SO = home_so,
      double = home_double,
      triple = home_triple,
      HR = home_hr,
      extra_base_hits = home_extra_base_hits,
      power_score = home_power_score,
      run_per_hit = home_run_per_hit,
      offense_pressure_score = home_offense_pressure_score,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1
  }

  offense_df <- do.call(rbind, offense_rows)
  team_game_df <- merge(team_game_df, offense_df, by = c("game_id", "team"), all.x = TRUE)

  team_game_df$offense_label <- ifelse(
    team_game_df$runs_scored >= 6 & team_game_df$extra_base_hits >= 3,
    "火力強勢",
    ifelse(
      team_game_df$runs_scored >= 3 & team_game_df$H >= 8,
      "穩定攻擊",
      ifelse(
        team_game_df$runs_scored <= 2 & team_game_df$SO >= 8,
        "攻勢受阻",
        ifelse(team_game_df$runs_scored <= 2, "低效進攻", "零星攻勢")
      )
    )
  )

  team_game_df
}

# Defensive features based on pitching box scores and defensive performance metrics.
add_defense_pitching_features <- function(team_game_df, raw_games) {
  defense_rows <- vector("list", length(raw_games) * 2)
  row_index <- 1

  for (game in raw_games) {
    game_id <- paste0(game$seasonId, "-", game$seq)

    away_outs <- sum(as.numeric(sapply(game$awayPitcherBox, "[[", "IPOuts")), na.rm = TRUE)
    away_hits_allowed <- sum(as.numeric(sapply(game$awayPitcherBox, "[[", "H")), na.rm = TRUE)
    away_bb_allowed <- sum(as.numeric(sapply(game$awayPitcherBox, "[[", "BB")), na.rm = TRUE)
    away_hr_allowed <- sum(as.numeric(sapply(game$awayPitcherBox, "[[", "HR")), na.rm = TRUE)
    away_so_pitched <- sum(as.numeric(sapply(game$awayPitcherBox, "[[", "SO")), na.rm = TRUE)
    away_runs_allowed <- sum(as.numeric(sapply(game$awayPitcherBox, "[[", "R")), na.rm = TRUE)
    away_innings_pitched <- away_outs / 3
    away_whip_like <- ifelse(
      away_innings_pitched > 0,
      (away_hits_allowed + away_bb_allowed) / away_innings_pitched,
      NA
    )
    away_strikeout_walk_ratio <- ifelse(
      away_bb_allowed > 0,
      away_so_pitched / away_bb_allowed,
      away_so_pitched
    )
    away_run_prevention_score <- away_so_pitched - away_bb_allowed - away_hr_allowed - away_runs_allowed

    defense_rows[[row_index]] <- data.frame(
      game_id = game_id,
      team = game$awayTeam,
      outs_pitched = away_outs,
      innings_pitched = away_innings_pitched,
      hits_allowed = away_hits_allowed,
      bb_allowed = away_bb_allowed,
      hr_allowed = away_hr_allowed,
      so_pitched = away_so_pitched,
      whip_like = away_whip_like,
      strikeout_walk_ratio = away_strikeout_walk_ratio,
      run_prevention_score = away_run_prevention_score,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1

    home_outs <- sum(as.numeric(sapply(game$homePitcherBox, "[[", "IPOuts")), na.rm = TRUE)
    home_hits_allowed <- sum(as.numeric(sapply(game$homePitcherBox, "[[", "H")), na.rm = TRUE)
    home_bb_allowed <- sum(as.numeric(sapply(game$homePitcherBox, "[[", "BB")), na.rm = TRUE)
    home_hr_allowed <- sum(as.numeric(sapply(game$homePitcherBox, "[[", "HR")), na.rm = TRUE)
    home_so_pitched <- sum(as.numeric(sapply(game$homePitcherBox, "[[", "SO")), na.rm = TRUE)
    home_runs_allowed <- sum(as.numeric(sapply(game$homePitcherBox, "[[", "R")), na.rm = TRUE)
    home_innings_pitched <- home_outs / 3
    home_whip_like <- ifelse(
      home_innings_pitched > 0,
      (home_hits_allowed + home_bb_allowed) / home_innings_pitched,
      NA
    )
    home_strikeout_walk_ratio <- ifelse(
      home_bb_allowed > 0,
      home_so_pitched / home_bb_allowed,
      home_so_pitched
    )
    home_run_prevention_score <- home_so_pitched - home_bb_allowed - home_hr_allowed - home_runs_allowed

    defense_rows[[row_index]] <- data.frame(
      game_id = game_id,
      team = game$homeTeam,
      outs_pitched = home_outs,
      innings_pitched = home_innings_pitched,
      hits_allowed = home_hits_allowed,
      bb_allowed = home_bb_allowed,
      hr_allowed = home_hr_allowed,
      so_pitched = home_so_pitched,
      whip_like = home_whip_like,
      strikeout_walk_ratio = home_strikeout_walk_ratio,
      run_prevention_score = home_run_prevention_score,
      stringsAsFactors = FALSE
    )
    row_index <- row_index + 1
  }

  defense_df <- do.call(rbind, defense_rows)
  team_game_df <- merge(team_game_df, defense_df, by = c("game_id", "team"), all.x = TRUE)

  team_game_df$defense_label <- ifelse(
    team_game_df$runs_allowed <= 2 & team_game_df$whip_like <= 1.2,
    "壓制力強",
    ifelse(
      team_game_df$runs_allowed <= 4 & team_game_df$run_prevention_score >= 0,
      "穩定守成",
      ifelse(
        team_game_df$runs_allowed >= 6 & team_game_df$whip_like >= 1.8,
        "投打被突破",
        ifelse(team_game_df$runs_allowed >= 5, "失分偏高", "普通防守")
      )
    )
  )

  team_game_df
}

save_team_game_features <- function(
  team_game_df,
  output_path = "data/cleaned/team_game_features.csv"
) {
  output_dir <- dirname(output_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(team_game_df, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  output_path
}

# Build a summary of home vs away performance for each team.
build_home_away_summary <- function(team_game_df) {
  teams <- sort(unique(team_game_df$team))
  summary_rows <- vector("list", length(teams))

  for (i in seq_along(teams)) {
    team_data <- team_game_df[team_game_df$team == teams[i], ]
    home_data <- team_data[team_data$is_home, ]
    away_data <- team_data[!team_data$is_home, ]

    home_win_rate <- mean(home_data$win, na.rm = TRUE)
    away_win_rate <- mean(away_data$win, na.rm = TRUE)
    home_avg_run_diff <- mean(home_data$run_diff, na.rm = TRUE)
    away_avg_run_diff <- mean(away_data$run_diff, na.rm = TRUE)
    home_advantage_score <- (home_win_rate - away_win_rate) +
      ((home_avg_run_diff - away_avg_run_diff) / 10)

    summary_rows[[i]] <- data.frame(
      team = teams[i],
      home_games = nrow(home_data),
      away_games = nrow(away_data),
      home_win_rate = home_win_rate,
      away_win_rate = away_win_rate,
      home_avg_runs_scored = mean(home_data$runs_scored, na.rm = TRUE),
      away_avg_runs_scored = mean(away_data$runs_scored, na.rm = TRUE),
      home_avg_runs_allowed = mean(home_data$runs_allowed, na.rm = TRUE),
      away_avg_runs_allowed = mean(away_data$runs_allowed, na.rm = TRUE),
      home_avg_run_diff = home_avg_run_diff,
      away_avg_run_diff = away_avg_run_diff,
      home_offense_pressure_avg = mean(home_data$offense_pressure_score, na.rm = TRUE),
      away_offense_pressure_avg = mean(away_data$offense_pressure_score, na.rm = TRUE),
      home_run_prevention_avg = mean(home_data$run_prevention_score, na.rm = TRUE),
      away_run_prevention_avg = mean(away_data$run_prevention_score, na.rm = TRUE),
      home_advantage_score = home_advantage_score,
      stringsAsFactors = FALSE
    )
  }

  summary_df <- do.call(rbind, summary_rows)
  summary_df$home_advantage_label <- ifelse(
    summary_df$home_advantage_score >= 0.15,
    "主場優勢明顯",
    ifelse(
      summary_df$home_advantage_score <= -0.15,
      "客場表現較佳",
      "主客差異小"
    )
  )

  summary_df
}

save_home_away_summary <- function(
  home_away_summary,
  output_path = "data/cleaned/team_home_away_summary.csv"
) {
  output_dir <- dirname(output_path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write.csv(home_away_summary, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  output_path
}

if (sys.nframe() == 0) {
  cpbl_data <- load_cpbl_data()
  team_game_base <- build_team_game_base(cpbl_data$raw_games)
  team_game_features <- add_game_result_labels(team_game_base)
  team_game_features <- add_game_flow_features(team_game_features, cpbl_data$raw_games)
  team_game_features <- add_offense_features(team_game_features, cpbl_data$raw_games)
  team_game_features <- add_defense_pitching_features(team_game_features, cpbl_data$raw_games)
  output_path <- save_team_game_features(team_game_features)
  summary_output_path <- save_home_away_summary(build_home_away_summary(team_game_features))

  message("Saved team-game features to: ", output_path)
  message("Saved home-away summary to: ", summary_output_path)
  message("Rows: ", nrow(team_game_features))
  message("Columns: ", ncol(team_game_features))
}
