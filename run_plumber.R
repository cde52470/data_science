library(plumber)

base_dir <- Sys.getenv("BASEBALL_DATA_DIR",
                       unset = dirname(normalizePath(sys.frames()[[1]]$ofile,
                                                     mustWork = FALSE)))
host     <- Sys.getenv("PLUMBER_HOST",      unset = "127.0.0.1")

pr(file.path(base_dir, "decision_plot.R")) %>%
  pr_run(host = host, port = 8001)
