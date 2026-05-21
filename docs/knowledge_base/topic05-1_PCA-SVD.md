# Topic 05-1: Principal Component Analysis (PCA) and Singular Value Decomposition (SVD)

## 1. Topic Summary

This topic introduces PCA and SVD as the two foundational linear methods for dimensionality reduction in unsupervised learning. PCA is described as "an effective method for reducing dataset dimensions while keeping spatial characteristics as much as possible." It is a linear transform with a solid mathematical foundation, used on unlabeled data, with applications ranging from line/plane fitting to face recognition.

The intuition is that PCA seeks a small number of new dimensions that are as "interesting" as possible, where "interesting" is defined as the amount the observations vary along each dimension. Each principal component (PC) is a linear combination of the original p features. SVD is presented as the more general matrix factorization that yields the same answer (and is in fact what most modern implementations, such as R's `prcomp` or sklearn's `PCA`, use internally).

For the CPBL final project, this material is highly relevant: after constructing per-game/per-team feature matrices from Senior Wang's top features (run_per_hit, innings_pitched, H, scored_first, whip_like, hr_allowed, hits_allowed, AB, middle_runs, late_runs), PCA/SVD lets us compress them into 2-3 components for visualization, deduplicate correlated offensive/pitching variables, and feed denoised coordinates into downstream clustering.

## 2. Outline / Section Structure

The lecture flows as follows:

1. Motivation: what PCA does and where it is used (unlabeled data, linear transform, applications).
2. Change of basis: Y = PX, with X an m x n matrix (m features, n points), P a linear transformation, Y the new representation.
3. Two enemies of a good basis: Noise (and Rotation) and Redundancy.
4. Measuring redundancy with the Covariance matrix C_X.
5. Goal of PCA: find an orthonormal P such that the new covariance C_Y = P C_X P^T is diagonal.
6. Linear-algebra refresher: scalar multiples, linear independence, orthogonal vectors, eigenvalues, eigenvectors.
7. Eigenvector decomposition for symmetric matrices: A = E D E^T, with E orthogonal eigenvectors and D diagonal of eigenvalues.
8. Solving PCA: set P = E^T (rows are eigenvectors of C_X); then C_Y = D.
9. Geometric interpretation: the first PC is the line in p-dimensional space closest (squared-Euclidean) to the n observations; the first M PC loadings/scores give the best M-dimensional approximation.
10. Summary of PCA: principal components = eigenvectors of C_X; ith diagonal of C_Y is variance along p_i; in practice subtract the mean and compute eigenvectors of C_X.
11. SVD: scalar form, matrix form, and the relationship between SVD factors and PCA.
12. SVD reduces dimensions from very high (e.g. 18,081 down to ~40 in the example noted).
13. Assumptions: linearity, large variances carry important structure, PCs are orthogonal.
14. Practical R demo with `prcomp` on iris and `USArrests`: log transform, center, scale, biplot, ellipse, correlation circle.
15. References (notably 線代啟示錄 by Prof. Chou, NCTU).

## 3. Key Concepts

- Principal component (PC). A new dimension that is a linear combination of the original p features, chosen so that variance of the data along it is maximized subject to orthogonality to earlier PCs.
- "Interesting" direction. Measured by the variance of the projected data; large variance is assumed to carry the structure of interest.
- Change of basis. Y = PX expresses the data in a new coordinate system; PCA chooses P so that the new coordinates are uncorrelated and ordered by variance.
- Covariance matrix C_X. Square symmetric matrix whose diagonal entries are per-feature variances and whose off-diagonal entries measure redundancy between feature pairs.
- Noise vs signal. Off-diagonal entries of C_X represent redundancy; PCA tries to diagonalize C_Y so redundancy is removed in the new basis.
- Eigenvalue / eigenvector. For a square matrix A, a vector v with Av = lambda v. PCA's eigenvectors of C_X are the principal directions; the eigenvalues are the variances along them.
- Orthogonal / orthonormal basis. Vectors are mutually perpendicular and unit length; the loadings of PCA form such a basis.
- Spectral / eigen decomposition. For any symmetric matrix A: A = E D E^T, where E has orthogonal eigenvectors as columns and D is diagonal of eigenvalues. C_X is symmetric, so this always applies.
- Singular value decomposition. Any real n x m matrix Y = U Sigma V^T where U and V are orthogonal and Sigma is diagonal of non-negative singular values. Squared singular values (divided by n - 1) equal the eigenvalues of the covariance matrix, linking SVD directly to PCA.
- Loadings vs scores. Loadings are the columns of V (or rotation matrix) telling how much each original feature contributes to each PC; scores are the projected coordinates of each observation.
- Proportion of Variance Explained (PVE). For PC i, lambda_i divided by sum of all eigenvalues; cumulative PVE drives how many components to keep.
- Biplot. Joint plot of scores (points) and loadings (arrows) in the first two PCs.
- Best M-dimensional approximation property. The first M PCs minimize average squared reconstruction error among all rank-M projections.
- Centering vs scaling. Centering shifts each column to mean zero; scaling additionally divides by standard deviation so each column has unit variance. Both are usually needed before PCA on mixed-unit data.
- Rotation matrix. R's `prcomp` calls the loading matrix `rotation`; sklearn calls it `components_`. Conceptually it is the orthogonal change-of-basis matrix from the original coordinates to the PC coordinates.
- Symmetric matrix theorems used in the derivation:
  - Theorem 1: a matrix is symmetric if and only if it is orthogonally diagonalizable.
  - Theorem 2: a symmetric matrix is diagonalized by a matrix of its orthogonal eigenvectors.
- Why diagonal C_Y is the goal. A diagonal covariance matrix means the new features are pairwise uncorrelated, so each PC carries an independent slice of variance and there is no redundancy left to remove.

## 4. Methods and Algorithms

### 4.1 PCA via eigendecomposition of the covariance matrix

- When. Small to moderate p (number of features); when the covariance matrix is well-conditioned and you want the cleanest mathematical interpretation.
- Math. Compute mean-centered X_c. Form C_X = (1 / (n - 1)) X_c X_c^T. Decompose C_X = E D E^T. Set P = E^T; scores Y = P X_c. The ith diagonal of D is the variance captured by PC i.
- Python. `from sklearn.decomposition import PCA; pca = PCA(n_components=k).fit(X_scaled)`. Loadings live in `pca.components_`; explained variance in `pca.explained_variance_` and `pca.explained_variance_ratio_`. sklearn internally uses SVD, not raw eigendecomposition, for numerical stability.
- Caveats. Requires mean centering. Sensitive to the scale of features, so standardize first if features have different units. Assumes linear structure; will miss curved manifolds.

### 4.2 PCA via SVD of the data matrix

- When. Default in modern libraries (`prcomp` in R, `PCA` in sklearn). Preferred when m or n is large or when C_X may be near-singular.
- Math. Center the data matrix X_c (rows = observations, columns = features). Compute X_c = U Sigma V^T. Columns of V are the principal loadings; PC scores are U Sigma (or equivalently X_c V). The variance along PC i equals sigma_i^2 / (n - 1).
- Python. `np.linalg.svd(X_centered, full_matrices=False)` for the raw factors; or just use `sklearn.decomposition.PCA` which wraps this.
- Caveats. Still requires centering (and usually scaling); standard SVD computes all components, which is wasteful when only a few are needed.

### 4.3 Truncated SVD

- When. Very high-dimensional or sparse data (e.g. text TF-IDF, large game-feature matrices) where you only need the top k components and cannot afford a full decomposition. Also works on sparse matrices without densifying.
- Math. Approximates X by U_k Sigma_k V_k^T, keeping only the top k singular triplets. Note: TruncatedSVD does not center the data, so when applied to dense numerical data after standardization it behaves like PCA, but on raw sparse data it differs from PCA (this is the "LSA" use case).
- Python. `from sklearn.decomposition import TruncatedSVD; svd = TruncatedSVD(n_components=k).fit_transform(X_sparse)`.
- Caveats. Without centering, the first component may simply capture the data mean direction. Choose k via cumulative `explained_variance_ratio_`.

### 4.4 Kernel PCA (mentioned conceptually as extension)

- When. Non-linear structure where straight PCA fails (e.g. concentric clusters of game styles).
- Math. Implicitly maps X to a higher-dimensional feature space through a kernel k(x, y) (e.g. RBF, polynomial), then runs PCA on the centered Gram matrix K.
- Python. `from sklearn.decomposition import KernelPCA; kpca = KernelPCA(n_components=k, kernel='rbf', gamma=gamma)`.
- Caveats. O(n^2) memory, no direct loadings in original feature space, choice of kernel/gamma matters a lot, and inverse transform is approximate.

### 4.5 Eigenvalue / eigenvector solve (linear-algebra building block)

- When. As a primitive inside PCA, or to inspect the spectrum of a small covariance matrix manually.
- Math. Solve det(A - lambda I) = 0 for eigenvalues; back-substitute to get eigenvectors. For symmetric A, eigenvectors can be chosen orthonormal.
- Python. `np.linalg.eigh(cov_matrix)` (use `eigh` rather than `eig` for symmetric matrices; it is more accurate and returns sorted real eigenvalues).
- Caveats. Numerically less stable than SVD on the data matrix when the covariance is near-singular.

## 5. Code Snippets

The slide deck uses R's `prcomp`. I include the original R snippets verbatim, then provide the Python equivalents we will actually use in the notebook.

### 5.1 R verbatim (from the slides)

```r
# Load data
data(iris)
head(iris, 3)

# log transform
log.ir <- log(iris[, 1:4])
ir.species <- iris[, 5]

# apply PCA - scale. = TRUE is highly advisable, but default is FALSE.
ir.pca <- prcomp(log.ir, center = TRUE, scale. = TRUE)

# summary method
summary(ir.pca)
# plot method
plot(ir.pca, type = "l")

# biplot using ggbiplot
library(ggbiplot)
g <- ggbiplot(ir.pca, obs.scale = 1, var.scale = 1, groups = ir.species)
g <- g + scale_color_discrete(name = '')
g <- g + theme(legend.direction = 'horizontal', legend.position = 'top')
print(g)

# with confidence ellipse + correlation circle
g <- ggbiplot(ir.pca, obs.scale = 1, var.scale = 1, groups = ir.species,
              ellipse = TRUE, circle = TRUE)

# Predict PCs
predict(ir.pca, newdata = tail(log.ir, 2))
```

Key R outputs noted in the slides:

```text
> ir.pca$rotation
                    PC1         PC2        PC3         PC4
Sepal.Length  0.5038236 -0.45499872  0.7088547  0.19147575
Sepal.Width  -0.3023682 -0.88914419 -0.3311628 -0.09125405
Petal.Length  0.5767881 -0.03378802 -0.2192793 -0.78618732
Petal.Width   0.5674952 -0.03545628 -0.5829003  0.58044745

sum(ir.pca$rotation[1, ] * ir.pca$rotation[1, ]) == 1
```

The slides also point out the variances in USArrests (Murder 18.97, Rape 87.73, Assault 6945.16, UrbanPop 209.5) to motivate `scale. = TRUE`.

### 5.2 Python equivalents we will use in the CPBL notebook

```python
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA, TruncatedSVD

# X is a DataFrame of per-game features for Senior Wang's top list.
features = ['run_per_hit', 'innings_pitched', 'H', 'scored_first',
            'whip_like', 'hr_allowed', 'hits_allowed', 'AB',
            'middle_runs', 'late_runs']
X = games_df[features].to_numpy()

# 1. Standardize: PCA is scale-sensitive.
scaler = StandardScaler()
X_std = scaler.fit_transform(X)

# 2. Fit PCA (keep all components first to inspect the spectrum).
pca = PCA(n_components=None, svd_solver='full', random_state=0)
scores = pca.fit_transform(X_std)

# 3. Inspect variance explained.
ratio = pca.explained_variance_ratio_
cum = np.cumsum(ratio)
print(pd.DataFrame({'PVE': ratio, 'cumPVE': cum},
                   index=[f'PC{i+1}' for i in range(len(ratio))]))

# 4. Loadings table (columns = original features, rows = PCs).
loadings = pd.DataFrame(
    pca.components_,
    columns=features,
    index=[f'PC{i+1}' for i in range(pca.n_components_)],
)

# 5. Predict (project) new games onto the trained basis.
new_scores = pca.transform(scaler.transform(new_games[features]))
```

For sparse or very wide intermediate feature matrices (e.g. one-hot encoded play-by-play counts), the analogous TruncatedSVD call is:

```python
svd = TruncatedSVD(n_components=10, random_state=0)
scores_sparse = svd.fit_transform(X_sparse_csr)
print(svd.explained_variance_ratio_.cumsum())
```

## 6. Notable Examples / Datasets

- iris (the running example in the slides). Four features (Sepal.Length, Sepal.Width, Petal.Length, Petal.Width) reduced to PC1-PC4. After log transform and scaling, PC1 alone captures most of the spread between species; the biplot shows petal-related features dominating PC1 and Sepal.Width dominating PC2.
- USArrests. n = 50 states, p = 4 features (Murder, Assault, Rape, UrbanPop). The slides highlight that without scaling, the wildly different variances (Assault 6945 vs Murder 19) would make PC1 essentially "Assault axis". This motivates `scale. = TRUE` and standardization in sklearn.
- Face recognition. Cited as a classical application: an image with 18,081 pixels is compressed by SVD down to roughly 40 components ("eigenfaces"), illustrating the rank-reduction power of SVD on high-dimensional data.
- The slides reference 線代啟示錄 (Prof. Chou Chih-Cheng, NCTU) at https://ccjou.wordpress.com/ for deeper linear-algebra background.

## 7. Pitfalls

- Failing to center. PCA is defined on mean-centered data. Without centering, the first PC just chases the mean and the geometry breaks. sklearn's `PCA` centers automatically; `TruncatedSVD` does not.
- Failing to scale when features have different units. Variables with large variance dominate the PCs regardless of whether they are meaningful (USArrests example). Use StandardScaler before PCA.
- Treating PCs as features with intrinsic meaning. PCs are linear combinations; interpreting them requires inspecting loadings. Sign flips between runs of SVD are arbitrary and have no meaning.
- Assuming PCA captures classes. PCA is unsupervised; the direction of maximum variance is not necessarily the direction that separates labels.
- Linear-only assumption. PCA cannot uncover non-linear manifolds. If the structure curves (e.g. game-pace patterns over innings), consider kernel PCA, t-SNE, or UMAP.
- Forgetting that PVE is computed on the training distribution. New data projected with `transform` may not preserve the same explained-variance proportions.
- Outliers move PCs. Because variance is sensitive to extremes, a single blowout game can rotate PCs noticeably; consider robust alternatives or winsorization.
- SVD on a wide matrix is expensive. For very wide data, use TruncatedSVD or randomized SVD (`svd_solver='randomized'` in sklearn) instead of the full decomposition.
- Number-of-components choice. Eyeballing the scree plot (`plot(ir.pca, type = "l")` in R, or `np.cumsum(pca.explained_variance_ratio_)` in Python) is standard; common targets are 80-95 percent cumulative variance.

## 8. Cross-references

- Topic 05 feature reduction (parent topic): PCA/SVD sits alongside variance-threshold filters, correlation-based pruning, and supervised wrappers (RFE) as one family of dimensionality-reduction tools.
- Topic 05-2 feature explanation: loadings (`pca.components_`) feed directly into the feature-importance / explainability narrative. We can describe PC1 as "an offense intensity axis loaded on H, AB, run_per_hit".
- Topic 06 visualization: 2-D PCA scatter and biplots are core visualization workflows for unlabeled data.
- Topic 08 unsupervised: PCA is often a pre-processing step before k-means or hierarchical clustering, because Euclidean distance behaves better in a denoised, isotropic subspace.
- Topic 03 measurement / descriptive statistics: PCA depends on second moments (covariance), so robust statistics, scaling, and outlier handling done earlier directly affect PCA quality.
- Topic 09 supervised learning: PC scores can serve as compressed inputs for regressors/classifiers, although for prediction PLS may be preferable since it uses the label.

## 9. Relevance to CPBL Unsupervised Feature Discovery

PCA and SVD are the workhorse tools for the unsupervised stage of the CPBL pipeline. Concrete uses tailored to Senior Wang's feature list:

- Build a per-game feature matrix X of shape (n_games_2023+2024, 10) using Senior Wang's variables (run_per_hit, innings_pitched, H, scored_first, whip_like, hr_allowed, hits_allowed, AB, middle_runs, late_runs). Standardize each column with `StandardScaler` first, because innings_pitched (single digits), AB (~30 per game), and middle_runs/late_runs (often 0-3) have very different variances, exactly the USArrests pitfall.
- Concrete PCA usage idea. Fit `PCA(n_components=None)` on the standardized matrix, examine `explained_variance_ratio_`, and keep enough components to reach 90 percent cumulative PVE (in the CPBL feature list we expect 2-3 PCs to suffice). Then run k-means or hierarchical clustering on the kept PCs rather than on the raw 10 features; this denoises and decorrelates the obvious redundancies (e.g. H, hits_allowed, AB all correlate with game length).
- Inspect `pca.components_` as a loadings table to discover composite axes such as "PC1 = offensive output" (positive loadings on H, AB, run_per_hit) and "PC2 = pitching distress" (positive loadings on whip_like, hr_allowed, hits_allowed). Reporting these axes is a direct, qualitative answer to "what structure exists in CPBL games?".
- Plot a 2-D biplot of PC1 vs PC2 colored by team or by scored_first (1/0). This visualization is the headline figure for the EDA section and lets us check whether scored_first separates linearly along a single PC, motivating downstream supervised modeling.
- Use TruncatedSVD if we expand features into one-hot encodings of inning-level events or opponent identifiers (high-dimensional, sparse); it gives PCA-like compression without densifying the matrix.
- Project the 2024 games onto the 2023-trained PCA basis with `pca.transform` to study season-to-season drift: if 2024 scores cluster differently from 2023, that signals a regime change in offensive/pitching balance.
- Treat the top PCs as compact game embeddings that can also feed Topic 08's clustering pipeline (k-means, GMM) and Topic 09's supervised models, reducing overfitting risk on a dataset with only ~240 games per season.
- Watch out for outlier games (e.g. extra-innings blowouts) skewing PC directions; consider clipping or running PCA on a robust-scaled copy as a sensitivity check.

### 9.1 Suggested notebook checklist for the PCA stage

1. After preprocessing the 2023+2024 JSON into a tidy per-game DataFrame, assemble a feature matrix using the Senior Wang shortlist plus any obvious derivatives.
2. Run descriptive statistics (mean, std, skew, missingness) on each column; impute or drop before PCA, because PCA does not tolerate NaNs.
3. Standardize with `StandardScaler` fit only on the training subset to avoid leakage if any supervised step follows later.
4. Fit a full-rank `PCA(n_components=None)`; plot a scree of `explained_variance_ratio_` and the cumulative curve.
5. Pick k by either the elbow of the scree or a 90 percent cumulative threshold; refit `PCA(n_components=k)`.
6. Export a loadings heatmap to interpret each retained PC against Senior Wang's variables.
7. Produce a biplot of PC1 vs PC2 colored by team or by `scored_first`, with a confidence ellipse per group, mirroring the iris demo from the slides.
8. Persist the fitted `scaler` and `pca` objects (e.g. via joblib) so the same projection can be applied to 2024-only or hold-out data later in the notebook.

### 9.2 Mapping Senior Wang's features to expected PC behavior

- Offense-cluster candidates (likely co-load on the same PC): H, AB, run_per_hit, scored_first.
- Pitching-distress candidates (likely co-load with opposite or orthogonal sign): hits_allowed, hr_allowed, whip_like.
- Pacing / late-game candidates: innings_pitched, middle_runs, late_runs (extra-innings games will pull these together).
- Composite interpretation. We expect roughly a 2-3 PC story: PC1 = offense intensity, PC2 = pitching trouble, PC3 = game-length / late-game scoring. Confirming or refuting this with empirical loadings is itself a worthwhile EDA finding for the report.
- If a PC ends up loaded almost entirely on a single feature, that is a signal to revisit standardization or to drop that feature from the PCA input.
- Sanity check via reconstruction. Compute `X_reconstructed = pca.inverse_transform(pca.transform(X_std))` and look at the per-feature reconstruction error; features with high error are the ones least represented in the kept PCs, which is useful diagnostic information.
- Reproducibility. Even though `PCA` in sklearn is deterministic for the `'full'` solver, the `'randomized'` and `'arpack'` solvers depend on `random_state`. Set it explicitly so reruns of the notebook produce identical PC coordinates.
