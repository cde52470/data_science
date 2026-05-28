# Topic 08 — Unsupervised Learning (Clustering, Association Rules, and the Broader Landscape)

> Lecturer: Jia-Ming Chang (Department of Computer Science, NCCU)
> Source slide deck: `topic08_unsupervised` — Data Science course
> Primary textbooks cited: *Practical Data Science with R* (Zumel & Mount, Manning 2019), Chapter 8 "Unsupervised Methods"; *An Introduction to Statistical Learning* (James, Witten, Hastie, Tibshirani, 2013), Chapter 10.3 "Clustering Methods".
> Scope note: the lecture's explicit content is hierarchical clustering, k-means, association rule mining (with cluster validity heuristics). The KB extends this scope with sklearn-equivalent translations and supplementary methods that are useful for the CPBL final project (DBSCAN, GMM, t-SNE, UMAP, autoencoders, anomaly detectors, etc.). Each method's section marks **[in lecture]** vs **[supplementary, sklearn-aligned]** so the project notebook can stay faithful to course material while still exploring the wider toolbox.

---

## 1. Topic Summary

Unsupervised learning is the family of techniques that ingest only the features `X1, X2, ..., Xp` measured across `n` observations — there is no response variable `Y`. The goal is to **discover structure** in the data: which observations clump together, which features co-vary, which transactions tend to co-occur, which points look anomalous, and which low-dimensional manifold the data approximately lives on. Where supervised learning answers "predict Y given X", unsupervised learning answers "what interesting things can I say about X alone?"

The lecture frames the topic around two pillars and one validation theme:

1. **Cluster analysis** — find homogeneous subgroups (rows that resemble each other across many features). Two main approaches are taught: hierarchical clustering (no need to pre-specify K, yields a dendrogram showing every nesting from K=1 to K=n) and k-means clustering (partition into a pre-specified K non-overlapping sets that locally minimise within-cluster squared distance).
2. **Association rule mining** — find features/items that frequently co-occur in transactions, expressed as "if X then Y" rules with support, confidence, and lift.
3. **Cluster validity / stability** — heuristics for choosing K (WSS elbow, Calinski–Harabasz, silhouette) and resampling-based confidence (Jaccard via `clusterboot`).

For the CPBL project, unsupervised methods will be deployed **after** descriptive statistics and EDA to (a) discover game archetypes (e.g. blowout, pitcher's duel, late-inning comeback), (b) find player/season profiles that supervised models will then predict, (c) reduce dimensionality before classification, and (d) check whether the clusters that emerge from raw box-score features map naturally onto the consensus supervised features identified by Senior Wang (run_per_hit, innings_pitched, H, scored_first, whip_like, hr_allowed, hits_allowed, AB, middle_runs, late_runs). If those features show up as dominant directions in PCA / cluster separators, that is independent evidence that the supervised story is real.

Big themes from the lecture worth carrying forward:

- **Scaling matters enormously** — units of measurement directly determine distances, so almost every clustering pipeline begins with `scale()` (R) / `StandardScaler` (sklearn).
- **K is not unique** — different K values and different methods give different answers; the analyst must explore and compare, not blindly accept one output.
- **Clustering is iterative and exploratory**, more like visualisation than like model fitting. Multiple algorithms should be tried.
- **Stability beats coincidence** — bootstrap-based Jaccard tests separate clusters that are robust to resampling from those that are artefacts of the particular sample.
- **Association rule mining** uses very different machinery (frequent itemsets, Apriori) but the same overarching goal: discover co-occurrence structure without labels.

---

## 2. Outline (full unsupervised landscape, with lecture coverage highlighted)

Lecture's stated outline (slide "Outline"):

1. Clustering analysis
   - Distance measurement
   - Hierarchical clustering (linkages)
   - K-means (and how to determine K)
   - Whether a given cluster is real (Jaccard / clusterboot)
2. Association rule mining (support, confidence, lift, Apriori, restrictions)

Broader unsupervised landscape (KB extension; not every item is in the lecture but every item is fair game for the CPBL notebook):

- **Partitional clustering**: K-Means, K-Medoids (PAM), Mini-Batch K-Means, Fuzzy C-Means.
- **Hierarchical clustering**: Agglomerative (bottom-up) with single / complete / average / Ward / centroid linkage; Divisive (DIANA, top-down) — only the agglomerative family is in the lecture; linkages are taught in detail.
- **Density-based clustering**: DBSCAN, HDBSCAN, OPTICS, Mean-Shift.
- **Model-based / probabilistic clustering**: Gaussian Mixture Models with EM; Bayesian GMMs; Dirichlet Process mixtures.
- **Graph / spectral clustering**: Spectral Clustering (Laplacian eigenmap + KMeans), Affinity Propagation.
- **Tree / hierarchical-summary clustering**: BIRCH (CF-tree based, scalable).
- **Neural / self-organising**: Self-Organising Maps (Kohonen).
- **Dimensionality reduction** (often a sister step):
   - Linear: PCA, SVD, ICA, NMF, Factor Analysis.
   - Non-linear / manifold: Kernel PCA, MDS, Isomap, LLE, Spectral Embedding, t-SNE, UMAP.
   - Neural: Autoencoders (vanilla, denoising, variational).
- **Anomaly / outlier detection**: Isolation Forest, Local Outlier Factor (LOF), One-Class SVM, Elliptic Envelope.
- **Density estimation**: Kernel Density Estimation, GMM as density estimator.
- **Association / pattern mining** (lecture covers this explicitly): Apriori, ECLAT, FP-Growth.

---

## 3. Key Concepts

### 3.1 Distance and similarity measures (lecture: explicit)

The lecture introduces the four standard families that the rest of the topic depends on:

- **Manhattan (L1) distance** — sum of absolute coordinate differences. `d(x,y) = Σ |x_i − y_i|`. Robust to outliers in any one dimension.
- **Euclidean (L2) distance** — square root of sum of squared coordinate differences. `d(x,y) = sqrt(Σ (x_i − y_i)^2)`. The default for K-means and for `hclust`'s default. Sensitive to scale of each feature, hence the universal preprocessing step `scale()`.
- **Hamming distance** — number of coordinates where x and y disagree (for binary/categorical vectors). `d(x,y) = Σ 1[x_i ≠ y_i]`.
- **Cosine similarity** — measures the angle between vectors, ignoring magnitude. `cos(x,y) = (x · y) / (||x|| ||y||)`. The lecture motivates this with text analytics: in word-count vectors, a long document need not be more "about" a word just because the raw count is higher, so direction (relative composition) matters more than length.

The lecture also mentions:

- **Set-based measures** (Jaccard, etc.) for set-valued data.
- **Correlation-based distance** `d(x,y) = 1 − cor(x,y)`. The slides give an R example: build the distance matrix with `as.dist(1 - cor(t(x)))` and then run `hclust(..., method="complete")`. Correlation distance treats two observations as similar if their feature *profiles* go up and down together, even if their absolute magnitudes differ — useful when scale is uninformative but pattern is.

### 3.2 Scaling / standardisation (lecture: emphasised explicitly)

Because distances depend on units, before clustering the lecture recommends `scale(protein[,vars.to.use])`, which centres each column at mean 0 and rescales to standard deviation 1. The slide goes out of its way to say: **"the units that each variable is measured in matter. Different units cause different distances and potentially different clusterings."** In sklearn the equivalent is `sklearn.preprocessing.StandardScaler`. For data with heavy tails, robust alternatives include `RobustScaler` (median + IQR) and `QuantileTransformer`.

### 3.3 Intrinsic dimensionality (supplementary, important for CPBL)

The intrinsic dimensionality of a dataset is the minimum number of latent coordinates needed to capture its structure. Box-score features (e.g. 30+ per game) typically have an intrinsic dimensionality much lower than 30 because many features are correlated (hits and AB; pitches thrown and innings pitched; etc.). Estimators: variance explained curve from PCA, two-NN method (Facco et al.), Maximum Likelihood Estimator (Levina–Bickel). For CPBL we will use PCA's cumulative explained variance as a rough proxy.

### 3.4 Curse of dimensionality

In high dimensions distances concentrate (the ratio of maximum to minimum pairwise distance approaches 1), so notions of "nearest neighbour" lose discriminative power. This affects DBSCAN/k-means/k-NN. Mitigations: dimensionality reduction before clustering, manifold methods, or metrics adapted to high-D (e.g. fractional p<1 norms).

### 3.5 Cluster validity criteria (lecture: WSS, BSS, CH, silhouette)

Definitions used in lecture:

- **WSS (Within Sum of Squares)** — for a single cluster, the average squared Euclidean distance of every point in the cluster from the cluster centroid. The cluster centroid is the column-wise mean of all points in that cluster. WSS(k) = Σ_clusters Σ_points ||x − c_cluster||². In R: see `WSS.R` snippet on slide.
- **TSS (Total Sum of Squares)** — squared distance of every data point from the grand mean. Independent of K.
- **BSS (Between Sum of Squares)** = TSS − WSS. As K grows, WSS decreases and BSS increases.
- **Within-cluster variance** W = WSS(k) / (n − k).
- **Between-cluster variance** B = BSS(k) / (k − 1).
- **Calinski–Harabasz index** (a.k.a. Variance Ratio Criterion) = B / W. Higher is better. The K that maximises CH is a candidate optimal K. (Caliński & Harabasz 1974, "A dendrite method for cluster analysis".)
- **Silhouette s(i)** — for point i, with a(i) the mean intra-cluster distance and b(i) the mean nearest-cluster distance, `s(i) = (b(i) − a(i)) / max(a(i), b(i))`. Range −1..1:
  - 1: well-clustered
  - 0: overlapping clusters
  - −1: i would fit better in a neighbouring cluster
  Average silhouette over all points = silhouette width; choose the K that maximises it.
- **Two-scenarios commentary** (slide): if K too low, dense clusters get fused → a(i) large → s(i) small; if K too high, natural clusters get fragmented → b(i) tiny → s(i) small. Either extreme is detectable from the silhouette.

### 3.6 Cluster stability (lecture: Jaccard / clusterboot)

After clustering once, bootstrap the data (sample n rows with replacement), re-cluster, and for every original cluster find the new cluster with maximum **Jaccard coefficient** = `|A ∩ B| / |A ∪ B|`. Repeat many bootstraps. Report:

- Cluster stability = mean Jaccard over bootstraps.
- 0.6 or less: unstable / dissolved (slide says treat as not real if max Jaccard < 0.5 on a given bootstrap).
- 0.6–0.75: a real pattern but membership is uncertain.
- ≥ 0.85: highly stable, likely a real cluster.

This is the lecture's principal answer to "is this cluster real or a coincidence of one particular sample?" In sklearn there is no built-in `clusterboot`, but it is straightforward to write the loop.

### 3.7 Other useful concepts (supplementary)

- **Cluster cohesion vs separation**: cohesion = how tight a cluster is; separation = how far clusters are from each other. Most validity scores are functions of these.
- **Hard vs soft clustering**: hard = each point belongs to exactly one cluster (K-means, hclust); soft = each point has a probability distribution over clusters (GMM/EM, fuzzy c-means).
- **Connected vs convex clusters**: K-means assumes roughly spherical/convex clusters; DBSCAN handles arbitrarily-shaped connected ones.

---

## 4. Methods — full catalogue

The format for each is:

> **Name** | When to use | Math/algorithm | Python (sklearn) | Hyperparameters | Caveats | Lecture status

### 4.1 K-Means **[in lecture]**

- **When**: numeric features, roughly spherical clusters of comparable size, K known or to be chosen by a heuristic, dataset small to medium.
- **Algorithm**:
  1. Pick K initial centroids (random, or `k-means++` for spread).
  2. Assign each point to the nearest centroid (Euclidean by default).
  3. Recompute each centroid as the column-wise mean of its assigned points.
  4. Iterate 2–3 until assignments stop changing (or iter.max).
  Objective: minimise sum over clusters of Σ ||x − c_cluster||² = WSS(K). Equivalent to maximising BSS(K) since TSS is constant.
- **Python**: `from sklearn.cluster import KMeans`. Fit with `KMeans(n_clusters=K, n_init=10, max_iter=300, random_state=42).fit(X)`. Access `.labels_`, `.cluster_centers_`, `.inertia_` (= WSS).
- **Hyperparameters**: `n_clusters` (K), `n_init` (number of random restarts; lecture recommends 20–50 in R's `kmeans(... nstart=...)`; sklearn default is 10), `init` (`k-means++` recommended), `max_iter`, `tol`, `algorithm` (`lloyd` / `elkan`), `random_state` for reproducibility.
- **Caveats** (per lecture): must pick K in advance, unstable across runs (final clusters depend on initial centres → run with `nstart > 1`), no unique stopping point guaranteed, assumes mixture-of-Gaussians-like structure with equal isotropic covariance, sensitive to outliers (because of squared distance), only sensible with numeric features and Euclidean distance.

### 4.2 K-Medoids / PAM **[supplementary]**

- **When**: like K-means but want centres that are actual data points (medoids) instead of means; works with arbitrary distance matrix (good for mixed/categorical data via Gower distance).
- **Algorithm**: PAM (Partitioning Around Medoids) — repeatedly swap medoids and non-medoids if the swap reduces total dissimilarity.
- **Python**: `from sklearn_extra.cluster import KMedoids` (in the `scikit-learn-extra` package). Alternative: `pyclustering`.
- **Hyperparameters**: `n_clusters`, `metric`, `method` (`alternate` / `pam`).
- **Caveats**: O(n²) memory for distance matrix; slower than K-means; more robust to outliers (because medoid not pulled by extremes).

### 4.3 Mini-Batch K-Means **[supplementary]**

- **When**: same as K-means but n is very large.
- **Algorithm**: same updates as K-means but at each step only a random mini-batch of size b is used; centroids updated with a learning rate that decays with the count of points assigned to that centroid.
- **Python**: `from sklearn.cluster import MiniBatchKMeans`.
- **Hyperparameters**: `n_clusters`, `batch_size`, `n_init`, `max_iter`, `reassignment_ratio`.
- **Caveats**: slightly worse WSS than full K-means but 10–100× faster; useful for streaming.

### 4.4 Hierarchical (Agglomerative) Clustering **[in lecture]**

- **When**: K unknown; want a dendrogram view; small-to-medium n (O(n²) memory for the dissimilarity matrix); want nested clusterings.
- **Algorithm** (agglomerative, bottom-up):
  1. Treat every observation as its own cluster.
  2. Compute the pairwise dissimilarity matrix (Euclidean by default, but any metric works).
  3. Find the two closest clusters under a chosen **linkage** rule and merge them.
  4. Update dissimilarities; repeat until one cluster remains.
  5. Cut the resulting dendrogram at height h (or to give K clusters via `cutree`).
- **Linkages** (lecture's explicit list):
  - **Single linkage** = minimum distance between any pair across two clusters. Tends to produce imbalanced dendrograms and the *chaining effect* (long stringy clusters where points connect via long thin bridges).
  - **Complete linkage** = maximum pairwise distance across two clusters. Compact, balanced clusters. Popular default.
  - **Average linkage** = mean pairwise distance across two clusters. Compromise between single and complete; also widely used.
  - **Ward linkage** = merge the pair whose union minimises the increase in total within-cluster sum of squares. Produces compact spherical clusters; very common in practice. Uses squared Euclidean distance.
  - **Centroid linkage** = distance between cluster centroids. Mentioned as common in genomics; drawback: *inversions* can occur, where two clusters fuse at a height below either child cluster — visually confusing.
  Lecture explicitly recommends average / complete / Ward over single because of chaining.
- **Python**: `from sklearn.cluster import AgglomerativeClustering`; or `from scipy.cluster.hierarchy import linkage, dendrogram, fcluster` for full dendrogram support.
- **Hyperparameters**: `n_clusters` or `distance_threshold`, `linkage` (`ward` / `complete` / `average` / `single`), `metric` (`euclidean` required for `ward`).
- **R equivalent on slide**: `d <- dist(pmatrix, method="euclidean"); pfit <- hclust(d, method="complete"); plot(pfit, labels=protein$Country); rect.hclust(pfit, k=5); groups <- cutree(pfit, k=5)`.
- **Caveats**: O(n²) memory and at best O(n² log n) time; once a merge is made it cannot be undone (greedy); choice of cut height is subjective; can be worse than K-means for a given K (lecture's male/female × American/Japanese/French thought experiment — hierarchical can't represent a 2-way × 3-way crossed structure cleanly because each split must be hierarchical, not crossed).

### 4.5 DBSCAN — Density-Based Spatial Clustering **[supplementary, very useful for CPBL outlier games]**

- **When**: clusters of arbitrary shape, want automatic outlier flagging, density is roughly uniform within a cluster.
- **Algorithm**: a point is a **core point** if at least `min_samples` other points lie within distance `eps`. Core points within ε of each other join the same cluster; points within ε of a core point but not themselves core are **border points**. Points belonging to no cluster are **noise/outliers** (label −1).
- **Python**: `from sklearn.cluster import DBSCAN`.
- **Hyperparameters**: `eps`, `min_samples`, `metric`.
- **Caveats**: choice of `eps` is critical; sensitive to varying density (a single ε won't fit clusters of very different density — use HDBSCAN); needs scaled features; struggles in high dimensions.

### 4.6 HDBSCAN **[supplementary]**

- **When**: like DBSCAN but with clusters of varying density; want a hierarchy and stability-based selection.
- **Algorithm**: build a mutual-reachability graph, form a minimum spanning tree, derive a cluster hierarchy, and extract clusters via stability.
- **Python**: `from sklearn.cluster import HDBSCAN` (sklearn ≥ 1.3) or the `hdbscan` package.
- **Hyperparameters**: `min_cluster_size`, `min_samples`, `cluster_selection_epsilon`, `cluster_selection_method`.
- **Caveats**: more robust than DBSCAN, fewer dials; still struggles with very high-D.

### 4.7 OPTICS **[supplementary]**

- **When**: similar to DBSCAN but want to see structure at multiple density scales.
- **Algorithm**: produces a reachability plot from which clusters at various densities can be read off.
- **Python**: `from sklearn.cluster import OPTICS`.
- **Hyperparameters**: `min_samples`, `max_eps`, `xi`, `cluster_method` (`xi` or `dbscan`).
- **Caveats**: slower than DBSCAN; the reachability plot needs interpretation.

### 4.8 Gaussian Mixture Model (EM) **[supplementary]**

- **When**: probabilistic (soft) clustering, clusters are roughly Gaussian but with different covariances; want a generative model and likelihood.
- **Algorithm**: assume the data are generated by a mixture Σ_k π_k N(μ_k, Σ_k). Fit by Expectation–Maximisation:
  - E step: compute responsibility γ_ik = π_k N(x_i; μ_k, Σ_k) / Σ_j π_j N(x_i; μ_j, Σ_j).
  - M step: update π_k, μ_k, Σ_k as responsibility-weighted statistics.
  Iterate to convergence.
- **Python**: `from sklearn.mixture import GaussianMixture` (or `BayesianGaussianMixture` with Dirichlet prior, which can automatically prune unused components).
- **Hyperparameters**: `n_components`, `covariance_type` (`full`/`tied`/`diag`/`spherical`), `init_params`, `n_init`, `reg_covar`.
- **Caveats**: assumes Gaussian components — bad fit for very non-Gaussian distributions; component count chosen via AIC/BIC; sensitive to init; `covariance_type='full'` has many parameters in high-D.

### 4.9 Spectral Clustering **[supplementary]**

- **When**: clusters with complex, non-convex structure where similarity (e.g. via a Gaussian kernel) captures structure better than Euclidean distance.
- **Algorithm**:
  1. Build a similarity matrix (RBF, k-NN graph, ...).
  2. Compute the graph Laplacian.
  3. Take the K smallest eigenvectors → embedding.
  4. Run K-means in the embedded space.
- **Python**: `from sklearn.cluster import SpectralClustering`.
- **Hyperparameters**: `n_clusters`, `affinity` (`rbf`, `nearest_neighbors`, `precomputed`), `gamma` (RBF bandwidth), `n_neighbors`.
- **Caveats**: O(n³) eigen-decomposition; scaling to many thousands of points needs Nyström approximations; gamma is touchy.

### 4.10 Affinity Propagation **[supplementary]**

- **When**: don't want to pre-specify K; message-passing finds exemplars.
- **Algorithm**: iteratively pass "responsibility" and "availability" messages between data points until exemplars emerge.
- **Python**: `from sklearn.cluster import AffinityPropagation`.
- **Hyperparameters**: `damping`, `preference` (controls number of exemplars), `affinity`.
- **Caveats**: O(n²) memory and time; preference parameter is non-obvious; can produce too many clusters.

### 4.11 Mean Shift **[supplementary]**

- **When**: don't know K, want mode-seeking on a density estimate.
- **Algorithm**: iteratively shift each point toward the local maximum of a kernel density estimate.
- **Python**: `from sklearn.cluster import MeanShift, estimate_bandwidth`.
- **Hyperparameters**: `bandwidth`, `bin_seeding`, `cluster_all`.
- **Caveats**: bandwidth choice is crucial and computationally expensive; struggles with high-D.

### 4.12 BIRCH **[supplementary]**

- **When**: very large datasets that don't fit in memory; need an incremental summary.
- **Algorithm**: build a CF-tree (Clustering Feature tree) of micro-cluster sufficient statistics, then cluster the leaf-level summaries with another algorithm (often Agglomerative).
- **Python**: `from sklearn.cluster import Birch`.
- **Hyperparameters**: `threshold`, `branching_factor`, `n_clusters`.
- **Caveats**: assumes spherical clusters; sensitive to order of data; only good for numeric Euclidean data.

### 4.13 Self-Organising Maps (SOM / Kohonen networks) **[supplementary]**

- **When**: want a 2D topographic visualisation of high-dimensional data; clusters on a grid.
- **Algorithm**: train a 2D grid of prototype vectors with competitive learning so neighbouring prototypes encode similar inputs.
- **Python**: `MiniSom` or `sklearn-som` (not in core sklearn). Example: `from minisom import MiniSom`.
- **Hyperparameters**: grid shape, learning rate, sigma (neighbourhood radius), iterations.
- **Caveats**: outside core sklearn; sensitive to initial weights; useful for visualisation more than for hard clustering.

### 4.14 PCA — Principal Component Analysis **[supplementary, lecture uses it for visualisation]**

- **When**: dimensionality reduction, decorrelation, visualisation. The slide uses `prcomp(pmatrix)` to project the protein-data clusters onto PC3/PC4.
- **Algorithm**: eigen-decompose the covariance matrix (or SVD the centred data matrix). The k principal components are the orthogonal directions of maximum variance.
- **Python**: `from sklearn.decomposition import PCA`. Use `PCA(n_components=...).fit_transform(X)`.
- **Hyperparameters**: `n_components` (int, float for variance retained, or `'mle'`), `whiten`, `svd_solver` (`auto`/`full`/`randomized`).
- **Caveats**: linear; sensitive to scaling (always standardise first); top components ≠ predictive components.

### 4.15 Kernel PCA **[supplementary]**

- **When**: PCA in a non-linear feature space (RBF, polynomial, sigmoid).
- **Python**: `from sklearn.decomposition import KernelPCA`.
- **Hyperparameters**: `n_components`, `kernel`, `gamma`, `degree`, `coef0`, `fit_inverse_transform`.
- **Caveats**: O(n²) kernel matrix; gamma tuning matters; no easy interpretation of components.

### 4.16 ICA — Independent Component Analysis **[supplementary]**

- **When**: source separation; recovering statistically independent latent signals (e.g. blind source separation).
- **Python**: `from sklearn.decomposition import FastICA`.
- **Hyperparameters**: `n_components`, `algorithm` (`parallel` / `deflation`), `fun`, `whiten`.
- **Caveats**: requires non-Gaussian sources to recover; sign and order of components are not identifiable.

### 4.17 NMF — Non-negative Matrix Factorisation **[supplementary]**

- **When**: data is non-negative (counts, intensities), want parts-based additive decomposition.
- **Python**: `from sklearn.decomposition import NMF`.
- **Hyperparameters**: `n_components`, `init`, `solver` (`cd`/`mu`), `beta_loss`, `l1_ratio`, `alpha`.
- **Caveats**: non-unique factorisation; requires X ≥ 0; component count chosen heuristically.

### 4.18 t-SNE **[supplementary]**

- **When**: 2D / 3D visualisation of high-D data with non-linear structure; preserves *local* neighbourhood.
- **Algorithm**: model pairwise similarities in input space as Gaussian, in output as t-distributed, minimise KL divergence with gradient descent.
- **Python**: `from sklearn.manifold import TSNE`.
- **Hyperparameters**: `n_components` (almost always 2), `perplexity` (5–50, typically 30), `learning_rate`, `n_iter`, `init` (`pca` recommended), `metric`.
- **Caveats**: distances in the output map are **not** meaningful at the global scale — only local neighbourhoods are; stochastic; not for downstream modelling; perplexity sensitive.

### 4.19 UMAP **[supplementary]**

- **When**: t-SNE-like visualisation but faster, preserves more global structure, and can be used as a general non-linear dim reduction.
- **Algorithm**: build a fuzzy simplicial set graph in high-D, optimise a low-D layout that has a similar graph.
- **Python**: `import umap; reducer = umap.UMAP()`. Not in core sklearn; install `umap-learn`.
- **Hyperparameters**: `n_neighbors`, `min_dist`, `n_components`, `metric`, `random_state`.
- **Caveats**: stochastic; global geometry better than t-SNE but still not strictly metric; can produce spurious clusters if `min_dist` too small.

### 4.20 MDS — Multi-Dimensional Scaling **[supplementary]**

- **When**: have a distance/dissimilarity matrix and want to embed it in low-D.
- **Python**: `from sklearn.manifold import MDS`.
- **Hyperparameters**: `n_components`, `metric` (True = classical MDS / PCoA, False = non-metric), `dissimilarity` (`precomputed`).
- **Caveats**: O(n²); poor for very large n.

### 4.21 Isomap **[supplementary]**

- **When**: data lies on a curved low-D manifold; want geodesic-preserving embedding.
- **Algorithm**: build k-NN graph, compute shortest path distances, run classical MDS on those.
- **Python**: `from sklearn.manifold import Isomap`.
- **Hyperparameters**: `n_neighbors`, `n_components`.
- **Caveats**: graph-disconnection if k too small; expensive for large n.

### 4.22 LLE — Locally Linear Embedding **[supplementary]**

- **When**: preserve local linear reconstructions.
- **Python**: `from sklearn.manifold import LocallyLinearEmbedding`.
- **Hyperparameters**: `n_neighbors`, `n_components`, `method` (`standard`/`modified`/`hessian`/`ltsa`), `reg`.
- **Caveats**: sensitive to neighbourhood graph; can collapse.

### 4.23 Autoencoders **[supplementary, neural]**

- **When**: very large data, want non-linear feature embedding; have GPU; want to learn representations end-to-end.
- **Architecture**: encoder `f` compresses x to z (bottleneck), decoder `g` reconstructs x'. Loss = reconstruction error (MSE for continuous, cross-entropy for binary). Variants: denoising AE (input is corrupted x), sparse AE (L1 on z), VAE (variational, probabilistic latent), contractive AE.
- **Python**: PyTorch or Keras (`tensorflow.keras.layers`). No core sklearn class. (`sklearn.neural_network.MLPRegressor` can be coerced, but a custom model is standard.)
- **Hyperparameters**: bottleneck size, architecture depth/width, activations, optimiser, learning rate, regularisation, denoising noise level.
- **Caveats**: needs more data and tuning than PCA; latent space not orthogonal; risk of overfitting.

### 4.24 Isolation Forest **[supplementary, anomaly]**

- **When**: anomaly detection in tabular data; fast, scalable.
- **Algorithm**: build random binary trees by recursive random feature × random split; anomalies have shorter average path length to a leaf because they isolate quickly.
- **Python**: `from sklearn.ensemble import IsolationForest`.
- **Hyperparameters**: `n_estimators`, `contamination`, `max_samples`, `max_features`, `random_state`.
- **Caveats**: contamination must be set; high cardinality features can dominate splits; doesn't model local density.

### 4.25 Local Outlier Factor (LOF) **[supplementary, anomaly]**

- **When**: density-based outlier scoring; finds points that are in much lower-density regions than their neighbours.
- **Python**: `from sklearn.neighbors import LocalOutlierFactor`.
- **Hyperparameters**: `n_neighbors`, `contamination`, `novelty`, `metric`.
- **Caveats**: by default doesn't support `predict` on new data unless `novelty=True`; sensitive to k.

### 4.26 One-Class SVM **[supplementary, anomaly]**

- **When**: model the "normal" region and flag outliers; works in high-D via kernel trick.
- **Python**: `from sklearn.svm import OneClassSVM`.
- **Hyperparameters**: `kernel`, `gamma`, `nu` (upper bound on training outliers).
- **Caveats**: sensitive to nu and gamma; O(n²) or worse; assumes one "normal" class.

### 4.27 Apriori — Association Rule Mining **[in lecture]**

- **When**: market-basket / itemset data, want rules of the form X ⇒ Y.
- **Definitions** (slide):
  - **Transaction**: an unordered set of items.
  - **Support(X)** = (# transactions containing itemset X) / (total # transactions). Probability a random transaction contains X.
  - **Confidence(X ⇒ Y)** = support(X ∪ Y) / support(X). Probability of Y given X.
  - **Lift(X ⇒ Y)** = support(X ∪ Y) / (support(X) × support(Y)). >1 means X and Y co-occur more than chance.
- **Algorithm (Apriori)**: monotonic-pruning generation of frequent itemsets in increasing size — any subset of a frequent itemset is itself frequent, so candidates whose subsets are infrequent can be dropped. Then for every frequent itemset enumerate rules X ⇒ Y satisfying the confidence threshold.
- **Python**: not in core sklearn. Use `mlxtend.frequent_patterns` (`apriori`, `association_rules`) or `efficient-apriori`. R analogue (lecture): `arules::apriori(bookbaskets_use, parameter=list(support=0.002, confidence=0.75))`.
- **Hyperparameters**: `min_support`, `min_confidence`, `max_len`.
- **Lecture-specific bookkeeping**: `interestMeasure(rules, measure=c("coverage", "fishersExactTest"))` where coverage = support of the LHS, Fisher's exact test = formal significance for the rule's co-occurrence. The slide uses these alongside lift.
- **Caveats**: combinatorial explosion of candidate rules; many "rules" are spurious without lift / Fisher; for sparse data thresholds must be set low (book example: support=0.002).

---

## 5. Cluster validity metrics — comprehensive

### 5.1 Internal (no ground-truth labels needed)

- **Inertia / WSS (total within-cluster sum of squares)** — sklearn `KMeans.inertia_`. Monotonically decreases with K; use elbow heuristic on inertia vs K to spot the diminishing-returns kink.
- **Elbow method** — plot inertia (or scaled WSS) against K; pick K where the curve bends. The lecture explicitly contrasts this with CH on the protein data.
- **Calinski–Harabasz index** — sklearn `sklearn.metrics.calinski_harabasz_score(X, labels)`. Higher is better. Maximised K is the candidate optimum. Slide formula: `B/W = (BSS/(k−1)) / (WSS/(n−k))`.
- **Davies–Bouldin index (DBI)** — sklearn `sklearn.metrics.davies_bouldin_score(X, labels)`. Average ratio of within-cluster scatter to between-cluster separation, summed over the worst pairing for each cluster. **Lower** is better (down to 0).
- **Silhouette score** — sklearn `sklearn.metrics.silhouette_score(X, labels)` (mean over all points) and `silhouette_samples` (per point). Range −1..1, higher better. Lecture covers in depth; visualised with `silhouette_visualizer` from `yellowbrick`.
- **Gap statistic** — Tibshirani et al. (2001). Compare log(WSS_k) on the real data with the expected log(WSS_k) under a reference null distribution (uniform over the bounding box of the data); pick the smallest K where Gap(K) ≥ Gap(K+1) − s_{K+1}. Not in core sklearn; available in `gap-statistic` package or hand-coded.
- **Dunn index** — ratio of minimum inter-cluster distance to maximum intra-cluster diameter; higher better.
- **Bayesian/Akaike Information Criterion (BIC/AIC)** — for probabilistic models (GMM); penalised log-likelihood; lower better.

### 5.2 External (require ground-truth labels)

- **Adjusted Rand Index (ARI)** — `sklearn.metrics.adjusted_rand_score`. Compares two partitions correcting for chance. Range up to 1; 0 = chance.
- **Normalised Mutual Information (NMI)** — `sklearn.metrics.normalized_mutual_info_score`. Mutual information between true and predicted labels, normalised.
- **Adjusted Mutual Information (AMI)** — chance-corrected NMI; preferred when comparing across different K.
- **Fowlkes–Mallows score** — `sklearn.metrics.fowlkes_mallows_score`. Geometric mean of precision and recall on pair co-membership.
- **V-measure** — harmonic mean of homogeneity and completeness.
- **Contingency / confusion matrix** — `sklearn.metrics.cluster.contingency_matrix`.

### 5.3 Stability (lecture's principal "is this real?" tool)

- **Jaccard via bootstrap (`clusterboot`)** — lecture's gold standard. Bootstrap many times, match clusters across bootstraps, take mean Jaccard. Thresholds: ≤0.6 unstable, 0.6–0.75 pattern present but uncertain, ≥0.85 highly stable.
- **Cross-validation-style consensus clustering** — split data, cluster each split, measure agreement.
- **Perturbation tests** — add small Gaussian noise and check label flip rate.

### 5.4 Choosing K — a practical recipe (combine multiple)

1. Run K-means / hclust at K = 2 ... K_max.
2. Plot inertia (elbow), silhouette, CH, DBI together (lecture does the first two as scaled overlay in `ggplot`).
3. Run `clusterboot` at the candidate K (or 2–3 candidates) and require Jaccard ≥ 0.75.
4. Cross-check with PCA/UMAP scatter plots coloured by labels: do the clusters look separable visually?
5. Interpret: do clusters mean anything substantive in domain terms?

---

## 6. Code snippets (paraphrased; lecture R code translated to sklearn-friendly forms)

### 6.1 Lecture's hierarchical workflow on the protein dataset (R)
```R
# load
protein <- read.table("protein.txt", sep="\t", header=TRUE)
# scale (always!)
vars.to.use <- colnames(protein)[-1]
pmatrix <- scale(protein[, vars.to.use])
# distance + linkage
d <- dist(pmatrix, method="euclidean")
pfit <- hclust(d, method="complete")
plot(pfit, labels=protein$Country)
rect.hclust(pfit, k=5)
groups <- cutree(pfit, k=5)
```
Equivalent in Python:
```python
import pandas as pd
from sklearn.preprocessing import StandardScaler
from scipy.cluster.hierarchy import linkage, fcluster, dendrogram
import matplotlib.pyplot as plt

X = StandardScaler().fit_transform(protein[vars_to_use])
Z = linkage(X, method="complete", metric="euclidean")
plt.figure(figsize=(10,5)); dendrogram(Z, labels=protein["Country"].values); plt.show()
labels = fcluster(Z, t=5, criterion="maxclust")
```

### 6.2 Lecture's k-means with multiple restarts (R)
```R
library(fpc)
kbest.p <- 5
set.seed(3)
pclusters <- kmeans(pmatrix, kbest.p, nstart=100, iter.max=100)
pclusters$tot.withinss
```
Equivalent in Python:
```python
from sklearn.cluster import KMeans
km = KMeans(n_clusters=5, n_init=100, max_iter=100, random_state=3).fit(X)
km.inertia_  # tot.withinss
```

### 6.3 Lecture's WSS and Calinski–Harabasz helpers (R, `WSS.R`, `CH.R`)
```R
sqr_edist <- function(x, y) sum((x - y)^2)
wss.cluster <- function(M) { c0 <- apply(M, 2, mean); sum(apply(M, 1, function(r) sqr_edist(r, c0))) }
wss.total   <- function(M, labels) sum(sapply(unique(labels), function(i) wss.cluster(subset(M, labels==i))))
totss       <- function(M) { g <- apply(M, 2, mean); sum(apply(M, 1, function(r) sqr_edist(r, g))) }
# CH index loop
ch_criterion <- function(M, kmax, method="kmeans") {
  npts <- nrow(M); tss <- totss(M); wss <- numeric(kmax)
  wss[1] <- (npts-1) * sum(apply(M, 2, var))
  for (k in 2:kmax) {
    if (method=="kmeans") {
      cl <- kmeans(M, k, nstart=10, iter.max=100); wss[k] <- cl$tot.withinss
    } else {
      d  <- dist(M, method="euclidean"); pf <- hclust(d, method="ward")
      wss[k] <- wss.total(M, cutree(pf, k=k))
    }
  }
  bss <- tss - wss
  list(crit = (bss/(0:(kmax-1))) / (wss/(npts - 1:kmax)), wss = wss, totss = tss)
}
```
Equivalent in Python:
```python
from sklearn.metrics import calinski_harabasz_score, silhouette_score
ch = [calinski_harabasz_score(X, KMeans(k, n_init=10).fit_predict(X)) for k in range(2, 11)]
```

### 6.4 Lecture's silhouette-driven K selection via `fpc::kmeansruns` (R)
```R
clustering.ch  <- kmeansruns(pmatrix, krange=1:10, criterion="ch")
clustering.asw <- kmeansruns(pmatrix, krange=1:10, criterion="asw")  # asw = avg silhouette width
clustering.ch$bestk
```
Equivalent in Python:
```python
from sklearn.metrics import silhouette_score
ks = range(2, 11)
sil = [silhouette_score(X, KMeans(k, n_init=10, random_state=42).fit_predict(X)) for k in ks]
best_k_silhouette = ks[int(np.argmax(sil))]
```

### 6.5 Lecture's `clusterboot` Jaccard stability (R)
```R
library(fpc)
# hierarchical
cboot.hclust <- clusterboot(pmatrix, clustermethod=hclustCBI, method="ward.D", k=5)
cboot.hclust$bootmean   # mean Jaccard per cluster
cboot.hclust$bootbrd    # # of bootstraps in which the cluster dissolved (max Jaccard < 0.5)
# k-means
cboot.km <- clusterboot(pmatrix, clustermethod=kmeansCBI, runs=100, krange=5, seed=15555)
```
Python sketch:
```python
import numpy as np
from sklearn.cluster import KMeans
def jaccard(A, B): return len(A & B) / len(A | B)
def cluster_stability(X, n_clusters, n_boot=100, seed=0):
    rng = np.random.default_rng(seed); n = len(X)
    base = KMeans(n_clusters, n_init=10, random_state=seed).fit_predict(X)
    base_sets = [set(np.where(base==k)[0]) for k in range(n_clusters)]
    stab = np.zeros(n_clusters)
    for b in range(n_boot):
        idx  = rng.integers(0, n, size=n)
        labb = KMeans(n_clusters, n_init=10, random_state=b).fit_predict(X[idx])
        boot_sets = [set(idx[labb==k]) for k in range(n_clusters)]
        for k, A in enumerate(base_sets):
            stab[k] += max(jaccard(A, B) for B in boot_sets)
    return stab / n_boot
```

### 6.6 Lecture's association-rule code (R, book dataset)
```R
library(arules)
bookbaskets <- read.transactions("bookdata.tsv.gz", format="single", sep="\t",
                                 cols=c("userid","title"), rm.duplicates=TRUE, header=TRUE)
bookbaskets_use <- bookbaskets[size(bookbaskets) > 1]
rules <- apriori(bookbaskets_use,
                 parameter=list(support=0.002, confidence=0.75))
measures <- interestMeasure(rules, measure=c("coverage","fishersExactTest"),
                            transactions=bookbaskets_use)
inspect(head(sort(rules, by="confidence"), n=5))
# Restricted: rules whose RHS is a specific title
brules <- apriori(bookbaskets_use, parameter=list(support=0.001, confidence=0.6),
                  appearance=list(rhs=c("The Lovely Bones: A Novel"), default="lhs"))
```
Python equivalent:
```python
from mlxtend.frequent_patterns import apriori, association_rules
freq = apriori(basket_df, min_support=0.002, use_colnames=True)
rules = association_rules(freq, metric="confidence", min_threshold=0.75)
rules.sort_values("lift", ascending=False).head()
```

### 6.7 Visualising clusters by PCA (lecture)
```R
princ   <- prcomp(pmatrix); nComp <- 4
project <- predict(princ, newdata=pmatrix)[, 1:nComp]
project.plus <- cbind(as.data.frame(project), cluster=as.factor(groups), country=protein$Country)
ggplot(project.plus, aes(x=PC3, y=PC4)) + geom_point(aes(shape=cluster)) +
  geom_text(aes(label=country), hjust=0, vjust=1)
```
Python:
```python
from sklearn.decomposition import PCA
import seaborn as sns
P = PCA(n_components=4).fit_transform(X)
sns.scatterplot(x=P[:,2], y=P[:,3], hue=labels, style=labels)
```

---

## 7. Notable examples / datasets used in the lecture

- **European Protein Consumption (1973, 25 countries × 9 food groups)** — the running example for hierarchical clustering and k-means. Goal: group countries by patterns in protein source (red meat, white meat, eggs, milk, fish, cereals, starch, nuts, fruits/vegetables). Demonstrates that scaling is critical and that K=5 yields interpretable Mediterranean, Eastern European, Nordic, etc. groupings. Used to demonstrate `hclust`, `kmeans`, `WSS`, `CH`, `clusterboot`, PCA visualisation.
- **Book-Crossing dataset (2004, Institut für Informatik, U. Freiburg)** — book transactions per user; the running example for `arules::apriori`. Demonstrates support, confidence, lift, the long-tail rarity problem (most books have very low support), Fisher's exact test on rules, and restricted-RHS search ("which left-hand sides imply The Lovely Bones?").
- **Synthetic two-dimensional Gaussian blobs** — used in slides to illustrate the k-means iteration loop and the effect of multiple `nstart` runs (the same K with different initialisations can converge to different local optima with different WSS).
- **Synthetic correlation example** — `x <- matrix(rnorm(30*3), ncol=3); dd <- as.dist(1 - cor(t(x))); hclust(dd, method="complete")` — illustrates clustering on correlation distance.

---

## 8. Pitfalls and gotchas

### 8.1 Scaling — the biggest lever
- Lecture emphasises: "different units cause different distances and potentially different clusterings." A variable measured in grams versus kilograms will dominate or be ignored depending on the unit. Default fix: `scale()` / `StandardScaler` to mean 0, sd 1 per column. Save the centre and scale so you can apply the same transform to new data (lecture's `pcenter`, `pscale`).
- Robust alternative: `RobustScaler` (median + IQR) when outliers exist; `QuantileTransformer` when distributions are heavily skewed.
- For mixed numeric+categorical data, use Gower distance + K-Medoids, or one-hot encode then scale (cautiously — high-cardinality one-hot can dominate distance).

### 8.2 Distance metric choice
- Euclidean is the default but assumes equal scale and independence between features. After standardisation it is reasonable; Mahalanobis distance (which accounts for covariance) is in principle better but requires estimating Σ and inverting it.
- Cosine distance ignores magnitude — good when proportion / direction matters (text, normalised box scores), bad when total magnitude is itself meaningful (a 10–0 game versus 1–0).
- Correlation distance treats two observations as similar if their feature *pattern* moves together — useful when you care about the *shape* of a feature vector but not its level.
- For categorical/binary features: Hamming, Jaccard, Dice.

### 8.3 The k-pickin' problem
- Different metrics (elbow / silhouette / CH / DBI / gap / stability) often disagree. Lecture's recommendation: try several, plot them together (scaled), choose K that is justified by at least two and is interpretable.
- Silhouette favours well-separated convex blobs; can punish density-based clusterings that DBSCAN considers correct.
- Inertia/WSS will always decrease as K grows (down to 0 at K=n), so it alone cannot pick K.

### 8.4 Initialisation sensitivity
- K-means depends on initial centroids. Lecture: "fairly unstable — the final clusters depend on the initial cluster centers." Run with `nstart` (R) or `n_init` (Python) ≥ 20. Use `k-means++` initialisation by default in sklearn.
- Hierarchical clustering is deterministic given input and metric, but the merge order is greedy and not undoable — a bad early merge propagates.

### 8.5 Outlier sensitivity
- K-means is squared-distance-based, so a few outliers can drag centroids dramatically. K-medoids, density methods (DBSCAN/HDBSCAN), and trimmed K-means are more robust.

### 8.6 Single-linkage chaining
- Single linkage links via nearest-pair minimum, which produces "chains" of points connected by long thin bridges — clusters become string-like and uninterpretable. Prefer complete / average / Ward for general use.

### 8.7 Cluster shape assumptions
- K-means assumes roughly spherical, equal-variance clusters. Ward linkage too.
- Spectral clustering, DBSCAN, HDBSCAN handle arbitrary shapes.
- GMM with full covariance handles ellipsoidal clusters but needs more data per component.

### 8.8 Curse of dimensionality
- All distances tend toward equality in high D, so neighbour-based methods (DBSCAN, k-NN) lose discriminative power. Mitigations: PCA / UMAP / autoencoder to reduce dimensions before clustering, or use kernel methods.

### 8.9 Interpreting clusters
- Cluster ID is just a label. Always describe clusters by their **centroid feature values** (lecture: `pclusters$centers`, `print_clusters(groups, k)` printing key columns per cluster). Eyeball the top distinguishing features for each cluster.
- The number-of-clusters answer is rarely unique; report findings with caveats and stability scores.

### 8.10 Validation traps
- Validating clustering with a hold-out metric is hard because there is no ground truth. Use Jaccard / `clusterboot` for stability, and downstream task performance (e.g. cluster as a feature in a supervised model) as one external test.
- Silhouette/CH/DBI are *internal* — they say the partition looks tight, not that it means anything.

### 8.11 Association-rule pitfalls
- With many possible items most rules will have very low support — set thresholds carefully. Lecture used `support=0.002` for the books because of long-tail rarity.
- High confidence ≠ interesting. A rule "if X then Y" with confidence 0.9 might just reflect that Y is bought in 90% of all transactions (huge prior). **Use lift > 1** (and ideally Fisher's exact test) to filter for genuinely non-random co-occurrence.
- Apriori is combinatorial. Restrict by RHS / LHS (lecture's `appearance=list(rhs=...)`) when you have a target question.

---

## 9. Cross-references

- **Topic 05-1 PCA / SVD** — PCA is used in this topic for *visualising* high-dimensional clusters on PC1/PC2 (or PC3/PC4 as the lecture does). PCA and clustering are commonly chained: scale → PCA → KMeans on PC scores.
- **Topic 05-2 Feature explanation / feature reduction** — clustering is itself a form of feature engineering (cluster ID as a categorical feature) and is a precursor to supervised modelling.
- **Visualisation topic** — dendrogram, silhouette plot, scree plot, biplot, t-SNE / UMAP map; lecture explicitly uses `ggplot2` for cluster + PC overlays.
- **Supervised modelling topics** — Senior Wang's consensus features list is the **predictive** lens; this topic provides the **descriptive** lens. The two should be compared at the end of the notebook.
- **EDA topic** — descriptive stats and EDA must precede clustering: distributional checks, missingness, collinearity, scaling decisions.
- **Anomaly detection** — Isolation Forest / LOF / One-Class SVM build on the same density / distance intuition as DBSCAN.
- **Association rule mining** — sister technique for co-occurrence rather than similarity; not used heavily in CPBL unless we redefine "transactions" (e.g. pitches in an at-bat).

---

## 10. Relevance to CPBL — detailed game plan

The CPBL final project pipeline is: **preprocess 2023+2024 raw JSON → descriptive stats → EDA → unsupervised feature discovery → (supervised modelling, downstream)**. This topic is *the* core of the unsupervised step. The plan below assigns concrete methods to concrete levels of the data and ties the discovered structure back to Senior Wang's consensus features.

1. **Pre-cluster sanity on team-game rows (the principal table).** Before any clustering, build a per-team-per-game feature matrix combining offence (H, AB, R, scored_first, run_per_hit, middle_runs, late_runs) and pitching (IP, hits_allowed, hr_allowed, whip_like). Standardise with `StandardScaler`. Confirm no leakage of the supervised label (win/loss) into the clustering inputs.

2. **PCA first, always.** Run `PCA(n_components='mle')` or look at the cumulative explained variance curve. If 2 PCs explain ≥60%, plot a scatter. Inspect loadings: if PC1 is dominated by `run_per_hit` and `scored_first` and `H`, that is independent confirmation of Wang's top features.

3. **K-means with K = 3..8 on the scaled team-game matrix.** For each K compute inertia (elbow), silhouette, Calinski–Harabasz, Davies–Bouldin. Overlay these on a single plot (the lecture's pattern). Pick 2 candidate K values. Use `KMeans(n_init=50, random_state=...)` for stability.

4. **Hierarchical (Ward) clustering as a cross-check.** Build a dendrogram from a small (e.g. 200-row) sample because n² gets expensive. Cut at the same K used by k-means. Compare partitions via Adjusted Rand Index — if k-means and Ward agree well, the partition is robust.

5. **Cluster stability via bootstrap Jaccard (`clusterboot` equivalent).** Run the snippet from §6.5 with 100 bootstraps on each cluster. Report the mean Jaccard per cluster. Only accept clusters with stability ≥ 0.75 as "real game archetypes".

6. **Interpret clusters in baseball terms.** For each cluster compute mean and std of each input feature (the centroid). Expected archetypes to look for: *Blowout wins* (high `run_per_hit`, high `scored_first`, low `hits_allowed`), *Pitcher's duels* (low total runs, high IP, low `whip_like`), *Comeback wins* (low `scored_first` but high `late_runs`), *Long-relief failures* (high `middle_runs` against, high `hits_allowed`). If these emerge unprompted, that is unsupervised confirmation of Wang's features.

7. **DBSCAN / HDBSCAN to find outlier games.** Apply with conservative parameters (`min_samples=10`, ε tuned by k-distance plot). Label noise points as "atypical games" — perfect games, walk-offs, no-hitters — and compare 2023 vs 2024 counts. This is anomaly detection without needing labels.

8. **Gaussian Mixture Model as a soft cluster alternative.** `GaussianMixture(n_components=K, covariance_type='full')` gives each game a probability distribution over K archetypes. Use AIC/BIC to choose K. Soft membership is useful as a feature for later supervised models (replace hard cluster ID with K probabilities). Probably preferable to k-means for downstream modelling.

9. **Compare 2023 vs 2024 cluster structure.** Two routes: (a) fit the clustering on combined data, then look at the season composition of each cluster — has any archetype's frequency shifted year-over-year? (b) fit independently per season and use Hungarian matching to align clusters across seasons. Report cluster-frequency deltas. Look for changes that map to known rule changes (pitch clock, etc.) in 2024.

10. **Per-player-season profile clustering.** Build a separate table: one row per (player, season), columns are season-aggregated rate stats. Apply K-means (K=4..8) and hierarchical Ward. Expected pitcher clusters: power-strikeout starters, soft-contact starters, high-WHIP relievers, closers. Expected hitter clusters: leadoff/contact, slugger, all-rounder, slap-and-run, struggling. Show which Wang features (e.g. `whip_like`, `hr_allowed`, `hits_allowed`) drive the pitcher partition.

11. **Per-inning behavioural clustering.** Build a table indexed by (game, half-inning) with features like `pitches_thrown`, `runs_scored_this_inning`, `walks_this_inning`, `Ks_this_inning`, `is_middle`, `is_late`. Cluster — clusters should correspond to "1-2-3 inning", "long inning with runners stranded", "scoring rally", "blow-up inning". Tie back to `middle_runs` and `late_runs` consensus features by checking which clusters dominate the middle (innings 4–6) vs late (innings 7+).

12. **Dimensionality-reduction visualisation: t-SNE and UMAP.** After choosing a clustering, project the standardised feature matrix to 2D with both. Colour points by cluster ID; t-SNE shows tight local groupings, UMAP shows global structure. If clusters are visually separable in 2D, the partition is credible. *Do not* use the t-SNE coords as features for downstream modelling — t-SNE distances are non-metric. UMAP coords are acceptable if `random_state` is fixed.

13. **PCA-loadings → feature recommendation.** Inspect the top-3 PCs' loadings. Pick the features with absolute loading > 0.3 across PCs that explain >70% of variance. Cross-tabulate this PCA-discovered shortlist with Wang's supervised list. Overlap = corroborated features; PCA-only = candidate features that supervised methods missed; Wang-only = features whose predictive power doesn't show up as variance (these are good Bayesian-interaction candidates).

14. **Anomaly detection layer.** Run `IsolationForest(contamination=0.02)` on the team-game matrix. The 2% most anomalous games should be either statistically unusual (no-hitter, 20-run game) or data-quality problems. Inspect a handful manually; this doubles as a sanity check on the preprocessor.

15. **Cluster ID as a downstream feature for supervised models.** Once stable clusters are accepted, append a `game_archetype` column to the supervised training set. Fit a logistic regression / random forest with and without `game_archetype`. If AUC improves materially, unsupervised step has produced a useful engineered feature — strong narrative for the report.

16. **Reporting checklist.** For each clustering result include: (a) the scaling used, (b) the K chosen and the validity metrics behind it, (c) the bootstrap-Jaccard stability scores, (d) a centroid table showing the feature means per cluster, (e) a t-SNE/UMAP figure coloured by cluster, (f) a one-sentence baseball interpretation, (g) a side-by-side 2023 vs 2024 frequency table. This template lets us slot in any K and any algorithm without reinventing the analysis structure.

17. **Association rules as an optional extension.** Define a "transaction" as the set of binary descriptors of one half-inning: `{lead_off_walk, double, HR, error, two_out_rally, scored_run}`. Run Apriori (via `mlxtend`) with low support (≈ 0.01) and confidence ≥ 0.6, filter by lift > 1.5. Discovered rules might read "lead_off_walk AND error ⇒ scored_run (lift 2.1)". This is a baseball-narrative-friendly output that pairs well with cluster archetypes.

18. **Tie back to Wang's consensus list, explicitly.** Maintain a small comparison table in the report:

| Wang feature       | Appears in top-3 PCA loadings? | Drives any cluster centroid? | Drives anomaly detection? |
|--------------------|--------------------------------|------------------------------|---------------------------|
| run_per_hit        |  yes/no                        |  yes/no                      |  yes/no                   |
| innings_pitched    |  ...                           |  ...                         |  ...                      |
| H                  |  ...                           |  ...                         |  ...                      |
| scored_first       |  ...                           |  ...                         |  ...                      |
| whip_like          |  ...                           |  ...                         |  ...                      |
| hr_allowed         |  ...                           |  ...                         |  ...                      |
| hits_allowed       |  ...                           |  ...                         |  ...                      |
| AB                 |  ...                           |  ...                         |  ...                      |
| middle_runs        |  ...                           |  ...                         |  ...                      |
| late_runs          |  ...                           |  ...                         |  ...                      |

The yes/no entries will be filled in directly from the notebook. Strong corroboration (lots of yeses) is the headline result; mismatches highlight directions where unsupervised methods extend the supervised story.

---

## Appendix: master sklearn-import cheat sheet

```python
# clustering
from sklearn.cluster import KMeans, MiniBatchKMeans, AgglomerativeClustering, \
                            DBSCAN, OPTICS, HDBSCAN, SpectralClustering, \
                            AffinityPropagation, MeanShift, Birch
from sklearn_extra.cluster import KMedoids  # extra package

# mixture / probabilistic
from sklearn.mixture import GaussianMixture, BayesianGaussianMixture

# dimensionality reduction
from sklearn.decomposition import PCA, KernelPCA, FastICA, NMF, TruncatedSVD
from sklearn.manifold     import TSNE, MDS, Isomap, LocallyLinearEmbedding, SpectralEmbedding
import umap

# anomaly
from sklearn.ensemble  import IsolationForest
from sklearn.neighbors import LocalOutlierFactor
from sklearn.svm       import OneClassSVM
from sklearn.covariance import EllipticEnvelope

# validity metrics
from sklearn.metrics import silhouette_score, silhouette_samples, \
                            calinski_harabasz_score, davies_bouldin_score, \
                            adjusted_rand_score, normalized_mutual_info_score, \
                            adjusted_mutual_info_score, fowlkes_mallows_score

# scaling
from sklearn.preprocessing import StandardScaler, RobustScaler, QuantileTransformer, MinMaxScaler

# association rules
from mlxtend.frequent_patterns import apriori, association_rules
```

---

## Appendix: glossary in CPBL-language

- **Cluster** — a group of CPBL games (or players, or innings) that resemble each other across many box-score features.
- **Centroid** — the average box-score profile of a cluster ("the typical pitcher's-duel game has 6.0 hits, 1.2 runs, 8.5 IP, ...").
- **Linkage** — when growing a dendrogram of games, the rule for measuring how far one growing subgroup is from another (single = closest pair, complete = farthest pair, Ward = squared-distance increase).
- **Inertia / WSS** — total "spread" inside clusters; lower is tighter.
- **Silhouette** — per-game score in −1..1 of whether a game fits its assigned cluster better than the nearest other cluster.
- **CH / Calinski–Harabasz** — ratio of between-cluster scatter to within-cluster scatter; higher is sharper.
- **Stability (Jaccard)** — how often the same set of games end up clustered together when we resample.
- **Support / confidence / lift** — for association rules of the form "if a half-inning has X then it also has Y": support is how often X∪Y happens, confidence is the conditional rate, lift is the conditional rate over the marginal rate (anything > 1 is interesting).
- **Anomaly** — a game whose box score doesn't look like any others (perfect game, 20-run game, blowout in either direction).
- **Game archetype** — a useful narrative label attached to a cluster (e.g. "comeback win", "pitcher's duel").
