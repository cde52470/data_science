#!/usr/bin/env Rscript

# Reproduce the current CPBL context-labeling analysis pipeline.
# Run from the project root:
# Rscript share_analyze/run_all_analysis.R

scripts <- c(
  "share_analyze/01_build_team_game_features.R",
  "share_analyze/02_eda_home_away.R",
  "share_analyze/03_eda_status_labels.R",
  "share_analyze/04_prepare_model_dataset.R",
  "share_analyze/05_train_descriptive_models.R",
  "share_analyze/06_cross_validate_descriptive_models.R",
  "share_analyze/07_visualize_model_results.R",
  "share_analyze/08_train_tree_models.R",
  "share_analyze/09_cv_tree_models.R",
  "share_analyze/10_xgboost_shap_analysis.R",
  "share_analyze/11_visualize_xgboost_and_model_comparison.R",
  "share_analyze/12_feature_importance_consensus.R",
  "share_analyze/13_tune_xgboost_limited.R",
  "share_analyze/14_update_model_comparison_with_tuned_xgboost.R",
  "share_analyze/15_create_model_labeled_dataset.R"
)

for (script in scripts) {
  message("Running: ", script)
  result <- system2("Rscript", script)

  if (!identical(result, 0L)) {
    stop("Pipeline stopped because this script failed: ", script)
  }
}

message("Analysis pipeline completed.")
