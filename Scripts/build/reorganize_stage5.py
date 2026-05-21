"""Physically subdivide Results/stage5/ into 10 sub-folders matching the
9 README sub-categories (numbered prefix for stable ordering)."""
from __future__ import annotations
import shutil
from pathlib import Path

RESULTS = Path("/home/user/data_science_final_project/Results")
S5 = RESULTS / "stage5"

# Mapping: subfolder -> list of stage5_*.{ext} filenames
SUBFOLDERS = {
    "01_filter_scale": [
        "stage5_filter_prune_log.csv",
        "stage5_scaled_describe.csv",
    ],
    "02_pca": [
        "stage5_pca_scree.png",
        "stage5_pca_biplot.png",
        "stage5_pca_biplot_interactive.html",
        "stage5_pca_loadings_abs.csv",
        "stage5_loadings_heatmap.png",
        "stage5_pca_3d.html",
    ],
    "03_k_consensus": [
        "stage5_kmeans_metrics.csv",
        "stage5_gap_statistic.csv",
        "stage5_gmm_metrics.csv",
        "stage5_k_consensus_votes.csv",
        "stage5_k_consensus_panel.png",
    ],
    "04_hierarchy": [
        "stage5_hierarchy_linkage_comparison.csv",
        "stage5_hierarchy_full_matrix.csv",
        "stage5_hierarchy_silhouette_sweep.csv",
        "stage5_dendrogram_4linkages.png",
        "stage5_hierarchy_kselection.png",
    ],
    "05_gmm": [
        "stage5_gmm_bic.png",
    ],
    "06_hdbscan": [
        "stage5_hdbscan_tree.png",
    ],
    "07_validity": [
        "stage5_validity_panel.csv",
        "stage5_silhouette_per_point.png",
    ],
    "08_embeddings": [
        "stage5_umap_pair.png",
        "stage5_tsne_perplexity.png",
    ],
    "09_interpretation": [
        "stage5_cluster_means.csv",
        "stage5_cluster_stds.csv",
        "stage5_cluster_radar.png",
        "stage5_cluster_boxplots.png",
        "stage5_shap_per_cluster.csv",
        "stage5_meaningful_features.csv",
        "stage5_anova_top12.png",
    ],
    "10_cross_season": [
        "stage5_season_cluster_xtab.csv",
        "stage5_cluster_freq_shift.png",
        "stage5_season_cluster_sankey.html",
    ],
}

moved = 0
missing = []
for sub, files in SUBFOLDERS.items():
    dest_dir = S5 / sub
    dest_dir.mkdir(exist_ok=True)
    for fn in files:
        src = S5 / fn
        dest = dest_dir / fn
        if src.exists():
            shutil.move(str(src), str(dest))
            moved += 1
        elif not dest.exists():
            missing.append(fn)

# Sanity check: any leftover files in stage5/ root?
leftovers = sorted(p.name for p in S5.iterdir() if p.is_file())
print(f"Moved {moved} files into {len(SUBFOLDERS)} sub-folders.")
if leftovers:
    print(f"WARNING: {len(leftovers)} files still flat in Results/stage5/:")
    for f in leftovers:
        print(f"  {f}")
if missing:
    print(f"MISSING (expected but not found): {missing}")

# Print final tree
print("\nFinal structure:")
for sub in sorted(p.name for p in S5.iterdir() if p.is_dir()):
    sub_dir = S5 / sub
    n = sum(1 for _ in sub_dir.iterdir())
    print(f"  Results/stage5/{sub}/   ({n} files)")
