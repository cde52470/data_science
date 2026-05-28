library(tidyverse)
library(ggplot2)
library(ggrepel)
library(factoextra)
library(gridExtra)

# ── 讀取資料 ──────────────────────────────────────────────
df <- read.csv("team_game_features.csv",
               stringsAsFactors = FALSE)

# ── 欄位定義（依 baseball4.png / baseball6.png）──────────

# 進攻數據（11 個數值變數，排除 offense_label）
offense_cols <- c(
  "AB",                     # 打數
  "H",                      # 安打
  "BB",                     # 四壞球
  "SO",                     # 被三振
  "double",                 # 二壘安打
  "triple",                 # 三壘安打
  "HR",                     # 全壘打
  "extra_base_hits",        # 長打總數（double + triple + HR）
  "power_score",            # 長打威脅分數（double + 2*triple + 3*HR）
  "run_per_hit",            # 安打得分轉換效率（runs_scored / H）
  "offense_pressure_score"  # 簡化攻勢壓力分數
)

# 防守數據（9 個數值變數，排除 defense_label）
defense_cols <- c(
  "outs_pitched",           # 投球出局數
  "innings_pitched",        # 投球局數
  "hits_allowed",           # 被安打
  "bb_allowed",             # 投手四壞球
  "hr_allowed",             # 被全壘打
  "so_pitched",             # 投手三振
  "whip_like",              # 類 WHIP（(hits_allowed + bb_allowed) / innings_pitched）
  "strikeout_walk_ratio",   # 三振保送比
  "run_prevention_score"    # 簡化失分壓制分數
)

# ── 資料清理 ───────────────────────────────────────────────
df_clean <- df %>%
  select(team, win, is_home, all_of(offense_cols), all_of(defense_cols)) %>%
  filter(if_all(all_of(c(offense_cols, defense_cols)),
                ~ !is.na(.) & is.finite(.))) %>%
  mutate(
    win     = as.logical(win),
    is_home = as.logical(is_home)
  )

cat("分析樣本數：", nrow(df_clean), "\n")

# ══════════════════════════════════════════════════════════
# PCA 1：進攻數據（11 vars → 取前 3 PCs）
# ══════════════════════════════════════════════════════════
X_off  <- df_clean %>% select(all_of(offense_cols)) %>% scale()
pca_off <- prcomp(X_off, center = FALSE, scale. = FALSE)

var_off <- pca_off$sdev^2 / sum(pca_off$sdev^2) * 100
cum_off <- cumsum(var_off)

cat("\n── 進攻 PCA 解釋變異量 ──\n")
cat(sprintf("PC1: %.1f%%  PC2: %.1f%%  PC3: %.1f%%  累積: %.1f%%\n",
            var_off[1], var_off[2], var_off[3], cum_off[3]))

cat("\n進攻 PC 載荷矩陣（前 3）：\n")
print(round(pca_off$rotation[, 1:3], 3))

# ══════════════════════════════════════════════════════════
# PCA 2：防守數據（9 vars → 取前 3 PCs）
# ══════════════════════════════════════════════════════════
X_def  <- df_clean %>% select(all_of(defense_cols)) %>% scale()
pca_def <- prcomp(X_def, center = FALSE, scale. = FALSE)

var_def <- pca_def$sdev^2 / sum(pca_def$sdev^2) * 100
cum_def <- cumsum(var_def)

cat("\n── 防守 PCA 解釋變異量 ──\n")
cat(sprintf("PC1: %.1f%%  PC2: %.1f%%  PC3: %.1f%%  累積: %.1f%%\n",
            var_def[1], var_def[2], var_def[3], cum_def[3]))

cat("\n防守 PC 載荷矩陣（前 3）：\n")
print(round(pca_def$rotation[, 1:3], 3))

# ══════════════════════════════════════════════════════════
# 整合 PC scores + 標籤
# ══════════════════════════════════════════════════════════
scores_off <- as.data.frame(pca_off$x[, 1:3]) %>%
  rename(Off_PC1 = PC1, Off_PC2 = PC2, Off_PC3 = PC3)

scores_def <- as.data.frame(pca_def$x[, 1:3]) %>%
  rename(Def_PC1 = PC1, Def_PC2 = PC2, Def_PC3 = PC3)

pca_result <- bind_cols(
  df_clean %>% select(team, win, is_home),
  scores_off,
  scores_def
)

# ══════════════════════════════════════════════════════════
# 視覺化設定
# ══════════════════════════════════════════════════════════
team_colors <- c(
  "味全龍"          = "#D32F2F",
  "樂天桃猿"        = "#1565C0",
  "中信兄弟"        = "#2E7D32",
  "富邦悍將"        = "#F57F17",
  "統一7-ELEVEn獅"  = "#6A1B9A",
  "台鋼雄鷹"        = "#00695C"
)

# ── 圖1：Scree Plots ──────────────────────────────────────
p_scree_off <- fviz_eig(pca_off, ncp = 11, addlabels = TRUE,
                         barfill = "#1565C0", barcolor = "#1565C0") +
  geom_vline(xintercept = 3.5, linetype = "dashed", color = "red", linewidth = 0.7) +
  annotate("text", x = 3.7, y = max(var_off) * 0.9,
           label = "取前3個PC", color = "red", hjust = 0, size = 3.5) +
  labs(title = "進攻 PCA — Scree Plot",
       subtitle = sprintf("PC1~PC3 累積解釋 %.1f%%", cum_off[3]),
       x = "主成分", y = "解釋變異量 (%)") +
  theme_minimal(base_size = 12)

p_scree_def <- fviz_eig(pca_def, ncp = 9, addlabels = TRUE,
                         barfill = "#2E7D32", barcolor = "#2E7D32") +
  geom_vline(xintercept = 3.5, linetype = "dashed", color = "red", linewidth = 0.7) +
  annotate("text", x = 3.7, y = max(var_def) * 0.9,
           label = "取前3個PC", color = "red", hjust = 0, size = 3.5) +
  labs(title = "防守 PCA — Scree Plot",
       subtitle = sprintf("PC1~PC3 累積解釋 %.1f%%", cum_def[3]),
       x = "主成分", y = "解釋變異量 (%)") +
  theme_minimal(base_size = 12)

# ── 圖2：進攻 Biplot（PC1 vs PC2，依球隊上色）────────────
p_off_biplot <- fviz_pca_biplot(
  pca_off,
  geom.ind    = "point",
  col.ind     = df_clean$team,
  palette     = team_colors,
  addEllipses = TRUE, ellipse.level = 0.68,
  col.var     = "#333333",
  repel       = TRUE,
  label       = "var",
  title       = sprintf("進攻 Biplot（PC1 %.1f%% | PC2 %.1f%%）",
                        var_off[1], var_off[2])
) + theme_minimal(base_size = 11) +
  theme(legend.position = "right")

# ── 圖3：防守 Biplot（PC1 vs PC2，依勝負上色）────────────
p_def_biplot <- fviz_pca_biplot(
  pca_def,
  geom.ind    = "point",
  col.ind     = ifelse(df_clean$win, "勝", "敗"),
  palette     = c("勝" = "#2E7D32", "敗" = "#C62828"),
  addEllipses = TRUE, ellipse.level = 0.68,
  col.var     = "#333333",
  repel       = TRUE,
  label       = "var",
  title       = sprintf("防守 Biplot（PC1 %.1f%% | PC2 %.1f%%）",
                        var_def[1], var_def[2])
) + theme_minimal(base_size = 11) +
  theme(legend.position = "right")

# ── 圖4：進攻 PC1 vs PC3（呈現第三維度）─────────────────
p_off_pc13 <- ggplot(pca_result,
                      aes(x = Off_PC1, y = Off_PC3, color = team)) +
  geom_point(alpha = 0.6, size = 1.6) +
  stat_ellipse(aes(group = team), level = 0.68, linewidth = 0.5) +
  scale_color_manual(values = team_colors, name = "球隊") +
  labs(title = "進攻 PC1 vs PC3（依球隊）",
       x = sprintf("Off_PC1 (%.1f%%)", var_off[1]),
       y = sprintf("Off_PC3 (%.1f%%)", var_off[3])) +
  theme_minimal(base_size = 11)

# ── 圖5：防守 PC1 vs PC3（勝/敗 + 主/客場）──────────────
p_def_pc13 <- ggplot(pca_result,
                      aes(x = Def_PC1, y = Def_PC3,
                          color = win, shape = is_home)) +
  geom_point(alpha = 0.6, size = 1.6) +
  scale_color_manual(values = c("TRUE" = "#2E7D32", "FALSE" = "#C62828"),
                     labels = c("TRUE" = "勝", "FALSE" = "敗"),
                     name = "結果") +
  scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 1),
                     labels = c("TRUE" = "主場", "FALSE" = "客場"),
                     name = "場地") +
  labs(title = "防守 PC1 vs PC3（勝敗 × 主客場）",
       x = sprintf("Def_PC1 (%.1f%%)", var_def[1]),
       y = sprintf("Def_PC3 (%.1f%%)", var_def[3])) +
  theme_minimal(base_size = 11)

# ── 圖6：各變數對 PC 的貢獻度（進攻）────────────────────
p_off_contrib <- fviz_contrib(pca_off, choice = "var", axes = 1:3,
                               fill = "#1565C0", color = "#1565C0") +
  labs(title = "進攻變數對 PC1~PC3 的貢獻度") +
  theme_minimal(base_size = 11)

# ── 圖7：各變數對 PC 的貢獻度（防守）────────────────────
p_def_contrib <- fviz_contrib(pca_def, choice = "var", axes = 1:3,
                               fill = "#2E7D32", color = "#2E7D32") +
  labs(title = "防守變數對 PC1~PC3 的貢獻度") +
  theme_minimal(base_size = 11)

# ══════════════════════════════════════════════════════════
# 儲存圖片
# ══════════════════════════════════════════════════════════
out_dir <- "."

png(file.path(out_dir, "pca_01_scree.png"), width = 13, height = 5, units = "in", res = 150)
grid.arrange(p_scree_off, p_scree_def, ncol = 2)
dev.off()

png(file.path(out_dir, "pca_02_biplot.png"), width = 15, height = 6, units = "in", res = 150)
grid.arrange(p_off_biplot, p_def_biplot, ncol = 2)
dev.off()

png(file.path(out_dir, "pca_03_pc13.png"), width = 13, height = 5, units = "in", res = 150)
grid.arrange(p_off_pc13, p_def_pc13, ncol = 2)
dev.off()

png(file.path(out_dir, "pca_04_contrib.png"), width = 13, height = 5, units = "in", res = 150)
grid.arrange(p_off_contrib, p_def_contrib, ncol = 2)
dev.off()

# ══════════════════════════════════════════════════════════
# 儲存 PC scores CSV
# ══════════════════════════════════════════════════════════
write.csv(pca_result,
          "pca_scores.csv",
          row.names = FALSE)

cat("\n── 完成 ──\n")
cat("輸出圖片：pca_01_scree.png / pca_02_biplot.png / pca_03_pc13.png / pca_04_contrib.png\n")
cat("PC scores：pca_scores.csv\n")

