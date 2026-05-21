# Topic 05 — Feature Reduction: Selection and Extraction

## 1. Topic Summary

Feature reduction is the umbrella term for cutting an input space of `p` features
down to a smaller, more informative set before downstream modeling. The lecture
(Prof. Jia-Ming Chang, Dept. of Computer Science, NCCU) splits the problem into
two complementary branches:

- **Feature selection** — keep a *subset* of the original features without any
  transformation. The chosen columns retain their original names and units,
  which preserves interpretability. Use cases: improve recognition rate, reduce
  computational load, and explain the relationship between features and the
  target class.
- **Feature extraction** — apply a (usually linear) transformation that maps
  the original `p` features into a new low-dimensional space whose axes are
  chosen to maximize variance (PCA / SVD), separation between classes (LDA),
  contingency-table inertia (CA), or generative likelihood (PLSA). The new
  axes are linear combinations of old features and are generally **not**
  interpretable as physical quantities.

The lecture frames feature reduction as a tool that simultaneously fights the
curse of dimensionality, suppresses redundancy/multicollinearity, lowers
variance (recall the previous lecture's bias–variance decomposition), and
exposes structure for exploratory data analysis. For our CPBL final project,
where we engineer ~30 Wang-style features per game (run_per_hit, WHIP-like,
innings_pitched, etc.), this topic tells us how to prune that pile before
clustering or PCA-based visualisation.

## 2. Outline

1. Recap of bias–variance trade-off, A/B testing, statistical power, and
   multiple-testing corrections — motivates *why* we should reduce features
   (variance scales with the number of estimated parameters).
2. Feature reduction taxonomy.
   - Feature selection (subset, no transform).
   - Feature extraction (transform into a new coordinate system).
3. Feature selection methods.
   - Exhaustive search (KNN classifier + leave-one-out R²).
   - One-pass ranking (filter scores).
   - Sequential forward selection (SFS).
   - Sequential backward selection (SBS).
   - Generalized SFS / SBS.
   - "Add m, remove n" plus-l-minus-r style stepwise.
   - Recursive Feature Elimination (RFE).
   - LIME-style local interpretability hooks.
4. Feature extraction methods.
   - PCA (Principal Component Analysis) and its weakness for classification.
   - SVD (Singular Value Decomposition), LSI for text.
   - Correspondence Analysis (CA) for contingency tables.
   - Linear Discriminant Analysis (LDA), which uses class labels.
   - Probabilistic Latent Semantic Analysis (PLSA) fit by EM.
5. How to interpret the resulting features (cross-references to
   `topic05-2_featureExplain.pptx`).

## 3. Key Concepts

### 3.1 Curse of dimensionality
As `p` grows, the volume of feature space grows exponentially while the number
of observations `n` stays fixed. Nearest-neighbour distances become uniform,
densities collapse, and any model that has to estimate `O(p)` or `O(p²)`
parameters spreads its sample evidence thin. This inflates model variance and
shows up as test-error explosion in the bias–variance plot from Topic 04.

### 3.2 Redundancy and multicollinearity
Two features that carry essentially the same signal (e.g., hits H and AB on a
per-game basis, or innings_pitched and outs_recorded) are *redundant*. With
linear models, redundant columns produce ill-conditioned design matrices —
coefficients become large, opposite-signed, and unstable. Even with tree-based
or distance-based learners, redundant columns over-weight whatever the
duplicated signal happens to encode and dampen the influence of unique
predictors.

### 3.3 Relevance vs. importance
A feature can be individually irrelevant yet jointly informative (XOR-style),
and individually strong yet redundant with another. Filter methods that score
features in isolation miss interactions; wrapper and embedded methods can
catch them but are more expensive.

### 3.4 "Good ranking ≠ good subset"
The lecture explicitly warns: a good feature *ranking* criterion is not
necessarily a good feature *subset* criterion. Removing the bottom-k features
from a one-pass ranking can be very suboptimal when several features are
correlated — you may drop two redundant winners and keep no information. RFE
addresses this by re-fitting after every removal.

### 3.5 Three-way data split
Selecting features and tuning hyper-parameters on the same fold that scores
performance is a leakage classic. Use a train/validation/test or nested-CV
split: select on train, evaluate on validation, report on test.

### 3.6 Multiple-testing and "venue shopping"
If you compute p-values for every feature against a target, the expected
number of false discoveries at α=0.05 is `0.05 × p`. Reduce α to `0.05 / p`
(Bonferroni) or use FDR control (Benjamini–Hochberg) before declaring a
feature "significant".

### 3.7 Interpretability cost
Selection keeps real variables — easy to explain to a coach or a project
reviewer. Extraction creates abstract axes such as `PC1 = 0.4·H + 0.3·AB −
0.6·whip_like ...`; the reconstruction may even contain negative entries that
are nonsensical for count features, as the slide on SVD weakness flags.

## 4. Methods — Name | When | Math | Python | Caveats

| Name | When to use | Math sketch | Python | Caveats |
|------|-------------|-------------|--------|---------|
| **Variance threshold** (filter) | Quick screen for near-constant columns. | Drop features where `Var(X_j) < τ`. | `sklearn.feature_selection.VarianceThreshold(threshold=…)` | Variance depends on scale; standardize first or apply only to comparable counts. |
| **Pearson / Spearman correlation** (filter) | Continuous-vs-continuous redundancy or target relevance. | `ρ = Cov(X,Y)/(σ_X σ_Y)`. | `df.corr()` plus pruning loop; `scipy.stats.pearsonr`. | Captures only linear/monotone signal; symmetry hides direction of causation. |
| **Mutual information** (filter) | Non-linear dependence with continuous or categorical target. | `I(X;Y) = Σ p(x,y) log p(x,y)/(p(x)p(y))`. | `sklearn.feature_selection.mutual_info_classif / _regression`. | Estimation is noisy for small `n`; needs binning or k-NN density estimate. |
| **Chi-squared** (filter) | Categorical feature, categorical target, all non-negative counts. | `χ² = Σ (O−E)²/E`. | `sklearn.feature_selection.chi2` followed by `SelectKBest`. | Requires non-negative inputs; sensitive to sparse cells. |
| **ANOVA F-test** (filter) | Continuous feature, categorical target. | Ratio of between-class to within-class variance. | `sklearn.feature_selection.f_classif`. | Assumes homoscedasticity and Gaussianity; use Kruskal–Wallis as a non-parametric backup. |
| **Exhaustive search** (wrapper) | Tiny `d`. | Enumerate all 2^d − 1 subsets; score with KNN + LOO R². | Custom loop with `sklearn.model_selection.LeaveOneOut`. | 2^d − 1 ≈ 1023 fits for d=10; intractable beyond ~15 features. |
| **Sequential Forward Selection (SFS)** (wrapper) | Medium d, hill-climb from empty set. | Greedy: add feature that most improves CV score; repeat. Cost ≈ d(d+1)/2 CV fits. | `mlxtend.feature_selection.SequentialFeatureSelector` or `sklearn.feature_selection.SequentialFeatureSelector(direction='forward')`. | Greedy → can miss the global optimum; cannot undo an early bad choice (use "add-m, remove-n" to mitigate). |
| **Sequential Backward Selection (SBS)** (wrapper) | Medium d, hill-climb from full set. | Greedy: drop the feature whose removal least hurts CV. | `SequentialFeatureSelector(direction='backward')`. | Expensive when starting d is large; same locality issue. |
| **Add-m, remove-n / plus-l-minus-r** (wrapper) | When pure SFS/SBS gets stuck. | After every `m` additions, remove the worst `n`. | Custom loop. | Hyper-parameters `m, n` themselves need tuning. |
| **Recursive Feature Elimination (RFE)** (wrapper/embedded hybrid) | Linear, SVM, or tree models exposing `coef_` or `feature_importances_`. | (1) Fit model; (2) compute importance; (3) drop the weakest; (4) refit. Repeat until k left. | `sklearn.feature_selection.RFE`, `RFECV`. | Re-fit cost is `d` model trainings; importance from a misspecified model gives misleading rankings. |
| **Lasso / L1 regression** (embedded) | Linear, sparse signal expected. | `min Σ(y − Xβ)² + λ‖β‖₁`. Many `β_j` shrink exactly to 0. | `sklearn.linear_model.Lasso, LassoCV, LogisticRegression(penalty='l1', solver='liblinear')`. | Standardize first; among correlated features Lasso picks an arbitrary one. Elastic Net (L1+L2) is more stable for groups. |
| **Tree feature importance** (embedded) | Any non-linear setting. | Mean decrease in impurity / permutation importance. | `RandomForestClassifier(...).feature_importances_`, `sklearn.inspection.permutation_importance`. | MDI is biased toward high-cardinality columns; prefer permutation importance on held-out data. |
| **PCA** (extraction, unsupervised) | Visualisation, decorrelation, variance compression. | Eigendecomposition of `XᵀX/(n−1)`; pick top-k components by explained variance. | `sklearn.decomposition.PCA(n_components=…)`. | Requires standardization; ignores class labels; nonsensical when units differ wildly. |
| **SVD / Truncated SVD / LSI** (extraction) | Sparse or term-document matrices. | `X = UΣVᵀ`; keep top-k singular triplets. | `sklearn.decomposition.TruncatedSVD`. | Reconstruction can have negative entries — meaningless for count data. |
| **Correspondence Analysis (CA)** (extraction) | Two-way contingency tables of counts. | Singular-value-style decomposition of a chi-squared-deviation matrix; produces factor scores for rows and columns. | `prince.CA`, or R's `ca::ca`. | Inputs must be non-negative counts/frequencies; categories with low mass dominate noise. |
| **LDA** (extraction, supervised) | Labeled classification problem. | Maximize between-class to within-class scatter: `S_B w = λ S_W w`. | `sklearn.discriminant_analysis.LinearDiscriminantAnalysis`. | Needs labels; at most `C − 1` components for `C` classes; assumes Gaussian class densities. |
| **PLSA** (extraction, probabilistic) | Topic modelling on word-document counts. | `P(w,d) = Σ_z P(w|z)P(z|d)P(d)`, fit via EM. | `gensim.models.LsiModel` / custom EM; LDA topic model is a Bayesian successor. | Overfits with many latent topics; needs held-out perplexity for k. |
| **t-SNE / UMAP** (extraction, non-linear) | 2-D visualisation of clusters. | t-SNE: minimize KL of pairwise Gaussian-vs-t-distribution similarities. UMAP: minimize cross-entropy on a fuzzy-simplicial neighbour graph. | `sklearn.manifold.TSNE`, `umap.UMAP`. | Distances on the map are not absolute; perplexity / `n_neighbors` heavily change layout; do not feed t-SNE outputs into downstream models. |
| **Autoencoder** (extraction, non-linear, neural) | Large datasets where linear PCA loses non-linear manifold structure. | Train an encoder–decoder net; bottleneck layer is the embedding. | `tensorflow.keras` or `torch` custom model. | Needs enough data; risk of trivial identity solutions; harder to interpret. |
| **LIME** (interpretability, not strictly reduction) | Explain individual predictions in terms of which features mattered locally. | Fit a sparse linear surrogate around a single instance. | `lime.lime_tabular.LimeTabularExplainer`. | Local, instance-specific; sensitive to the perturbation sampling. |

## 5. Code Snippets

### 5.1 Variance threshold + correlation filter

```python
import pandas as pd
import numpy as np
from sklearn.feature_selection import VarianceThreshold

# X: DataFrame of engineered CPBL features (one row per game-team).
X_std = (X - X.mean()) / X.std(ddof=0)

vt = VarianceThreshold(threshold=0.01)
X_vt = pd.DataFrame(
    vt.fit_transform(X_std),
    columns=X_std.columns[vt.get_support()],
)

# Pairwise correlation pruning at |r| >= 0.9
corr = X_vt.corr().abs()
upper = corr.where(np.triu(np.ones_like(corr, dtype=bool), k=1))
drop = [c for c in upper.columns if (upper[c] >= 0.9).any()]
X_pruned = X_vt.drop(columns=drop)
```

### 5.2 Mutual information ranking against a target

```python
from sklearn.feature_selection import mutual_info_classif

mi = mutual_info_classif(X_pruned, y_win, random_state=0)
ranking = pd.Series(mi, index=X_pruned.columns).sort_values(ascending=False)
print(ranking.head(15))
```

### 5.3 Lasso path for embedded selection

```python
from sklearn.linear_model import LassoCV
from sklearn.preprocessing import StandardScaler

scaler = StandardScaler()
Xz = scaler.fit_transform(X_pruned)
lasso = LassoCV(cv=5, random_state=0, n_alphas=100).fit(Xz, y_run_diff)
keep = X_pruned.columns[np.abs(lasso.coef_) > 1e-6]
print("Lasso kept:", list(keep))
```

### 5.4 Recursive Feature Elimination with CV

```python
from sklearn.feature_selection import RFECV
from sklearn.ensemble import GradientBoostingRegressor

selector = RFECV(
    estimator=GradientBoostingRegressor(random_state=0),
    step=1,
    min_features_to_select=5,
    cv=5,
    scoring="neg_mean_absolute_error",
).fit(X_pruned, y_run_diff)

print("Optimal #features:", selector.n_features_)
print("Chosen:", X_pruned.columns[selector.support_].tolist())
```

### 5.5 PCA for visualisation after selection

```python
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt

pca = PCA(n_components=2).fit(Xz[:, selector.support_])
emb = pca.transform(Xz[:, selector.support_])
plt.scatter(emb[:, 0], emb[:, 1], c=y_win, s=8, alpha=0.6)
plt.xlabel(f"PC1 ({pca.explained_variance_ratio_[0]:.1%})")
plt.ylabel(f"PC2 ({pca.explained_variance_ratio_[1]:.1%})")
plt.tight_layout()
```

### 5.6 Greedy sequential forward selection

```python
from sklearn.feature_selection import SequentialFeatureSelector
from sklearn.linear_model import Ridge

sfs = SequentialFeatureSelector(
    estimator=Ridge(alpha=1.0),
    n_features_to_select=8,
    direction="forward",
    scoring="r2",
    cv=5,
).fit(X_pruned, y_run_diff)
print("SFS kept:", X_pruned.columns[sfs.get_support()].tolist())
```

## 6. Examples / Datasets

- **Lecture example (writers / punctuation contingency table).** Six authors x
  three punctuation categories (Comma, Period, Others) shown via
  Correspondence Analysis. The first CA axis spread the authors who lean on
  periods from those who lean on commas, demonstrating how CA visualises
  category-vs-category structure.
- **Lecture example (Gram-negative bacteria).** CA reapplied to a
  microbiological contingency table, again to display category proximity in
  factor space.
- **PCA failure example (slide on "when PCA fails").** Two interlocking
  half-moons: variance is maximised along an axis that does *not* separate
  classes. Motivates LDA when labels exist or non-linear methods (t-SNE,
  UMAP, kernel PCA) otherwise.
- **PLSA on documents.** Term–document counts factorised into latent topics
  via EM; a precursor to LDA topic modelling.
- **CPBL game data (our final project).** Per-game team rows with
  `run_per_hit`, `innings_pitched`, `H`, `scored_first`, `whip_like`,
  `hr_allowed`, `hits_allowed`, `AB`, `middle_runs`, `late_runs`, plus
  derived ratios. ~30 features after Wang-style engineering, which is exactly
  the regime where this lecture's selection methods earn their keep.

## 7. Pitfalls

1. **Selecting on the test set.** All filter scores (variance, MI, χ², F) and
   wrapper CV scores must be computed on training folds only. Anything else
   leaks the target into your "selection".
2. **Forgetting to standardize before variance/PCA/Lasso.** A feature in
   thousands (e.g., `AB`) dominates one in fractions (e.g., `run_per_hit`)
   purely on units. Always z-score continuous columns first.
3. **Confusing ranking with subsetting.** Two perfectly correlated good
   features will both rank high, but you only need one. Combine ranking with
   correlation pruning or use embedded methods that handle redundancy.
4. **Greedy locality.** SFS/SBS choose the next-best step, never reconsidering
   earlier ones. Pair with floating variants ("add-m, remove-n") or RFE-style
   refits.
5. **MDI feature importance bias.** Random-forest impurity importance inflates
   high-cardinality and continuous features. Permutation importance on a
   held-out fold is the safer default.
6. **PCA on categorical / one-hot inputs.** The eigenstructure of a sparse
   binary matrix has little to do with semantic distance. Use MCA (multiple
   correspondence analysis) or treat categoricals separately.
7. **Negative reconstructions from SVD/PCA on counts.** Lecture flags this:
   numbers reconstructed from truncated SVD are *not* valid count vectors.
   Prefer non-negative matrix factorisation (NMF) or CA when inputs are counts.
8. **t-SNE / UMAP fed to a classifier.** Their embeddings are visualisations,
   not stable features. Distances are not preserved beyond local neighbourhoods.
9. **Multiple testing without correction.** Filtering 30 features with α=0.05
   gives ~1.5 expected false positives. Use Bonferroni or BH-FDR if you report
   selection p-values.
10. **Selecting features after imputation/scaling fitted on the full dataset.**
    Always wrap preprocessing + selection + model in a `Pipeline` so CV folds
    re-fit each step from scratch.

## 8. Cross-references

- **Topic 04 — Bias–variance, statistical testing.** The motivation for
  trimming features is to reduce model variance; the multiple-testing warning
  applies directly to filter selection.
- **Topic 05-1 — PCA.** A deep dive into the extraction side: derivation of
  principal components, explained variance, scree plots, loadings.
- **Topic 05-2 — Feature explanation (LIME / SHAP-style).** How to interpret
  whatever feature set we end up with.
- **Topic 06+ — Unsupervised learning, clustering.** Clustering on raw,
  redundant CPBL features will be dominated by whichever cluster of correlated
  columns is largest; pruning first changes the result dramatically.
- **Topic on regression / classification.** Embedded methods (Lasso, tree
  importance) live inside these models, so feature selection is not always a
  separate pipeline step.

## 9. Relevance to CPBL — pruning the 30+ Wang-style features before clustering

The final project pipeline (preprocess 2023+2024 rebas.tw JSON → descriptive
stats → EDA → unsupervised feature discovery) needs feature reduction *twice*:
once to clean redundant columns before clustering, and once to project to 2-D
for plotting. Concrete moves:

1. **Variance threshold + correlation prune first.** Several Wang features are
   algebraic siblings: `H` vs. `AB` (counts), `whip_like` vs. `hits_allowed +
   walks` (sum), `middle_runs + late_runs ≈ total_runs − early_runs`. Z-score
   every continuous column, then drop any feature whose absolute correlation
   with another retained feature exceeds 0.9. Expected drop: 8–12 of the 30.
2. **Use mutual information against a proxy target** such as
   `won_game ∈ {0,1}` or `run_diff`. This ranks features by non-linear
   relevance and exposes whether `scored_first` (binary) actually carries
   independent signal beyond the continuous offensive aggregates. Filter to
   the top 12–15.
3. **Apply Lasso/Elastic-Net regression on `run_diff`** as an embedded sanity
   check. Lasso will zero out coefficients of features that the linear story
   does not need; Elastic-Net is preferred because we have correlated groups
   (offence vs. pitching). The non-zero set is a defensible "kept by the
   model" list to compare with the filter ranking.
4. **Run RFECV with a Gradient Boosting regressor.** Non-linear interactions
   between `innings_pitched`, `hr_allowed`, and `whip_like` are exactly the
   kind of effect that filters miss. RFECV will recommend a feature count `k`
   based on cross-validated MAE.
5. **Cross-validate the union and intersection.** Cluster (k-means /
   hierarchical) on both the *union* of features selected by any method (more
   recall) and the *intersection* (more precision). Silhouette and Davies–
   Bouldin on the two sets tells us which is more cluster-friendly. The
   lecture's bias–variance lens predicts the intersection will give tighter
   but possibly fewer clusters.
6. **Reserve PCA for after selection.** Running PCA on all 30 raw features
   will make PC1 a "team scored a lot" axis dominated by counts on a different
   scale to ratios. After pruning, PCA on 8–12 standardised features yields
   PC1/PC2 that are interpretable (e.g., offensive output vs. pitching
   stinginess) and safe to colour-code by team or year.
7. **Use Correspondence Analysis on contingency tables we engineer.** Tables
   like `team x (won / lost / drew_first_blood / late_comeback)` are perfect
   CA inputs because rows are counts and we want a 2-D map of which teams
   pattern together. CA complements PCA on the *categorical* engineered
   variables that PCA cannot handle directly.
8. **Avoid t-SNE/UMAP for the final clustering substrate.** The lecture
   stresses that the goal of selection/extraction is to support a downstream
   classifier or cluster algorithm. Reserve t-SNE/UMAP for the EDA chart that
   accompanies the report, and run k-means/Gaussian Mixture on the
   selected-then-PCA features so cluster assignments are reproducible.

In short, for our CPBL notebook the practical order is:
**z-score → variance + correlation filter → mutual-information ranking → Lasso
/ RFECV refinement → PCA(2) for plotting → cluster on the chosen feature set.**
Each stage is implemented by one of the methods in section 4, with caveats in
section 7 watched.
