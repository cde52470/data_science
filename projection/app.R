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

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background: #f6f7f9; color: #1f2933; }
      .app-shell { max-width: 1180px; margin: 0 auto; padding: 18px 12px 32px; }
      .topbar { display: flex; justify-content: space-between; align-items: end; gap: 16px; margin-bottom: 16px; }
      .title-block h1 { font-size: 28px; margin: 0 0 4px; font-weight: 700; }
      .title-block p { margin: 0; color: #52616b; }
      .panel { background: #ffffff; border: 1px solid #dde3ea; border-radius: 8px; padding: 16px; box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04); }
      .metric-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
      .metric { background: #ffffff; border: 1px solid #dde3ea; border-radius: 8px; padding: 14px; }
      .metric-label { font-size: 13px; color: #52616b; margin-bottom: 6px; }
      .metric-value { font-size: 30px; line-height: 1.1; font-weight: 700; color: #102a43; }
      .metric-sub { font-size: 13px; color: #627d98; margin-top: 6px; }
      .state-pill { display: inline-block; border-radius: 999px; padding: 5px 10px; font-weight: 700; font-size: 13px; background: #e6f4ea; color: #1e6b3a; }
      .lookup { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; color: #52616b; }
      .section-title { font-weight: 700; font-size: 16px; margin: 0 0 12px; }
      .two-column { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
      @media (max-width: 900px) {
        .metric-grid, .two-column { grid-template-columns: 1fr; }
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
        p("Stage 1 result-state distribution + Stage 2 weighted win probability")
      )
    ),
    fluidRow(
      column(
        width = 4,
        div(
          class = "panel",
          div(class = "section-title", "目前局勢"),
          numericInput("inning", "局數", value = 5, min = 1, max = 12, step = 1),
          selectInput(
            "home_away_context",
            "進攻方",
            choices = c("主場進攻" = "home_batting", "客場進攻" = "away_batting"),
            selected = "home_batting"
          ),
          numericInput("score_diff_before", "進攻方分差", value = 0, min = -15, max = 15, step = 1),
          selectInput("current_base_out_state", "壘包與出局狀態", choices = base_out_choices, selected = "0_outs_empty"),
          selectInput("batter_name", "打者", choices = batter_choices, selected = unname(batter_choices[1])),
          selectInput("pitcher_name", "投手", choices = pitcher_choices, selected = unname(pitcher_choices[1])),
          br(),
          div(class = "section-title", "球員 Profile"),
          tableOutput("player_profile_table")
        )
      ),
      column(
        width = 8,
        div(
          class = "metric-grid",
          div(
            class = "metric",
            div(class = "metric-label", "加權後勝率"),
            div(class = "metric-value", textOutput("weighted_win_probability", inline = TRUE)),
            div(class = "metric-sub", textOutput("weighted_detail", inline = TRUE))
          ),
          div(
            class = "metric",
            div(class = "metric-label", "最可能半局結果"),
            uiOutput("top_result_state"),
            div(class = "metric-sub", textOutput("stage1_lookup", inline = TRUE))
          ),
          div(
            class = "metric",
            div(class = "metric-label", "Stage 2 查詢"),
            div(class = "metric-value", textOutput("top_state_win_probability", inline = TRUE)),
            div(class = "metric-sub", textOutput("stage2_lookup", inline = TRUE))
          )
        ),
        br(),
        div(
          class = "two-column",
          div(
            class = "panel",
            div(class = "section-title", "Stage 1：半局結果機率"),
            tableOutput("result_state_probability_table")
          ),
          div(
            class = "panel",
            div(class = "section-title", "Stage 2：各結果對應勝率"),
            tableOutput("result_state_win_table")
          )
        ),
        br(),
        div(
          class = "panel",
          div(class = "section-title", "查詢脈絡"),
          tableOutput("context_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  selected_batter_profile <- reactive({
    get_batter_profile(input$batter_name)
  })

  selected_pitcher_profile <- reactive({
    get_pitcher_profile(input$pitcher_name)
  })

  current_context <- reactive({
    inning_phase <- derive_inning_phase(input$inning)
    score_diff_bucket <- bucket_score_diff(input$score_diff_before)
    batter_row <- selected_batter_profile()
    pitcher_row <- selected_pitcher_profile()

    data.frame(
      inning = input$inning,
      stage2_inning_phase = inning_phase,
      score_diff_before = input$score_diff_before,
      score_diff_bucket = score_diff_bucket,
      home_away_context = input$home_away_context,
      current_base_out_state = input$current_base_out_state,
      batter_name = input$batter_name,
      pitcher_name = input$pitcher_name,
      batter_primary_type = batter_row$batter_primary_type,
      pitcher_primary_type = pitcher_row$pitcher_primary_type,
      stringsAsFactors = FALSE
    )
  })

  stage1_result <- reactive({
    lookup_stage1_result_distribution(current_context())
  })

  stage2_result <- reactive({
    lookup_stage2_win_by_result_state(current_context())
  })

  weighted_win_probability <- reactive({
    sum(stage1_result()$probabilities * stage2_result()$win_probabilities)
  })

  output$weighted_win_probability <- renderText({
    format_percent(weighted_win_probability())
  })

  output$weighted_detail <- renderText({
    "五類 result state 機率加權"
  })

  output$top_result_state <- renderUI({
    span(class = "state-pill", label_result_state_zh(stage1_result()$top_state))
  })

  output$stage1_lookup <- renderText({
    paste0("Stage 1 查詢層級：", stage1_result()$lookup_level, " / 樣本數=", stage1_result()$lookup_rows)
  })

  output$top_state_win_probability <- renderText({
    top_state <- stage1_result()$top_state
    format_percent(stage2_result()$win_probabilities[[top_state]])
  })

  output$stage2_lookup <- renderText({
    paste0("Stage 2 查詢層級：", stage2_result()$lookup_level, " / 樣本數=", stage2_result()$lookup_rows)
  })

  output$player_profile_table <- renderTable({
    batter_row <- selected_batter_profile()
    pitcher_row <- selected_pitcher_profile()

    data.frame(
      item = c(
        "打者類型",
        "打者打席數",
        "打者安打率",
        "打者長打率",
        "打者選球分數",
        "投手類型",
        "投手面對打者數",
        "投手被安打率",
        "投手三振率",
        "投手失分抑制分數"
      ),
      value = c(
        label_batter_type_zh(batter_row$batter_primary_type),
        batter_row$pa,
        format_percent(batter_row$hit_rate),
        format_percent(batter_row$extra_base_hit_rate),
        format_number(batter_row$discipline_score),
        label_pitcher_type_zh(pitcher_row$pitcher_primary_type),
        pitcher_row$batters_faced,
        format_percent(pitcher_row$hit_allowed_rate),
        format_percent(pitcher_row$strikeout_rate),
        format_number(pitcher_row$run_prevention_score)
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$result_state_probability_table <- renderTable({
    probabilities <- stage1_result()$probabilities
    data.frame(
      result_state = label_result_state_zh(names(probabilities)),
      probability = format_percent(as.numeric(probabilities)),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$result_state_win_table <- renderTable({
    win_probabilities <- stage2_result()$win_probabilities
    probabilities <- stage1_result()$probabilities
    data.frame(
      result_state = label_result_state_zh(names(win_probabilities)),
      stage1_probability = format_percent(as.numeric(probabilities[names(win_probabilities)])),
      win_probability_if_state = format_percent(as.numeric(win_probabilities)),
      weighted_contribution = format_percent(
        as.numeric(probabilities[names(win_probabilities)]) * as.numeric(win_probabilities)
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$context_table <- renderTable({
    context <- current_context()
    data.frame(
      item = c(
        "局段",
        "比分狀態",
        "進攻方",
        "壘包與出局",
        "打者",
        "打者類型",
        "投手",
        "投手類型"
      ),
      value = c(
        label_inning_phase_zh(context$stage2_inning_phase),
        label_score_diff_bucket_zh(context$score_diff_bucket),
        label_home_away_zh(context$home_away_context),
        label_base_out_zh(context$current_base_out_state),
        context$batter_name,
        label_batter_type_zh(context$batter_primary_type),
        context$pitcher_name,
        label_pitcher_type_zh(context$pitcher_primary_type)
      ),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, spacing = "s")
}

shinyApp(ui, server)
