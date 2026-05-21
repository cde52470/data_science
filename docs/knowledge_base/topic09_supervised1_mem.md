# Topic 09 — Supervised Learning Part 1: Memorization Methods (kNN & Naive Bayes)

## 1. Topic Summary

This lecture (Prof. Jia-Ming Chang, NCCU CS) introduces **memorization-based supervised learning** — methods that effectively *store* the training data (or compact per-variable summaries of it) and produce predictions for new points by looking up similar training records. The course frames three families as memorization methods:

1. **Single-variable models** — for each predictor, summarise its empirical conditional outcome distribution (a pivot/contingency table for categorical inputs; quantile-binned tables for numeric inputs). These act as one-feature lookups.
2. **Naive Bayes** — a multi-variable extension that multiplies the single-variable likelihoods under a conditional-independence assumption (`P(ev_1,...,ev_N | y) ≈ ∏ P(ev_i | y)`).
3. **k-Nearest Neighbours (kNN)** — at prediction time, locate the *k* closest training points by a distance metric and return a majority vote (classification) or mean (regression) of their labels. kNN literally keeps the entire training set.

The case study is the **KDD Cup 2009 customer-relationship data** (50,000 credit-card accounts × 230 features; goals: churn, appetency, upselling). The lecture works through preparing the data, building single-variable models, AUC evaluation, cross-validation for overfitting estimation, variable selection by log-likelihood, then running Naive Bayes and kNN, comparing AUC across train / calibration / test splits.

Although the course code is in R (`class::knn`, `e1071::naiveBayes`, `ROCR`), the concepts transfer one-to-one to Python (`sklearn.neighbors.KNeighborsClassifier`, `sklearn.naive_bayes.GaussianNB`, `sklearn.metrics.roc_auc_score`).

For our CPBL pipeline (which ends at unsupervised feature discovery), the methodological transfer is mainly the **distance / similarity machinery** that kNN shares with clustering (k-means, HDBSCAN, spectral), and the **probabilistic per-feature summarisation** intuition behind Naive Bayes that mirrors how we score per-feature informativeness during EDA and unsupervised feature engineering.

---

## 2. Outline

1. Recap of unsupervised methods (clustering, association rules, cluster stability via Jaccard / bootstrap, Calinski–Harabasz index, dendrograms).
2. The KDD Cup 2009 problem statement and data preparation pipeline.
3. Single-variable models — categorical and numeric (quantile-binning) variants.
4. Evaluating single-variable models — AUC, train/calibration/test split, density plots.
5. Handling missing values — indicator + imputation pattern.
6. Cross-validation for overfitting estimation; `replicate()` vs `for` loops.
7. Multivariable Naive Bayes — assumption, math, log-space implementation, smoothing.
8. k-Nearest Neighbours — concept, choice of *k*, class-imbalance considerations.
9. Variable selection via log-likelihood gain over baseline.
10. ROC curves and AUC comparisons across all methods.
11. Comparison summary: kNN vs Naive Bayes vs single-variable.

---

## 3. Key Concepts

### 3.1 Lazy (instance-based) vs eager (model-based) learning
- **Eager** learners (linear/logistic regression, decision trees, naive Bayes once fit) compress the training data into a fixed-size parameter vector at *training time*. Prediction is fast and the training data may be discarded.
- **Lazy** learners (kNN, kernel regression) defer almost all work to *prediction time*: they store the training set verbatim and search it for each query. Training cost is near zero; prediction cost grows with *n*.
- Memorization methods sit on a spectrum: single-variable models and Naive Bayes are "memorize summary tables"; kNN is "memorize every row".

### 3.2 Bias–variance trade-off (operationalised through *k*)
- Small *k* (e.g. k=1): very flexible decision boundary, **low bias, high variance** — memorises noise.
- Large *k*: smoother, more biased estimator approaching the global class prior — **high bias, low variance**.
- The lecture's KDD example uses k=200 because the positive class is ~7%; this is needed so each neighbourhood contains ~10 positives to give non-trivial probability resolution (10/0.07 ≈ 142, rounded up to 200).
- 3-NN on a ~7% positive class can only output {0, 1/3, 2/3, 1} — a coarseness issue called *concept-space granularity*.

### 3.3 Generalisation, calibration and overfitting
- Three subsets used: **train**, **calibration** (a held-out 10% of training used to score variables and pick *k*), and **test**.
- Single-variable categorical models had train AUC=0.83 but calibration AUC=0.565 and test=0.551 — classic overfit signature on high-cardinality categoricals.
- The lecture advocates **replicated cross-validation** (resample the calibration split 100–1000 times via `replicate()`) when fitting many variables, level values, or when individual estimates are noisy.

### 3.4 Bayes optimal classifier & decision boundary
- For a two-class problem, assign class 1 when `Pr(Y=1|X=x_0) > 0.5`, else class 2.
- The set where `Pr(Y=orange|X)=0.5` is the **Bayes decision boundary**; the irreducible misclassification rate along it is the **Bayes error rate**.
- All methods (kNN, naive Bayes, logistic regression) are attempts to estimate the same `Pr(Y|X)` from data.

### 3.5 Curse of dimensionality (implicit but central to memorization methods)
- In high *d*, Euclidean distances become uninformative — the ratio of nearest to farthest neighbour approaches 1.
- This is why the lecture's kNN step is preceded by *variable selection* using log-likelihood gain — kNN is only run on the few features that beat baseline by `minStep=5` log-likelihood units.

---

## 4. Methods — Reference Table

| Name | When to use | Math | Python | Caveats |
|---|---|---|---|---|
| **Single-variable model (categorical)** | Quick baseline; high-cardinality categorical predictors | `P(y=1|x=c) = (count(y=1,x=c) + α·p_pos) / (count(x=c) + α)` — Laplace-style smoothing | `groupby(col).agg(mean_target)` then map onto new data | Overfits rare levels; need calibration set; NA handling needed |
| **Single-variable model (numeric)** | Quick baseline for numeric features | Bin via deciles (`np.quantile(x, np.linspace(0,1,11))`), then apply categorical model on bins | `pd.qcut(x, 10)` then groupby-target | Bin edges learned from train only; bins on test that fall outside need fallback |
| **Naive Bayes (own impl., log-space)** | Many weak/independent features (text, document classification) | `log P(y|ev) ∝ log P(y) + Σ log P(ev_i|y)`; under independence assumption | `from sklearn.naive_bayes import GaussianNB / MultinomialNB / BernoulliNB` | Independence assumption violated by correlated features; needs smoothing (ε≈1e-5 in slides); can overconfident-predict |
| **Naive Bayes (package: `e1071::naiveBayes` in R; `sklearn.naive_bayes` in Python)** | Fast multi-feature classifier | as above with library smoothing | `GaussianNB().fit(X,y).predict_proba(X)` | sklearn's GaussianNB assumes Gaussian per-feature likelihoods; for categorical use MultinomialNB or CategoricalNB |
| **kNN classification** | Decision boundaries are non-linear and locally smooth; moderate *n*; well-scaled features | Predict class with majority vote among the *k* nearest training points by chosen metric | `KNeighborsClassifier(n_neighbors=k, weights='uniform'/'distance', metric=...)` | Sensitive to feature scale; curse of dimensionality; slow at predict time; class imbalance distorts probabilities |
| **kNN regression** | Smooth non-linear regression; baseline for tabular | `ŷ(x) = (1/k) Σ_{i ∈ N_k(x)} y_i` | `KNeighborsRegressor(n_neighbors=k)` | Same scaling/dimensionality issues; biased near boundary of training range |
| **Weighted kNN** | When closer neighbours should count more | `ŷ = Σ w_i y_i / Σ w_i`, `w_i = 1/d(x,x_i)` or kernel | `weights='distance'` or callable | Tied / zero-distance points need handling; pick weight schedule |

### 4.1 Distance metrics — short reference

| Metric | Formula | Use when |
|---|---|---|
| **Euclidean** L2 | `d(x,y) = sqrt(Σ (x_i − y_i)^2)` | Features are on comparable scales (after standardisation), Gaussian-ish geometry |
| **Manhattan** L1 | `d(x,y) = Σ |x_i − y_i|` | Robust to outliers in individual axes; sparse / grid-like data |
| **Minkowski Lp** | `d = (Σ |x_i−y_i|^p)^{1/p}` | Generalises L1 (p=1), L2 (p=2); tune *p* if you like |
| **Chebyshev L∞** | `d = max_i |x_i − y_i|` | Worst-coordinate matters most |
| **Mahalanobis** | `d(x,y) = sqrt((x−y)^T Σ⁻¹ (x−y))` | Account for feature covariance and scale automatically; equivalent to Euclidean in PCA-whitened space |
| **Cosine** | `d = 1 − (x·y)/(‖x‖‖y‖)` | Direction/profile matters more than magnitude (text TF-IDF, normalised player profiles) |
| **Hamming** | `d = Σ 1[x_i ≠ y_i]` | Binary/categorical strings |
| **Jaccard** | `1 − |A∩B|/|A∪B|` | Set/binary indicator vectors (also referenced in the slides for cluster stability) |

### 4.2 Kernel methods (briefly referenced via density / weighting language)
The slide deck does not develop full kernel regression (Nadaraya–Watson) or SVM kernels, but the *weighted-kNN* idea is the discrete analogue. A kernel `K(d)` (Gaussian, Epanechnikov, tricube) replaces the hard 1/0 indicator of "is in top *k*" with a smooth weight on distance. In Python: `sklearn.neighbors.KernelDensity`, or a custom callable in `KNeighborsRegressor(weights=...)`.

---

## 5. Code Snippets

### 5.1 R reference (from the lecture)
```r
# Single-variable categorical model with Laplace-style smoothing
mkPredC <- function(outCol, varCol, appCol) {
  pPos <- sum(outCol == pos) / length(outCol)
  naTab <- table(as.factor(outCol[is.na(varCol)]))
  pPosWna <- (naTab / sum(naTab))[pos]
  vTab <- table(as.factor(outCol), varCol)
  pPosWv <- (vTab[pos,] + 1.0e-3 * pPos) / (colSums(vTab) + 1.0e-3)
  pred <- pPosWv[appCol]
  pred[is.na(appCol)] <- pPosWna
  pred[is.na(pred)]   <- pPos
  pred
}

# Numeric -> quantile binning -> reuse categorical model
mkPredN <- function(outCol, varCol, appCol) {
  cuts <- unique(as.numeric(quantile(varCol, probs = seq(0, 1, 0.1), na.rm = TRUE)))
  varC <- cut(varCol, cuts)
  appC <- cut(appCol, cuts)
  mkPredC(outCol, varC, appC)
}

# Log-space Naive Bayes (own implementation)
nBayes <- function(pPos, pf) {
  pNeg <- 1 - pPos
  eps  <- 1.0e-5
  scorePos <- log(pPos + eps) + rowSums(log(pf      / pPos     + eps))
  scoreNeg <- log(pNeg + eps) + rowSums(log((1 - pf) / (1 - pPos) + eps))
  m <- pmax(scorePos, scoreNeg)
  ePos <- exp(scorePos - m); eNeg <- exp(scoreNeg - m)
  ePos / (ePos + eNeg)
}

# kNN via class package
library(class)
nK <- 200
knnPred <- function(df) {
  d <- knn(knnTrain, df, knnCl, k = nK, prob = TRUE)
  ifelse(d == TRUE, attributes(d)$prob, 1 - attributes(d)$prob)
}
```

### 5.2 Python equivalents (what we'd actually use)

```python
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.neighbors import (
    KNeighborsClassifier, KNeighborsRegressor, NearestNeighbors,
)
from sklearn.naive_bayes import GaussianNB, MultinomialNB
from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.metrics import roc_auc_score, RocCurveDisplay
from scipy.spatial.distance import cdist

# --- 1. Standardise BEFORE distance-based methods. Critical for kNN / clustering.
scaler = StandardScaler()
X_train_s = scaler.fit_transform(X_train)
X_test_s  = scaler.transform(X_test)

# --- 2. kNN classifier (uniform vote)
knn = KNeighborsClassifier(n_neighbors=200, weights='uniform', metric='euclidean')
knn.fit(X_train_s, y_train)
proba_test = knn.predict_proba(X_test_s)[:, 1]
print("Test AUC:", roc_auc_score(y_test, proba_test))

# --- 3. Distance-weighted kNN regression
knn_reg = KNeighborsRegressor(n_neighbors=15, weights='distance', metric='manhattan')
knn_reg.fit(X_train_s, y_train_continuous)

# --- 4. Mahalanobis distance kNN
cov_inv = np.linalg.pinv(np.cov(X_train_s, rowvar=False))
knn_maha = KNeighborsClassifier(
    n_neighbors=25,
    metric='mahalanobis',
    metric_params={'VI': cov_inv},
    algorithm='brute',  # required for arbitrary metric
)
knn_maha.fit(X_train_s, y_train)

# --- 5. Cosine-distance neighbours (useful for "player profile" similarity)
nn_cos = NearestNeighbors(n_neighbors=10, metric='cosine')
nn_cos.fit(X_train_s)
dist, idx = nn_cos.kneighbors(X_test_s)

# --- 6. Naive Bayes
gnb = GaussianNB(var_smoothing=1e-9).fit(X_train_s, y_train)
mnb = MultinomialNB(alpha=1.0).fit(X_train_counts, y_train)   # for count features

# --- 7. Choosing k with stratified CV (lecture's cross-validation idea)
auc_by_k = {}
for k in [5, 15, 50, 100, 200, 400]:
    auc = cross_val_score(
        KNeighborsClassifier(n_neighbors=k),
        X_train_s, y_train,
        cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=0),
        scoring='roc_auc',
    ).mean()
    auc_by_k[k] = auc

# --- 8. Quantile-bin single-variable model (the lecture's mkPredC/N)
def fit_singlevar_numeric(x_train, y_train, n_bins=10, alpha=1e-3):
    edges = np.unique(np.quantile(x_train, np.linspace(0, 1, n_bins + 1)))
    bins  = pd.cut(x_train, edges, include_lowest=True)
    p_pos = float(np.mean(y_train))
    table = (pd.crosstab(bins, y_train)
               .pipe(lambda t: (t.get(1, 0) + alpha * p_pos)
                              / (t.sum(axis=1) + alpha)))
    return edges, table, p_pos

def apply_singlevar_numeric(x_new, edges, table, p_pos):
    bins = pd.cut(x_new, edges, include_lowest=True)
    out  = bins.map(table).astype(float)
    return out.fillna(p_pos).to_numpy()
```

### 5.3 Variable selection by log-likelihood gain (R, slide-faithful)
```r
logLikelyhood <- function(outCol, predCol) {
  sum(ifelse(outCol == pos, log(predCol), log(1 - predCol)))
}

baseRateCheck <- logLikelyhood(
  dCal[, outcome],
  sum(dCal[, outcome] == pos) / length(dCal[, outcome])
)
minStep <- 5
selVars <- c()
for (v in catVars) {
  pi <- paste('pred', v, sep = '')
  liCheck <- 2 * (logLikelyhood(dCal[, outcome], dCal[, pi]) - baseRateCheck)
  if (liCheck > minStep) {
    selVars <- c(selVars, pi)
  }
}
```

The factor `2` and threshold `5` correspond informally to a chi-square / deviance test at a generous level — the slide treats it as a screening tool, not a formal test.

---

## 6. Examples / Datasets

### 6.1 KDD Cup 2009 (lecture case study)
- **Source:** 230 features × 50,000 credit card accounts.
- **Targets:** `churn` (account cancellation), `appetency` (propensity for new products), `upselling` (response to marketing).
- **Class imbalance:** ~7% positive for `churn` — drives the `k=200` choice.
- **Split:** 90% train / 10% test; train further split into ~90% fit / ~10% calibration via `rbinom(prob=0.1)`.
- **Final AUC summary table from the slides** (note Naive Bayes overfits hard on train, then collapses on test):

| Model | Train AUC | Calibration AUC | Test AUC |
|---|---|---|---|
| Single-variable, categorical | 0.830 | 0.565 | 0.551 |
| Single-variable, numerical | 0.635 | 0.629 | 0.637 |
| k-NN (k=200) | 0.744 | 0.711 | 0.718 |
| Naive Bayes (own log-space) | 0.975 | 0.599 | 0.595 |
| Naive Bayes (`e1071`) | 0.464 | 0.554 | 0.567 |

kNN ended up the most generalisable model in this study — modest train AUC but the smallest train-test gap.

### 6.2 Other classic kNN datasets
- **Iris** (3 species × 4 features) — toy kNN demo.
- **MNIST** — kNN with Euclidean on raw pixels reaches ~97% (slow but a fair baseline).
- **20 Newsgroups** — text Naive Bayes baseline; cosine distance for kNN.

---

## 7. Pitfalls

1. **Unscaled features dominate Euclidean distance.** A feature ranging 0–10 000 will swamp one ranging 0–1. Always `StandardScaler` (or `RobustScaler` if outliers exist) before kNN.
2. **Curse of dimensionality.** In high *d* without feature selection, kNN distances concentrate and neighbours become uninformative. Use variable selection (lecture's log-likelihood screen) or PCA first.
3. **High-cardinality categoricals overfit single-variable models.** The 0.83 → 0.55 train→test AUC drop is a warning: a contingency table with one row per training observation will memorise but never generalise. Smoothing (`α·p_pos` in the slides) and a calibration set are mandatory.
4. **Class imbalance & probability resolution.** For very rare positives, small *k* gives output probabilities on a discrete coarse grid (lecture rule: pick *k* so each neighbourhood holds ~10 positives).
5. **Naive Bayes independence assumption.** When features are correlated, the log-likelihood multiplication double-counts evidence and produces overconfident probabilities (AUC=0.975 on train, 0.595 on test in the slide table).
6. **NA handling matters.** The lecture's two-step pattern: add an indicator variable `is_missing`, then impute the original with 0 (or median). Forgetting either step leaks bias.
7. **kNN test-time cost.** O(n) per query with brute force. For large *n*, use `ball_tree`, `kd_tree`, or approximate libraries (Faiss, Annoy, HNSW).
8. **Train/calibration leakage.** Quantile bin edges, scaler statistics, and any per-feature summaries must be fit on *train only* and reused on calibration / test.
9. **Mahalanobis covariance instability.** With p > n or near-collinear features, `Σ` is singular — use `np.linalg.pinv` or shrinkage (Ledoit–Wolf).
10. **`replicate()` vs `for` (lecture aside).** The two are equivalent semantically; `replicate()` is slightly cleaner and very mildly faster for 1000+ iterations.

---

## 8. Cross-references

- **Topic 08 (Unsupervised — clustering):** Every distance metric in §4.1 is shared with k-means, hierarchical clustering, HDBSCAN, and spectral clustering. The scaling pitfalls and curse-of-dimensionality warnings in §7 apply identically.
- **Topic 05-1 (PCA / SVD):** PCA-whitening is exactly Mahalanobis distance in the original space; using Euclidean kNN after PCA achieves the same effect.
- **Topic 05-2 (Feature explanation):** The lecture's per-variable AUC and log-likelihood scoring is a sibling of mutual-information / `f_classif` feature ranking.
- **Recap material at top of slides:** Jaccard coefficient and `clusterboot` from the prior unsupervised lecture re-appear here as set-similarity / stability ideas; the same `clusterboot`-style bootstrap stability test could be applied to kNN-derived neighbourhoods.
- **Forward link (Supervised Part 2 — likely linear/logistic/SVM):** Naive Bayes and kNN are baselines that those parametric methods must beat; logistic regression's decision boundary is the linear approximation of the Bayes boundary diagrammed in this lecture.

---

## 9. Relevance to CPBL (rebas.tw 2023 + 2024)

Although our final notebook deliberately ends at unsupervised feature discovery (no churn-style supervised target), four kNN / Naive-Bayes ideas carry over directly and one more is worth flagging:

- **Distance metric choice for player/team profiles.** Senior Wang's top features (`run_per_hit`, `innings_pitched`, `H`, `whip_like`, `hr_allowed`, `hits_allowed`, `AB`, `middle_runs`, `late_runs`, `scored_first`) live on *very* different scales — `innings_pitched` is ~5–7, `H` and `AB` are tens-to-hundreds, `scored_first` is 0/1. Without standardisation, Euclidean distance in HDBSCAN or k-means becomes "the AB metric". Use `StandardScaler` or `RobustScaler` exactly as kNN would require.

- **Mahalanobis / PCA-whitening for correlated rate stats.** `whip_like`, `hits_allowed`, and `hr_allowed` are highly correlated for pitchers; `H` and `AB` for batters. Mahalanobis distance (or equivalently, k-means in PCA-whitened space) removes this redundancy — directly relevant to the cluster/feature-discovery step.

- **Cosine similarity for "profile" comparisons.** When we care about a player's *shape* across the feature vector (e.g. "is this batter a power-and-strikeout type or a contact type?") rather than total volume, cosine distance after row-normalisation gives the right neighbourhoods. This feeds into descriptive statistics ("who are the 5 most similar batters to player X?") even without a supervised target.

- **Neighbourhood concepts feed HDBSCAN / spectral.** HDBSCAN's `min_samples` and spectral clustering's affinity matrix are both nearest-neighbour graphs — the same `NearestNeighbors` machinery used for kNN. Choosing *k* by the lecture's rule (large enough for stable neighbourhood probabilities; ~√n is a rule of thumb) translates to choosing `min_samples` for HDBSCAN.

- **Per-feature summarisation echoes single-variable models.** The lecture's `mkPredC` / `mkPredN` (quantile-binning + within-bin target rate) is the supervised analogue of our EDA step: quantile-binning `run_per_hit` and visualising distributions by year / team / position is the same machinery, only without a `y`. Even without a target, the lecture's *variable-selection-by-log-likelihood-gain* idea can be repurposed as *variable-selection-by-variance-explained* (e.g. how much of cluster separation each feature carries) in our unsupervised pipeline.

- **(Bonus) Framing supervised intuitions about our unsupervised features.** If a downstream user *did* want to predict, say, `scored_first` or season win count from our discovered features, the Naive Bayes / kNN baselines from this lecture are the right sanity checks. We can mention that our feature set is "kNN-friendly" (low-dimensional, standardised, decorrelated) in the final notebook's "future work" remarks.
