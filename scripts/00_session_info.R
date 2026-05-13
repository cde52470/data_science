# ============================================================================
# File   : scripts/00_session_info.R
# Purpose: Dump sessionInfo() to Results/session_info.txt for reproducibility
#          (CLAUDE.md §6 rule 4). Sourced at the end of any Phase A / B run.
# Author : Sub-Agent 4 (model-builder)
# Date   : 2026-05-13
# ============================================================================

# 用法: 在任何一個 entry-point script (例如 03a_phase_a_poc.R) 跑完後,
#   source(here::here("scripts/00_session_info.R"))
# 之即可。獨立 source 也 ok, 不會 side-effect 到 global env (除了寫檔)。

suppressPackageStartupMessages({
  library(here)
})

config <- list(
  out_path = here::here("Results", "session_info.txt")
)

dir.create(dirname(config$out_path),
           showWarnings = FALSE,
           recursive    = TRUE)

# capture.output 把 sessionInfo() 完整列印捕捉成字串向量, 寫出 plain text
session_lines <- c(
  sprintf("# sessionInfo() captured at %s", format(Sys.time(), tz = "UTC",
                                                   usetz = TRUE)),
  sprintf("# R version: %s", R.version.string),
  sprintf("# Working dir: %s", here::here()),
  "",
  utils::capture.output(utils::sessionInfo())
)

writeLines(session_lines, con = config$out_path)

message("[00_session_info.R] wrote ", config$out_path)
invisible(config$out_path)
