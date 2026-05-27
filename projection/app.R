library(shiny)

app_root <- normalizePath(getwd(), mustWork = FALSE)
if (basename(app_root) != "projection") {
  app_root <- normalizePath(file.path(getwd(), "projection"), mustWork = FALSE)
}

bridge_output_path <- file.path(
  app_root,
  "data/stage1_result_state_stage2_win_bridge_output.csv"
)

if (!file.exists(bridge_output_path)) {
  stop("Missing Stage 1 result-state Stage 2 bridge output: ", bridge_output_path)
}

bridge_data <- read.csv(bridge_output_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")

batter_profile_path <- file.path(app_root, "data/batter_type_profile.csv")
pitcher_profile_path <- file.path(app_root, "data/pitcher_type_profile.csv")

if (!file.exists(batter_profile_path)) {
  stop("Missing batter profile: ", batter_profile_path)
}
if (!file.exists(pitcher_profile_path)) {
  stop("Missing pitcher profile: ", pitcher_profile_path)
}

batter_profile <- read.csv(batter_profile_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
pitcher_profile <- read.csv(pitcher_profile_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")

result_states <- c(
  "no_score_stable",
  "wasted_chance",
  "score_once",
  "score_multiple",
  "big_inning"
)

result_probability_columns <- paste0("prob_result_state_", result_states)
result_win_columns <- paste0("win_probability_if_", result_states)

derive_inning_phase <- function(inning) {
  ifelse(
    inning <= 3,
    "early",
    ifelse(inning <= 6, "middle", ifelse(inning <= 9, "late", "extra"))
  )
}

bucket_score_diff <- function(score_diff) {
  ifelse(
    score_diff <= -4,
    "big_deficit",
    ifelse(
      score_diff <= -2,
      "small_deficit",
      ifelse(
        score_diff == -1,
        "one_run_deficit",
        ifelse(
          score_diff == 0,
          "tied",
          ifelse(score_diff == 1, "one_run_lead", ifelse(score_diff <= 3, "small_lead", "big_lead"))
        )
      )
    )
  )
}

label_result_state_zh <- function(result_state) {
  labels <- c(
    no_score_stable = "安靜無得分",
    wasted_chance = "攻勢浪費",
    score_once = "單分進帳",
    score_multiple = "多分進帳",
    big_inning = "大局形成"
  )
  unname(ifelse(result_state %in% names(labels), labels[result_state], result_state))
}

label_inning_phase_zh <- function(phase) {
  labels <- c(
    early = "前段 1-3 局",
    middle = "中段 4-6 局",
    late = "後段 7-9 局",
    extra = "延長賽"
  )
  unname(ifelse(phase %in% names(labels), labels[phase], phase))
}

label_score_diff_bucket_zh <- function(bucket) {
  labels <- c(
    big_deficit = "大幅落後 4+ 分",
    small_deficit = "落後 2-3 分",
    one_run_deficit = "落後 1 分",
    tied = "平手",
    one_run_lead = "領先 1 分",
    small_lead = "領先 2-3 分",
    big_lead = "大幅領先 4+ 分"
  )
  unname(ifelse(bucket %in% names(labels), labels[bucket], bucket))
}

label_home_away_zh <- function(context) {
  labels <- c(
    home_batting = "主場進攻",
    away_batting = "客場進攻"
  )
  unname(ifelse(context %in% names(labels), labels[context], context))
}

label_base_out_zh <- function(base_out_state) {
  parts <- strsplit(base_out_state, "_", fixed = TRUE)
  vapply(parts, function(tokens) {
    outs <- tokens[1]
    base_tokens <- tokens[-c(1, 2)]
    outs_zh <- paste0(outs, " 出局")

    bases_zh <- if (length(base_tokens) == 0 || identical(base_tokens, "empty")) {
      "無人在壘"
    } else {
      base_labels <- c("1b" = "一壘", "2b" = "二壘", "3b" = "三壘")
      paste(base_labels[base_tokens], collapse = "、")
    }

    paste(outs_zh, bases_zh)
  }, character(1))
}

label_batter_type_zh <- function(batter_type) {
  labels <- c(
    balanced_hitter = "均衡型打者",
    contact_hitter = "接觸型打者",
    high_risk_hitter = "高風險打者",
    limited_sample_hitter = "樣本不足打者",
    patient_hitter = "選球型打者",
    power_hitter = "長打型打者",
    productive_hitter = "高產出打者",
    weak_offense = "弱攻擊打者"
  )
  unname(ifelse(batter_type %in% names(labels), labels[batter_type], batter_type))
}

label_pitcher_type_zh <- function(pitcher_type) {
  labels <- c(
    balanced_pitcher = "均衡型投手",
    contact_suppressor = "壓制接觸投手",
    control_pitcher = "控球型投手",
    homer_prone = "容易被長打投手",
    limited_sample_pitcher = "樣本不足投手",
    power_pitcher = "力量型投手",
    run_prevention_pitcher = "失分抑制型投手",
    vulnerable_pitcher = "高風險投手",
    walk_prone = "保送風險投手"
  )
  unname(ifelse(pitcher_type %in% names(labels), labels[pitcher_type], pitcher_type))
}

make_named_choices <- function(values, label_function) {
  values <- sort(unique(values))
  labels <- label_function(values)
  stats::setNames(values, labels)
}

format_percent <- function(value) {
  paste0(sprintf("%.1f", value * 100), "%")
}

format_number <- function(value, digits = 3) {
  sprintf(paste0("%.", digits, "f"), value)
}

safe_mean <- function(values) {
  mean(values, na.rm = TRUE)
}

input_number <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value)) {
    return(0)
  }
  as.numeric(value)
}

score_input <- function(id, value = 0, disabled = FALSE) {
  tags$input(
    id = id,
    type = "number",
    class = "form-control",
    value = value,
    min = 0,
    max = 30,
    step = 1,
    disabled = if (disabled) "disabled" else NULL
  )
}

make_scoreboard_inputs <- function(current_inning, half_inning, scores) {
  current_inning <- max(1, min(12, current_inning))
  inning_cells <- lapply(1:9, function(inning) {
    div(class = "inning-label", inning)
  })
  away_cells <- lapply(1:9, function(inning) {
    value <- scores$away[inning]
    disabled <- inning > current_inning || (inning == current_inning && identical(half_inning, "top"))
    score_input(paste0("away_score_", inning), value = value, disabled = disabled)
  })
  home_cells <- lapply(1:9, function(inning) {
    value <- scores$home[inning]
    disabled <- inning >= current_inning
    score_input(paste0("home_score_", inning), value = value, disabled = disabled)
  })

  tagList(
    div(class = "score-row score-header", div("Team"), inning_cells, div("R")),
    div(class = "score-row", div(class = "team-cell", textOutput("away_scoreboard_team", inline = TRUE)), away_cells, div(class = "run-total", textOutput("away_total", inline = TRUE))),
    div(class = "score-row", div(class = "team-cell", textOutput("home_scoreboard_team", inline = TRUE)), home_cells, div(class = "run-total", textOutput("home_total", inline = TRUE)))
  )
}

get_batter_profile <- function(batter_name) {
  profile <- batter_profile[batter_profile$batter_name == batter_name, ]
  if (nrow(profile) == 0) {
    return(NULL)
  }
  profile[1, ]
}

get_pitcher_profile <- function(pitcher_name) {
  profile <- pitcher_profile[pitcher_profile$pitcher_name == pitcher_name, ]
  if (nrow(profile) == 0) {
    return(NULL)
  }
  profile[1, ]
}

lookup_matching_rows <- function(input_row, specs) {
  for (spec in specs) {
    matched <- rep(TRUE, nrow(bridge_data))
    for (column_name in spec$columns) {
      matched <- matched & bridge_data[[column_name]] == input_row[[column_name]]
    }
    matched_data <- bridge_data[matched, ]

    if (nrow(matched_data) >= spec$minimum_rows) {
      return(list(
        data = matched_data,
        lookup_level = spec$level,
        lookup_rows = nrow(matched_data)
      ))
    }
  }

  list(
    data = bridge_data,
    lookup_level = "global",
    lookup_rows = nrow(bridge_data)
  )
}

lookup_stage1_result_distribution <- function(input_row) {
  specs <- list(
    list(
      level = "baseout_phase_score_home_batter_pitcher",
      columns = c(
        "current_base_out_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context",
        "batter_name",
        "pitcher_name"
      ),
      minimum_rows = 3
    ),
    list(
      level = "baseout_phase_score_home_player",
      columns = c(
        "current_base_out_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context",
        "batter_primary_type",
        "pitcher_primary_type"
      ),
      minimum_rows = 5
    ),
    list(
      level = "baseout_phase_score_home_batter",
      columns = c(
        "current_base_out_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context",
        "batter_name"
      ),
      minimum_rows = 5
    ),
    list(
      level = "baseout_phase_score_home_pitcher",
      columns = c(
        "current_base_out_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context",
        "pitcher_name"
      ),
      minimum_rows = 5
    ),
    list(
      level = "baseout_phase_score_home",
      columns = c(
        "current_base_out_state",
        "stage2_inning_phase",
        "score_diff_bucket",
        "home_away_context"
      ),
      minimum_rows = 20
    ),
    list(
      level = "baseout_score",
      columns = c("current_base_out_state", "score_diff_bucket"),
      minimum_rows = 20
    ),
    list(
      level = "baseout",
      columns = c("current_base_out_state"),
      minimum_rows = 1
    )
  )

  lookup <- lookup_matching_rows(input_row, specs)
  probabilities <- vapply(
    result_probability_columns,
    function(column_name) safe_mean(lookup$data[[column_name]]),
    numeric(1)
  )
  probabilities <- probabilities / sum(probabilities)
  names(probabilities) <- result_states

  list(
    probabilities = probabilities,
    lookup_level = lookup$lookup_level,
    lookup_rows = lookup$lookup_rows,
    top_state = names(probabilities)[which.max(probabilities)]
  )
}

constrain_result_distribution_by_runs <- function(stage1, runs_scored) {
  probabilities <- stage1$probabilities
  runs_scored <- input_number(runs_scored)

  if (runs_scored >= 3) {
    probabilities[] <- 0
    probabilities["big_inning"] <- 1
  } else if (runs_scored >= 2) {
    probabilities[c("no_score_stable", "wasted_chance", "score_once")] <- 0
    probabilities <- probabilities / sum(probabilities)
  } else if (runs_scored >= 1) {
    probabilities[c("no_score_stable", "wasted_chance")] <- 0
    probabilities <- probabilities / sum(probabilities)
  }

  probabilities[is.na(probabilities)] <- 0
  if (sum(probabilities) <= 0) {
    probabilities[] <- 0
    probabilities["big_inning"] <- 1
  }

  stage1$probabilities <- probabilities
  stage1$top_state <- names(probabilities)[which.max(probabilities)]
  stage1
}

lookup_stage2_win_by_result_state <- function(input_row) {
  specs <- list(
    list(
      level = "phase_score_home",
      columns = c("stage2_inning_phase", "score_diff_bucket", "home_away_context"),
      minimum_rows = 20
    ),
    list(
      level = "phase_score",
      columns = c("stage2_inning_phase", "score_diff_bucket"),
      minimum_rows = 20
    ),
    list(
      level = "phase",
      columns = c("stage2_inning_phase"),
      minimum_rows = 1
    )
  )

  lookup <- lookup_matching_rows(input_row, specs)
  win_probabilities <- vapply(
    result_win_columns,
    function(column_name) safe_mean(lookup$data[[column_name]]),
    numeric(1)
  )
  names(win_probabilities) <- result_states

  list(
    win_probabilities = win_probabilities,
    lookup_level = lookup$lookup_level,
    lookup_rows = lookup$lookup_rows
  )
}

base_out_choices <- make_named_choices(bridge_data$current_base_out_state, label_base_out_zh)
batter_choices <- stats::setNames(sort(unique(batter_profile$batter_name)), sort(unique(batter_profile$batter_name)))
pitcher_choices <- stats::setNames(sort(unique(pitcher_profile$pitcher_name)), sort(unique(pitcher_profile$pitcher_name)))
team_choices <- stats::setNames(
  sort(unique(c(bridge_data$batting_team, bridge_data$fielding_team))),
  sort(unique(c(bridge_data$batting_team, bridge_data$fielding_team)))
)

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      html, body { overflow-x: hidden; }
      body { background: #f6f7f9; color: #1f2933; }
      .app-shell { max-width: 1180px; margin: 0 auto; padding: 18px 12px 32px; box-sizing: border-box; }
      .topbar { display: flex; justify-content: space-between; align-items: end; gap: 16px; margin-bottom: 14px; }
      .title-block h1 { font-size: 28px; margin: 0 0 4px; font-weight: 700; }
      .title-block p { margin: 0; color: #52616b; }
      .panel { min-width: 0; max-width: 100%; overflow-x: auto; background: #ffffff; border: 1px solid #dde3ea; border-radius: 8px; padding: 16px; box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04); }
      .setup-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
      .game-grid { display: grid; grid-template-columns: minmax(0, 1.2fr) minmax(360px, 1.8fr); gap: 12px; margin-top: 12px; }
      .matchup-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
      .inning-score-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-bottom: 12px; }
      .player-select-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-bottom: 12px; }
      .base-out-grid { display: grid; grid-template-columns: minmax(0, 1fr) 170px; gap: 14px; align-items: center; margin-bottom: 12px; }
      .outs-control .radio-inline { margin-right: 12px; font-weight: 700; }
      .base-diamond { position: relative; width: 150px; height: 128px; margin: 0 auto; }
      .base-node { position: absolute; width: 58px; height: 42px; }
      .base-node .checkbox { margin: 0; }
      .base-node label { width: 42px; height: 42px; border: 1px solid #cbd8e5; background: #f7fafc; transform: rotate(45deg); display: flex; align-items: center; justify-content: center; cursor: pointer; margin: 0 auto; border-radius: 6px; }
      .base-node span { transform: rotate(-45deg); font-size: 12px; font-weight: 800; color: #334e68; }
      .base-node input { position: absolute; opacity: 0; }
      .base-node:has(input:checked) label { background: #d9ebf7; border-color: #2f80b7; box-shadow: 0 0 0 2px rgba(47, 128, 183, 0.16); }
      .base-node.second { left: 46px; top: 4px; }
      .base-node.third { left: 0; top: 54px; }
      .base-node.first { right: 0; top: 54px; }
      .projection-grid { display: grid; grid-template-columns: minmax(0, 1.15fr) minmax(300px, 0.85fr); gap: 12px; margin-top: 12px; }
      .metric { min-width: 0; background: #ffffff; border: 1px solid #dde3ea; border-radius: 8px; padding: 14px; }
      .metric-label { font-size: 13px; color: #52616b; margin-bottom: 6px; }
      .metric-value { font-size: 30px; line-height: 1.1; font-weight: 700; color: #102a43; }
      .metric-sub { font-size: 13px; color: #627d98; margin-top: 6px; }
      .metric-note { font-size: 12px; line-height: 1.45; color: #52616b; margin-top: 8px; }
      .formula { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; color: #334e68; }
      .state-pill { display: inline-block; border-radius: 999px; padding: 5px 10px; font-weight: 700; font-size: 13px; background: #e6f4ea; color: #1e6b3a; }
      .lookup { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; color: #52616b; }
      .section-title { font-weight: 700; font-size: 16px; margin: 0 0 12px; }
      .section-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; }
      .section-header .section-title { margin: 0; }
      .reset-link { border: 1px solid #cbd8e5; background: #f7fafc; color: #334e68; border-radius: 999px; padding: 5px 12px; font-size: 12px; font-weight: 700; line-height: 1.2; }
      .reset-link:hover, .reset-link:focus { background: #e5edf5; color: #102a43; border-color: #9fb3c8; }
      .section-subtitle { color: #627d98; font-size: 13px; margin: -6px 0 12px; }
      .context-summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-top: 4px; }
      .context-item { background: #f7fafc; border: 1px solid #dde8f2; border-radius: 8px; padding: 10px 12px; min-width: 0; }
      .context-label { color: #627d98; font-size: 12px; margin-bottom: 4px; }
      .context-value { color: #102a43; font-size: 15px; font-weight: 700; overflow-wrap: anywhere; }
      .profile-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .profile-card { background: #f7fafc; border: 1px solid #dde8f2; border-radius: 8px; padding: 14px; }
      .profile-card-title { font-weight: 800; color: #102a43; margin-bottom: 10px; }
      .profile-stat-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
      .profile-stat { background: #ffffff; border: 1px solid #e5edf5; border-radius: 8px; padding: 9px 10px; }
      .profile-stat-label { color: #627d98; font-size: 12px; margin-bottom: 2px; }
      .profile-stat-value { color: #102a43; font-size: 16px; font-weight: 800; overflow-wrap: anywhere; }
      .scoreboard { overflow-x: auto; }
      .score-row { display: grid; grid-template-columns: minmax(120px, 1.4fr) repeat(9, 58px) 58px; gap: 6px; align-items: end; min-width: 720px; margin-bottom: 6px; }
      .score-header { align-items: center; color: #627d98; font-size: 12px; font-weight: 700; }
      .score-row .form-group { margin-bottom: 0; }
      .score-row input { text-align: center; padding-left: 6px; padding-right: 6px; width: 58px; }
      .score-row input:disabled { background: #eef2f7; color: #7b8794; cursor: not-allowed; }
      .team-cell { align-self: center; font-weight: 700; color: #102a43; }
      .inning-label, .run-total { text-align: center; font-weight: 700; }
      .run-total { align-self: center; font-size: 20px; color: #102a43; }
      .win-card { min-height: 250px; position: relative; overflow: hidden; }
      .win-row { display: grid; grid-template-columns: 1fr auto; gap: 16px; align-items: baseline; margin: 10px 0; }
      .team-name { font-size: 20px; color: #334e68; font-weight: 700; }
      .win-percent { font-size: 52px; line-height: 1; font-weight: 800; color: #1f6fa5; }
      .win-percent.secondary { color: #52616b; }
      .leader-note { margin-top: 10px; color: #52616b; font-size: 13px; }
      .state-bars { display: grid; gap: 10px; }
      .state-bar-row { display: grid; grid-template-columns: 112px minmax(0, 1fr) 52px; gap: 8px; align-items: center; font-size: 13px; }
      .state-label { display: flex; align-items: center; gap: 6px; min-width: 0; }
      .state-arrow { width: 18px; height: 18px; border-radius: 999px; display: inline-flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 900; }
      .arrow-up { background: #e6f4ea; color: #1e6b3a; }
      .arrow-down { background: #fdecea; color: #9f1d1d; }
      .arrow-flat { background: #eef2f7; color: #52616b; }
      .bar-track { height: 10px; background: #e5edf5; border-radius: 999px; overflow: hidden; }
      .bar-fill { height: 100%; background: #2f80b7; border-radius: 999px; }
      .panel table { width: 100%; max-width: 100%; table-layout: auto; }
      .panel th, .panel td { white-space: normal; overflow-wrap: anywhere; }
      @media (max-width: 900px) {
        .setup-grid, .game-grid, .matchup-grid, .inning-score-grid, .player-select-grid, .base-out-grid, .projection-grid, .context-summary, .profile-grid { grid-template-columns: 1fr; }
        .topbar { display: block; }
      }
    "))
  ),
  div(
    class = "app-shell",
    div(
      class = "topbar",
      div(
        class = "title-block",
        h1("CPBL State Prediction"),
        p("用本次進攻狀態推動，投影最終勝負機率")
      )
    ),
    div(
      class = "panel",
      div(
        class = "section-header",
        div(class = "section-title", "比賽設定"),
        actionButton("reset_game", "初始化", class = "reset-link")
      ),
      div(
        class = "setup-grid",
        selectInput("away_team", "客場球隊", choices = team_choices, selected = "富邦悍將"),
        selectInput("home_team", "主場球隊", choices = team_choices, selected = "味全龍"),
        numericInput("inning", "目前局數", value = 1, min = 1, max = 12, step = 1),
        selectInput("half_inning", "目前半局", choices = c("上半局" = "top", "下半局" = "bottom"), selected = "top")
      ),
      div(class = "section-title", "逐局比分"),
      div(class = "section-subtitle", "目前局與未來局會鎖定；本局分數請在目前對戰情境輸入，會同步回這張 scoreboard。"),
      div(class = "scoreboard", uiOutput("scoreboard_inputs"))
    ),
    div(
      class = "game-grid",
      div(
        class = "panel",
      div(class = "section-title", "目前對戰情境"),
        uiOutput("current_inning_score_inputs"),
        uiOutput("base_out_control"),
        uiOutput("context_summary")
      ),
      div(
        class = "panel",
        div(class = "section-title", "球員 Profile"),
        div(
          class = "player-select-grid",
          uiOutput("batter_selector"),
          uiOutput("pitcher_selector")
        ),
        uiOutput("player_profile_cards")
      )
    ),
    div(
      class = "projection-grid",
      div(
        class = "panel win-card",
        div(class = "section-title", "最終勝負預測"),
        div(class = "win-row", div(class = "team-name", textOutput("away_win_team", inline = TRUE)), div(class = "win-percent secondary", textOutput("away_win_probability", inline = TRUE))),
        div(class = "win-row", div(class = "team-name", textOutput("home_win_team", inline = TRUE)), div(class = "win-percent", textOutput("home_win_probability", inline = TRUE))),
        div(class = "leader-note", textOutput("win_projection_note", inline = TRUE))
      ),
      div(
        class = "panel",
        div(class = "section-title", "本次進攻狀態預測"),
        uiOutput("top_result_state"),
        div(class = "metric-note", textOutput("stage1_note", inline = TRUE)),
        br(),
        uiOutput("state_probability_bars")
      )
    ),
    div(
      class = "panel",
      div(class = "section-title", "比賽情勢推動"),
      plotOutput("win_probability_plot", height = "260px")
    )
  )
)

server <- function(input, output, session) {
  score_state <- reactiveVal(data.frame(
    inning = 1:9,
    away = rep(0, 9),
    home = rep(0, 9),
    stringsAsFactors = FALSE
  ))

  observeEvent(input$reset_game, {
    score_state(data.frame(
      inning = 1:9,
      away = rep(0, 9),
      home = rep(0, 9),
      stringsAsFactors = FALSE
    ))
    updateSelectInput(session, "away_team", selected = "富邦悍將")
    updateSelectInput(session, "home_team", selected = "味全龍")
    updateNumericInput(session, "inning", value = 1)
    updateSelectInput(session, "half_inning", selected = "top")
    updateNumericInput(session, "current_away_score", value = 0)
    updateNumericInput(session, "current_home_score", value = 0)
    updateRadioButtons(session, "outs_count", selected = "0")
    updateCheckboxInput(session, "base_1b", value = FALSE)
    updateCheckboxInput(session, "base_2b", value = FALSE)
    updateCheckboxInput(session, "base_3b", value = FALSE)
    for (inning in 1:9) {
      updateNumericInput(session, paste0("away_score_", inning), value = 0)
      updateNumericInput(session, paste0("home_score_", inning), value = 0)
    }
  })

  output$batter_selector <- renderUI({
    batting_team <- if (identical(input$half_inning, "top")) input$away_team else input$home_team
    choices <- sort(unique(bridge_data$batter_name[bridge_data$batting_team == batting_team]))
    if (length(choices) == 0) {
      choices <- sort(unique(batter_profile$batter_name))
    }
    selectInput("batter_name", "球隊打者", choices = stats::setNames(choices, choices), selected = choices[1])
  })

  output$pitcher_selector <- renderUI({
    fielding_team <- if (identical(input$half_inning, "top")) input$home_team else input$away_team
    choices <- sort(unique(bridge_data$pitcher_name[bridge_data$fielding_team == fielding_team]))
    if (length(choices) == 0) {
      choices <- sort(unique(pitcher_profile$pitcher_name))
    }
    selectInput("pitcher_name", "球隊投手", choices = stats::setNames(choices, choices), selected = choices[1])
  })

  output$base_out_control <- renderUI({
    div(
      class = "base-out-grid",
      div(
        class = "outs-control",
        div(class = "metric-label", "出局數"),
        radioButtons(
          "outs_count",
          label = NULL,
          choices = c("0 出局" = "0", "1 出局" = "1", "2 出局" = "2"),
          selected = "0",
          inline = TRUE
        )
      ),
      div(
        div(class = "metric-label", "壘包狀態"),
        div(
          class = "base-diamond",
          div(class = "base-node second", checkboxInput("base_2b", label = span("二壘"), value = FALSE)),
          div(class = "base-node third", checkboxInput("base_3b", label = span("三壘"), value = FALSE)),
          div(class = "base-node first", checkboxInput("base_1b", label = span("一壘"), value = FALSE))
        )
      )
    )
  })

  selected_base_out_state <- reactive({
    outs <- if (is.null(input$outs_count)) "0" else input$outs_count
    bases <- c()
    if (isTRUE(input$base_1b)) bases <- c(bases, "1b")
    if (isTRUE(input$base_2b)) bases <- c(bases, "2b")
    if (isTRUE(input$base_3b)) bases <- c(bases, "3b")
    base_part <- if (length(bases) == 0) "empty" else paste(bases, collapse = "_")
    paste0(outs, "_outs_", base_part)
  })

  output$current_inning_score_inputs <- renderUI({
    scores <- score_state()
    current_inning <- max(1, min(9, input_number(input$inning)))
    if (identical(input$half_inning, "top")) {
      div(
        class = "inning-score-grid",
        numericInput("current_away_score", "本局客隊得分", value = scores$away[current_inning], min = 0, max = 30, step = 1),
        div(
          class = "context-item",
          div(class = "context-label", "本局主隊得分"),
          div(class = "context-value", "尚未進攻")
        )
      )
    } else {
      div(
        class = "inning-score-grid",
        div(
          class = "context-item",
          div(class = "context-label", "本局客隊得分"),
          div(class = "context-value", scores$away[current_inning])
        ),
        numericInput("current_home_score", "本局主隊得分", value = scores$home[current_inning], min = 0, max = 30, step = 1)
      )
    }
  })

  observe({
    current_inning <- max(1, min(12, input_number(input$inning)))
    scores <- isolate(score_state())

    for (inning in 1:9) {
      if (inning < current_inning || (inning == current_inning && identical(input$half_inning, "bottom"))) {
        away_input <- input[[paste0("away_score_", inning)]]
        if (!is.null(away_input)) {
          scores$away[inning] <- input_number(away_input)
        }
      }

      if (inning < current_inning) {
        home_input <- input[[paste0("home_score_", inning)]]
        if (!is.null(home_input)) {
          scores$home[inning] <- input_number(home_input)
        }
      }

      if (inning == current_inning) {
        if (identical(input$half_inning, "top")) {
          scores$away[inning] <- input_number(input$current_away_score)
          scores$home[inning] <- 0
        } else {
          scores$home[inning] <- input_number(input$current_home_score)
        }
      } else if (inning > current_inning) {
        scores$away[inning] <- 0
        scores$home[inning] <- 0
      }
    }

    old_scores <- isolate(score_state())
    if (!identical(scores, old_scores)) {
      score_state(scores)
    }
  })

  output$scoreboard_inputs <- renderUI({
    make_scoreboard_inputs(
      current_inning = input_number(input$inning),
      half_inning = input$half_inning,
      scores = score_state()
    )
  })

  score_by_inning <- reactive({
    score_state()
  })

  current_score <- reactive({
    scores <- score_by_inning()
    list(
      away = sum(scores$away, na.rm = TRUE),
      home = sum(scores$home, na.rm = TRUE)
    )
  })

  current_offense_inning_runs <- reactive({
    scores <- score_by_inning()
    current_inning <- max(1, min(9, input_number(input$inning)))
    if (identical(input$half_inning, "bottom")) {
      scores$home[current_inning]
    } else {
      scores$away[current_inning]
    }
  })

  offense_context <- reactive({
    is_home_batting <- identical(input$half_inning, "bottom")
    scores <- current_score()
    offense_score <- if (is_home_batting) scores$home else scores$away
    defense_score <- if (is_home_batting) scores$away else scores$home

    list(
      home_away_context = if (is_home_batting) "home_batting" else "away_batting",
      offense_team = if (is_home_batting) input$home_team else input$away_team,
      defense_team = if (is_home_batting) input$away_team else input$home_team,
      score_diff_before = offense_score - defense_score
    )
  })

  selected_batter_profile <- reactive({
    req(input$batter_name)
    get_batter_profile(input$batter_name)
  })

  selected_pitcher_profile <- reactive({
    req(input$pitcher_name)
    get_pitcher_profile(input$pitcher_name)
  })

  build_context_row <- function(inning, home_away_context, score_diff, base_out_state, batter_row, pitcher_row) {
    data.frame(
      inning = inning,
      stage2_inning_phase = derive_inning_phase(inning),
      score_diff_before = score_diff,
      score_diff_bucket = bucket_score_diff(score_diff),
      home_away_context = home_away_context,
      current_base_out_state = base_out_state,
      batter_name = batter_row$batter_name,
      pitcher_name = pitcher_row$pitcher_name,
      batter_primary_type = batter_row$batter_primary_type,
      pitcher_primary_type = pitcher_row$pitcher_primary_type,
      stringsAsFactors = FALSE
    )
  }

  current_context <- reactive({
    req(input$batter_name, input$pitcher_name)
    batter_row <- selected_batter_profile()
    pitcher_row <- selected_pitcher_profile()
    offense <- offense_context()

    build_context_row(
      inning = input$inning,
      home_away_context = offense$home_away_context,
      score_diff = offense$score_diff_before,
      base_out_state = selected_base_out_state(),
      batter_row = batter_row,
      pitcher_row = pitcher_row
    )
  })

  stage1_result <- reactive({
    lookup_stage1_result_distribution(current_context())
  })

  adjusted_stage1_result <- reactive({
    constrain_result_distribution_by_runs(stage1_result(), current_offense_inning_runs())
  })

  stage2_result <- reactive({
    lookup_stage2_win_by_result_state(current_context())
  })

  weighted_win_probability <- reactive({
    sum(adjusted_stage1_result()$probabilities * stage2_result()$win_probabilities)
  })

  team_win_probability <- reactive({
    offense_win_probability <- weighted_win_probability()
    home_probability <- if (identical(offense_context()$home_away_context, "home_batting")) {
      offense_win_probability
    } else {
      1 - offense_win_probability
    }
    list(
      home = home_probability,
      away = 1 - home_probability
    )
  })

  output$away_scoreboard_team <- renderText(input$away_team)
  output$home_scoreboard_team <- renderText(input$home_team)
  output$away_total <- renderText(current_score()$away)
  output$home_total <- renderText(current_score()$home)

  output$away_win_team <- renderText(input$away_team)
  output$home_win_team <- renderText(input$home_team)

  output$away_win_probability <- renderText({
    format_percent(team_win_probability()$away)
  })

  output$home_win_probability <- renderText({
    format_percent(team_win_probability()$home)
  })

  output$win_projection_note <- renderText({
    probabilities <- team_win_probability()
    leader <- if (probabilities$home >= probabilities$away) input$home_team else input$away_team
    paste0(
      leader,
      " 目前較有優勢。此預測會把本次進攻可能形成的狀態分布納入最終勝負投影。"
    )
  })

  output$top_result_state <- renderUI({
    top_state <- adjusted_stage1_result()$top_state
    delta <- stage2_result()$win_probabilities[[top_state]] - weighted_win_probability()
    arrow <- if (delta >= 0.01) "↑" else if (delta <= -0.01) "↓" else "→"
    span(class = "state-pill", paste(label_result_state_zh(top_state), arrow))
  })

  output$stage1_note <- renderText({
    paste0(
      "目前進攻方：", offense_context()$offense_team,
      "；已依本局得分校正不可能的收尾狀態。"
    )
  })

  output$state_probability_bars <- renderUI({
    probabilities <- adjusted_stage1_result()$probabilities
    win_probabilities <- stage2_result()$win_probabilities
    weighted_probability <- weighted_win_probability()
    ordered_states <- names(sort(probabilities, decreasing = TRUE))
    div(
      class = "state-bars",
      lapply(ordered_states, function(state) {
        probability <- probabilities[[state]]
        delta <- win_probabilities[[state]] - weighted_probability
        arrow <- if (delta >= 0.01) "↑" else if (delta <= -0.01) "↓" else "→"
        arrow_class <- if (delta >= 0.01) {
          "state-arrow arrow-up"
        } else if (delta <= -0.01) {
          "state-arrow arrow-down"
        } else {
          "state-arrow arrow-flat"
        }
        div(
          class = "state-bar-row",
          div(class = "state-label", span(class = arrow_class, arrow), span(label_result_state_zh(state))),
          div(class = "bar-track", div(class = "bar-fill", style = paste0("width:", round(probability * 100, 1), "%;"))),
          div(format_percent(probability))
        )
      })
    )
  })

  output$player_profile_cards <- renderUI({
    batter_row <- selected_batter_profile()
    pitcher_row <- selected_pitcher_profile()

    stat_item <- function(label, value) {
      div(
        class = "profile-stat",
        div(class = "profile-stat-label", label),
        div(class = "profile-stat-value", value)
      )
    }

    div(
      class = "profile-grid",
      div(
        class = "profile-card",
        div(class = "profile-card-title", batter_row$batter_name),
        div(
          class = "profile-stat-grid",
          stat_item("打席數", batter_row$pa),
          stat_item("安打率", format_percent(batter_row$hit_rate)),
          stat_item("長打率", format_percent(batter_row$extra_base_hit_rate)),
          stat_item("選球分數", format_number(batter_row$discipline_score)),
          stat_item("得分打席率", format_percent(batter_row$scoring_pa_rate)),
          stat_item("攻擊價值", format_number(batter_row$run_value_score))
        )
      ),
      div(
        class = "profile-card",
        div(class = "profile-card-title", pitcher_row$pitcher_name),
        div(
          class = "profile-stat-grid",
          stat_item("面對打者", pitcher_row$batters_faced),
          stat_item("被安打率", format_percent(pitcher_row$hit_allowed_rate)),
          stat_item("三振率", format_percent(pitcher_row$strikeout_rate)),
          stat_item("保送率", format_percent(pitcher_row$walk_allowed_rate)),
          stat_item("失分抑制", format_number(pitcher_row$run_prevention_score))
        )
      )
    )
  })

  output$result_state_probability_table <- renderTable({
    probabilities <- adjusted_stage1_result()$probabilities
    table_data <- data.frame(
      result_state = label_result_state_zh(names(probabilities)),
      probability = format_percent(as.numeric(probabilities)),
      stringsAsFactors = FALSE
    )
    names(table_data) <- c("結果", "機率")
    table_data
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$result_state_win_table <- renderTable({
    win_probabilities <- stage2_result()$win_probabilities
    probabilities <- adjusted_stage1_result()$probabilities
    table_data <- data.frame(
      result_state = label_result_state_zh(names(win_probabilities)),
      stage1_probability = format_percent(as.numeric(probabilities[names(win_probabilities)])),
      win_probability_if_state = format_percent(as.numeric(win_probabilities)),
      weighted_contribution = format_percent(
        as.numeric(probabilities[names(win_probabilities)]) * as.numeric(win_probabilities)
      ),
      stringsAsFactors = FALSE
    )
    names(table_data) <- c("結果", "Stage 1 機率", "該結果勝率", "加權貢獻")
    table_data
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$context_summary <- renderUI({
    context <- current_context()
    summary_item <- function(label, value) {
      div(
        class = "context-item",
        div(class = "context-label", label),
        div(class = "context-value", value)
      )
    }

    div(
      class = "context-summary",
      summary_item("比分", paste0(input$away_team, " ", current_score()$away, " - ", current_score()$home, " ", input$home_team)),
      summary_item("局段", paste(label_inning_phase_zh(context$stage2_inning_phase), ifelse(identical(input$half_inning, "top"), "上半局", "下半局"))),
      summary_item("進攻方", offense_context()$offense_team),
      summary_item("進攻方分差", context$score_diff_before),
      summary_item("比分狀態", label_score_diff_bucket_zh(context$score_diff_bucket)),
      summary_item("壘包與出局", label_base_out_zh(context$current_base_out_state))
    )
  })

  output$win_probability_plot <- renderPlot({
    req(input$batter_name, input$pitcher_name)
    scores <- score_by_inning()
    batter_row <- selected_batter_profile()
    pitcher_row <- selected_pitcher_profile()

    points <- data.frame(x = numeric(0), label = character(0), home_probability = numeric(0), stringsAsFactors = FALSE)
    away_total <- 0
    home_total <- 0
    current_inning <- max(1, min(9, input_number(input$inning)))

    for (inning in 1:current_inning) {
      away_total <- away_total + scores$away[inning]
      if (inning < current_inning || identical(input$half_inning, "bottom")) {
        top_context <- build_context_row(
          inning = inning,
          home_away_context = "away_batting",
          score_diff = away_total - home_total,
          base_out_state = "0_outs_empty",
          batter_row = batter_row,
          pitcher_row = pitcher_row
        )
        top_stage1 <- lookup_stage1_result_distribution(top_context)
        top_stage2 <- lookup_stage2_win_by_result_state(top_context)
        away_probability <- sum(top_stage1$probabilities * top_stage2$win_probabilities)
        points <- rbind(points, data.frame(x = inning - 0.25, label = paste0(inning, "上"), home_probability = 1 - away_probability))
      }

      home_total <- home_total + scores$home[inning]
      if (inning < current_inning) {
        bottom_context <- build_context_row(
          inning = inning,
          home_away_context = "home_batting",
          score_diff = home_total - away_total,
          base_out_state = "0_outs_empty",
          batter_row = batter_row,
          pitcher_row = pitcher_row
        )
        bottom_stage1 <- lookup_stage1_result_distribution(bottom_context)
        bottom_stage2 <- lookup_stage2_win_by_result_state(bottom_context)
        home_probability <- sum(bottom_stage1$probabilities * bottom_stage2$win_probabilities)
        points <- rbind(points, data.frame(x = inning + 0.25, label = paste0(inning, "下"), home_probability = home_probability))
      }
    }

    current_x <- if (identical(input$half_inning, "top")) current_inning - 0.25 else current_inning + 0.25
    points <- rbind(
      points,
      data.frame(x = current_x, label = "目前", home_probability = team_win_probability()$home)
    )

    top_state <- adjusted_stage1_result()$top_state
    predicted_offense_probability <- stage2_result()$win_probabilities[[top_state]]
    predicted_home_probability <- if (identical(offense_context()$home_away_context, "home_batting")) {
      predicted_offense_probability
    } else {
      1 - predicted_offense_probability
    }

    old_par <- par(no.readonly = TRUE)
    on.exit(par(old_par))
    par(mar = c(4, 4, 2, 2), bg = "#ffffff")
    x <- points$x
    y <- points$home_probability * 100
    predict_x <- min(9.35, current_x + 0.5)
    predict_y <- predicted_home_probability * 100
    plot(
      NA,
      NA,
      ylim = c(0, 100),
      xlim = c(0.65, 9.35),
      xaxt = "n",
      xlab = "",
      ylab = "主場勝率 (%)",
      main = "",
      bty = "n"
    )
    grid(nx = NA, ny = NULL, col = "#dde3ea", lty = 1)
    if (length(x) >= 2) {
      lines(x, y, lwd = 3, col = "#2f80b7")
    }
    points(x, y, pch = 19, col = "#1f6fa5")
    lines(c(x[length(x)], predict_x), c(y[length(y)], predict_y), lwd = 3, col = "#7b8794", lty = 2)
    points(predict_x, predict_y, pch = 1, col = "#52616b")
    axis(1, at = 1:9, labels = paste0(1:9, "局"), cex.axis = 0.8)
    abline(h = 50, col = "#9fb3c8", lty = 2)
    text(x[length(x)], y[length(y)], labels = paste0("  ", format_percent(team_win_probability()$home)), pos = 4, col = "#102a43")
    text(
      predict_x,
      predict_y,
      labels = paste0("  ", label_result_state_zh(top_state)),
      pos = 4,
      col = "#52616b"
    )
  })
}

shinyApp(ui, server)
