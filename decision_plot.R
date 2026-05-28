library(randomForest)
library(ggplot2)
library(dplyr)

# ── 啟動時一次性載入資料、訓練 RF、預建 grid ──────────────────
BASE <- Sys.getenv("BASEBALL_DATA_DIR", unset = ".")

pca  <- read.csv(file.path(BASE, "pca_scores.csv"),         stringsAsFactors = FALSE)
orig <- read.csv(file.path(BASE, "team_game_features.csv"), stringsAsFactors = FALSE)

OFFENSE_COLS <- c("AB","H","BB","SO","double","triple","HR",
                  "extra_base_hits","power_score","run_per_hit",
                  "offense_pressure_score")
DEFENSE_COLS <- c("outs_pitched","innings_pitched","hits_allowed",
                  "bb_allowed","hr_allowed","so_pitched","whip_like",
                  "strikeout_walk_ratio","run_prevention_score")

orig_clean <- orig %>%
  filter(if_all(all_of(c(OFFENSE_COLS, DEFENSE_COLS)),
                ~ !is.na(.) & is.finite(.))) %>%
  mutate(
    led_after_3 = as.integer(led_after_3 %in% c("TRUE", TRUE, 1)),
    led_after_6 = as.integer(led_after_6 %in% c("TRUE", TRUE, 1))
  )

pca_clean <- pca %>%
  mutate(
    win     = as.integer(win     %in% c("TRUE", TRUE, 1)),
    is_home = as.integer(is_home %in% c("TRUE", TRUE, 1))
  )

if (nrow(pca_clean) != nrow(orig_clean))
  stop(sprintf("行數不符：pca=%d, orig=%d", nrow(pca_clean), nrow(orig_clean)))

df_model <- bind_cols(
  pca_clean[, c("win","is_home","Off_PC1","Off_PC2","Off_PC3",
                "Def_PC1","Def_PC2","Def_PC3")],
  orig_clean[, c("led_after_3","led_after_6","team","opponent")]
) %>%
  mutate(win_factor = factor(win, levels = c(0,1), labels = c("敗","勝")))

set.seed(42)
rf <- randomForest(
  win_factor ~ Off_PC1 + Off_PC2 + Off_PC3 +
               Def_PC1 + Def_PC2 + Def_PC3 +
               is_home + led_after_3 + led_after_6,
  data     = df_model,
  ntree    = 300,
  maxnodes = 64,
  nodesize = 10
)
cat(sprintf("[plumber] RF 訓練完成，OOB Error: %.1f%%\n",
            rf$err.rate[300, "OOB"] * 100))

# 預先建立背景 grid（固定特徵 = 全資料均值）
fix    <- df_model %>%
  summarise(across(c(Off_PC2, Off_PC3, Def_PC2, Def_PC3,
                     is_home, led_after_3, led_after_6), mean))

x_rng  <- range(df_model$Def_PC1);  pad_x <- diff(x_rng) * 0.05
y_rng  <- range(df_model$Off_PC1);  pad_y <- diff(y_rng) * 0.05

grid <- expand.grid(
  Def_PC1 = seq(x_rng[1] - pad_x, x_rng[2] + pad_x, length.out = 200),
  Off_PC1 = seq(y_rng[1] - pad_y, y_rng[2] + pad_y, length.out = 200)
) %>% mutate(
  Off_PC2 = fix$Off_PC2, Off_PC3 = fix$Off_PC3,
  Def_PC2 = fix$Def_PC2, Def_PC3 = fix$Def_PC3,
  is_home = fix$is_home,
  led_after_3 = fix$led_after_3,
  led_after_6 = fix$led_after_6
)
grid$prob_win <- predict(rf, newdata = grid, type = "prob")[, "勝"]
cat("[plumber] Grid 預測完成，API 就緒\n")

# ── CORS（允許前端跨埠存取）──────────────────────────────────

#* @filter cors
function(res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  plumber::forward()
}

# ── Decision Plot endpoint ────────────────────────────────────

#* @get /decision_plot
#* @param home 主場球隊
#* @param away 客場球隊
#* @serializer png list(width=900, height=600, res=150)
function(home, away) {
  pts <- df_model %>%
    mutate(matchup = ifelse(
      (team == home & is_home == 1 & opponent == away) |
      (team == away & is_home == 0 & opponent == home),
      "本對戰", "其他"
    ))

  p <- ggplot() +
    geom_raster(data = grid,
                aes(x = Def_PC1, y = Off_PC1, fill = prob_win),
                interpolate = TRUE) +
    scale_fill_gradient2(
      low = "#c62828", mid = "#fafafa", high = "#2e7d32",
      midpoint = 0.5, limits = c(0, 1), name = "預測勝率"
    ) +
    geom_contour(data = grid,
                 aes(x = Def_PC1, y = Off_PC1, z = prob_win),
                 breaks = 0.5, colour = "black",
                 linewidth = 0.9, linetype = "dashed") +
    # 其他場次：勝（圓點）/ 敗（X，加粗）分開控制 stroke
    geom_point(data = filter(pts, matchup == "其他", win_factor == "勝"),
               aes(x = Def_PC1, y = Off_PC1),
               shape = 16, colour = "#1b5e20", size = 1.0, alpha = 0.2) +
    geom_point(data = filter(pts, matchup == "其他", win_factor == "敗"),
               aes(x = Def_PC1, y = Off_PC1),
               shape = 4, colour = "#b71c1c", size = 1.0, stroke = 1.3, alpha = 0.25) +
    # 本對戰場次：強調顯示（加深顏色）
    geom_point(data = filter(pts, matchup == "本對戰", win_factor == "勝"),
               aes(x = Def_PC1, y = Off_PC1),
               shape = 16, colour = "#003300", size = 2.8, alpha = 1.0) +
    geom_point(data = filter(pts, matchup == "本對戰", win_factor == "敗"),
               aes(x = Def_PC1, y = Off_PC1),
               shape = 4, colour = "#7f0000", size = 2.8, stroke = 2.2, alpha = 1.0) +
    # 手動圖例
    scale_colour_manual(values = c("勝" = "#1b5e20", "敗" = "#b71c1c")) +
    scale_shape_manual(values  = c("勝" = 16, "敗" = 4)) +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0)) +
    labs(x = "PC1_Defence", y = "PC1_Offence") +
    theme_minimal(base_size = 9) +
    theme(
      plot.title       = element_blank(),
      plot.subtitle    = element_blank(),
      legend.position  = "right",
      legend.title     = element_blank(),
      legend.text      = element_text(size = 8),
      axis.title       = element_text(size = 8),
      axis.text        = element_text(size = 7),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey85", linewidth = 0.4)
    )

  print(p)
}
