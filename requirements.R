# ============================================================================
# File   : requirements.R
# Purpose: Fallback package list when renv::restore() is not available.
#          Per CLAUDE.md §4 directory contract.
# Author : Sub-Agent 4 (model-builder)
# Date   : 2026-05-13
# ============================================================================

# 用法 (RStudio Desktop / Posit Cloud, 沒有 renv.lock 的情況):
#   source("requirements.R")
# 此檔僅宣告 install.packages() 呼叫, 不真的執行其他副作用。
# 若已有 renv.lock, 改跑 renv::restore() (CLAUDE.md §6 rule 4).

required_pkgs <- c(
  # ---- tidyverse 主幹 ----
  "tidyverse",   # dplyr, tidyr, purrr, readr, tibble, stringr, ggplot2, ...
  "lubridate",
  "here",
  "logger",

  # ---- tidymodels stack ----
  "tidymodels",
  "parsnip",
  "recipes",
  "rsample",
  "workflows",
  "workflowsets",
  "tune",
  "yardstick",
  "dials",

  # ---- engines ----
  "glmnet",     # m7 elastic-net (Phase A) + tuning (Phase B)
  "ranger",     # random forest, Phase B
  "xgboost",    # boost tree, Phase B

  # ---- interpretation / SA-5 hand-off ----
  "vip",        # variable importance plots
  "DALEX",      # model-agnostic explainers (passes baton to SA-5)
  "butcher",    # slim down fitted model objects for deployment

  # ---- POC + IO ----
  "jsonlite",   # manifest.json + log payload serialisation
  "readr"
)

# 顯示哪些已裝, 哪些缺
installed <- rownames(utils::installed.packages())
missing   <- setdiff(required_pkgs, installed)

message("Required: ", length(required_pkgs), " | Missing: ", length(missing))
if (length(missing) > 0) {
  message("Installing missing: ", paste(missing, collapse = ", "))
  utils::install.packages(missing)
} else {
  message("All required packages already installed.")
}

invisible(required_pkgs)
