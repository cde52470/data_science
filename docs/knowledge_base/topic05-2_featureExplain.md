# Topic 05-2: Feature Explanation (LIME & SHAP)

## 1. Topic Summary

This topic covers **post-hoc model explanation**: techniques that attribute a
trained model's output to its input features so humans can understand
"why" a prediction was made. The lecture focuses on two flagship
**additive feature attribution methods**:

- **LIME** (Local Interpretable Model-Agnostic Explanations) — a *local*
  surrogate that approximates the black-box model with a simple linear
  model in the neighborhood of a single instance.
- **SHAP** (SHapley Additive exPlanations) — a unified game-theoretic
  framework that distributes the prediction "payout" among features using
  **Shapley values** from cooperative game theory.

The unifying idea is to define an **explanation model `g`** that is an
interpretable approximation of the original (often opaque) model `f`. We
do not change `f`; we build `g` purely to make `f`'s behavior legible.
The lecture also introduces the iris dataset (4 numeric features,
3 species) as a running example for LIME, and walks through the
pseudo-code of Kernel SHAP from the official `shap` Python repository.

Although our CPBL final project is **unsupervised**, the same intuitions
help interpret PCA loadings, cluster centroids, and the contribution of
each input feature to a discovered axis.

## 2. Outline

1. Motivation: why explanation models are needed
   - Simple models explain themselves; complex models (ensembles, deep
     nets) need a surrogate `g`.
2. Additive feature attribution: the common framework behind LIME / SHAP.
3. LIME
   - Iris running example (R / `lime` package, XGBoost classifier).
   - Intuition: local perturbations + weighted linear surrogate.
   - Mapping `x = h_x(x')` from interpretable inputs to original space
     (bag-of-words, image super-pixels).
4. SHAP
   - Shapley values from cooperative game theory.
   - Shapley regression values for ML.
   - **Kernel SHAP** algorithm — pseudo-code walk-through:
     `explain`, `addsample`, `run`, `solve`.
5. Practical considerations: coalitions, weighting, background data.

## 3. Key Concepts

- **Explanation model (`g`)**: an interpretable approximation of `f` used
  *only* for understanding, not for inference.
- **Additive feature attribution**: `g(x') = phi_0 + sum_j phi_j * x'_j`
  where `x'` is a binary "present / absent" vector and `phi_j` is the
  attribution to feature `j`.
- **Local fidelity**: an explanation needs to be accurate in the
  neighborhood of the instance, not globally.
- **Model-agnostic**: treats `f` as a black box — only requires the
  ability to query `f(x)`.
- **Interpretable input** (`x'`): a simplified representation:
  binary word-presence for text, super-pixels for images, discretized
  bins for tabular features.
- **Mapping function** `h_x(x')`: maps `x'` back to original space so we
  can query `f`.
- **Shapley value**: the unique fair allocation satisfying efficiency,
  symmetry, dummy, and additivity axioms — averages a feature's
  marginal contribution over all coalitions.
- **Coalition**: a subset of features marked "present" (others replaced
  by background values).
- **Background data**: distribution used to "mask" absent features
  during SHAP perturbation (often the training set's mean or a sample).

## 4. Methods Catalog

| Method | When to use | Math (sketch) | Python library | Caveats |
|---|---|---|---|---|
| **LIME** | Need a quick, local explanation for one instance of any model | Sample around `x`, weight by proximity kernel `pi_x`, fit sparse linear `g` minimizing `L(f, g, pi_x) + Omega(g)` | `lime` (Marco Ribeiro) | Unstable across runs; choice of kernel width and discretization changes the story; only locally valid |
| **Kernel SHAP** | Want consistent, theoretically grounded attributions for any model | Weighted linear regression with the **SHAP kernel** weights `(M-1)/(C(M,|z|) * |z| * (M-|z|))`; coefficients are Shapley values | `shap.KernelExplainer` | Exponential in #features; needs careful background-set choice; slow |
| **Tree SHAP** | Tree ensembles (XGBoost, LightGBM, RF) | Exact polynomial-time algorithm exploiting tree structure | `shap.TreeExplainer` | Tree-specific; conditional vs interventional expectation matters |
| **Deep SHAP** | Deep networks | Backpropagation-style approximation combining DeepLIFT with Shapley | `shap.DeepExplainer` | Approximation; depends on baseline |
| **Permutation importance** | Global feature ranking, any model | Drop in score after shuffling feature `j` over the validation set | `sklearn.inspection.permutation_importance` | Inflates importance for correlated features; uses model performance not raw output |
| **Partial Dependence Plot (PDP)** | Visualize average effect of feature `j` | `pd_j(v) = E_{x_{-j}}[f(v, x_{-j})]` averaged over data | `sklearn.inspection.PartialDependenceDisplay` | Hides interactions; misleading under feature correlation |
| **ICE (Individual Conditional Expectation)** | Show per-instance curves behind the PDP average | Plot `f(v, x_{-j}^{(i)})` for many `i` | Same as PDP | Visually busy; still assumes independence |
| **Global surrogate** | Get a "story" of a black-box model | Fit a decision tree on `(X, f(X))` | scikit-learn | Surrogate may have low fidelity |
| **Anchors** | Want rule-based local explanations | High-precision IF-THEN rules around `x` | `anchor` package | Coverage can be tiny |
| **Counterfactual** | "What would have changed the decision?" | Minimum perturbation `x' close to x` with `f(x') != f(x)` | `DiCE`, `alibi` | Many valid counterfactuals; needs constraints |

## 5. Code Snippets

The lecture itself uses R; below are paraphrased Python equivalents that
plug into the CPBL workflow.

### 5.1 LIME on a tabular classifier

```python
import lime
import lime.lime_tabular
from sklearn.ensemble import RandomForestClassifier

# Suppose X_train, y_train, X_test are CPBL game-level frames
clf = RandomForestClassifier(n_estimators=200, random_state=0).fit(X_train, y_train)

explainer = lime.lime_tabular.LimeTabularExplainer(
    training_data=X_train.values,
    feature_names=X_train.columns.tolist(),
    class_names=['lose', 'win'],
    discretize_continuous=True,   # mirrors bin_continuous=TRUE in R
    mode='classification',
)

i = 5
exp = explainer.explain_instance(
    data_row=X_test.iloc[i].values,
    predict_fn=clf.predict_proba,
    num_features=6,
    num_samples=5000,
)
exp.show_in_notebook()
```

### 5.2 Kernel SHAP for any black-box

```python
import shap
background = shap.utils.sample(X_train, 100)        # background set
explainer = shap.KernelExplainer(clf.predict_proba, background)
shap_values = explainer.shap_values(X_test.iloc[:50], nsamples=200)

shap.summary_plot(shap_values[1], X_test.iloc[:50])  # bee-swarm
shap.force_plot(explainer.expected_value[1],
                shap_values[1][0], X_test.iloc[0])
```

### 5.3 Tree SHAP (fast, exact for trees)

```python
import xgboost as xgb
model = xgb.XGBClassifier().fit(X_train, y_train)
explainer = shap.TreeExplainer(model)
sv = explainer.shap_values(X_test)
shap.summary_plot(sv, X_test, plot_type='bar')   # global importance
```

### 5.4 Permutation importance + PDP / ICE

```python
from sklearn.inspection import permutation_importance, PartialDependenceDisplay

perm = permutation_importance(model, X_val, y_val, n_repeats=30,
                              random_state=0, n_jobs=-1)
importances = sorted(zip(X_val.columns, perm.importances_mean),
                     key=lambda t: -t[1])

PartialDependenceDisplay.from_estimator(
    model, X_val, features=['run_per_hit', 'whip_like'],
    kind='both',  # 'both' = PDP + ICE
)
```

### 5.5 Pseudo-code from the lecture (Kernel SHAP)

```python
# Paraphrased from shap/explainers/_kernel.py
def explain(self, instance, **kw):
    varying = self.varying_groups(instance)        # which features differ
    if len(varying) == 0:
        return zeros(M)                            # nothing to attribute
    if len(varying) == 1:
        phi = zeros(M)
        phi[varying[0]] = f(instance) - f(background_mean)
        return phi

    # Enumerate or sample coalitions z in {0,1}^M
    for z in coalitions(varying):
        x_synth = mix(instance, background, mask=z)  # addsample()
        y_synth = f(x_synth)                          # run()
    return self.solve(fraction_evaluated, dim)        # weighted LR -> phi
```

## 6. Examples / Datasets

- **Iris (running example in slides)**
  - 4 features: `sepal length / width`, `petal length / width`.
  - 3 classes (`setosa`, `versicolor`, `virginica`) — collapsed to
    binary `is_setosa` for LIME.
  - 75 / 25 train-test split; XGBoost classifier; `lime::explain` with
    10 bins.
- **Text classification**: bag-of-words `x'` = 1/0 word indicator,
  `h_x` returns the original counts where present, zero where absent.
- **Image classification**: super-pixel segmentation; `h_x` paints
  absent super-pixels with their neighbor average.
- **Toy 2-D black box** used to motivate LIME: irregular pink/blue
  decision regions, one bold red cross is the instance; sampled
  perturbations are weighted by Euclidean proximity; a dashed line is
  the locally-fit linear surrogate.
- **Tabular benchmarks for SHAP**: UCI Adult (income), California
  housing, Boston housing — all common in `shap` tutorials.

## 7. Pitfalls

- **Correlated features**
  - LIME and Kernel SHAP perturb features independently, which can
    create unrealistic synthetic samples (off-manifold).
  - Tree SHAP "interventional" mode has the same issue;
    "conditional" mode tries to fix it but loses some Shapley axioms.
- **Background data choice (SHAP)**
  - Using the full training set is slow; sampling 100–200 rows is
    typical but adds variance. The expected value `phi_0` shifts with
    the background.
- **Kernel width / discretization (LIME)**
  - Small kernel = very local but noisy; large kernel = stable but no
    longer faithful. Bin count similarly trades stability for fidelity.
- **Instability**
  - Re-running LIME with different seeds produces different
    explanations — quote uncertainty.
- **Confusing global vs local**
  - LIME and per-instance SHAP are *local*; averaging |SHAP| across
    instances gives a global ranking but loses sign information.
- **Causality**
  - SHAP / LIME describe the *model*, not the world. A high SHAP value
    does not mean the feature causes the outcome.
- **Class semantics**
  - For multi-class, you must inspect the SHAP value for the *right*
    class — `shap_values[1]` is class-1, not "overall."
- **Computation**
  - Kernel SHAP is exponential in `M`; use Tree / Linear / Deep
    explainers when applicable.

## 8. Cross-references

- **Topic 05-1 (PCA & SVD)**: PCA *loadings* are a built-in
  explanation: each principal component is a linear combination of
  original features. SHAP-style thinking generalizes this to non-linear
  models.
- **Topic 05 (Feature Reduction)**: feature selection and explanation
  are duals — selection removes features, explanation ranks them.
- **Topic 08 (Unsupervised Learning)**: explanation ideas adapt to
  clusters by comparing cluster means to the global mean, or training a
  classifier "is in cluster k vs not" and explaining *that*.
- **Topic 09 (Supervised Learning)**: SHAP / LIME wrap any classifier
  or regressor built there.
- **Topic 06 (Visualization)**: bee-swarm, force plots, PDP, and ICE
  are standard explanation visuals.
- External: Lundberg & Lee (2017) *A unified approach to interpreting
  model predictions* (NeurIPS); Ribeiro et al. (2016) *Why should I
  trust you?* (KDD).

## 9. Relevance to CPBL (UNSUPERVISED scope)

Our project is unsupervised, but feature-explanation thinking is still
useful when interpreting clusters, PCA components, and unusual rows.

- **PCA loadings as cheap SHAP**: the linear coefficient of feature `j`
  in PC1 / PC2 plays the role of a Shapley value for that axis —
  e.g., if `run_per_hit` and `scored_first` load heavily on PC1, the
  first principal component is essentially an "offensive efficiency"
  axis. Quote both magnitude and sign.
- **Cluster interpretation via surrogate**: after K-Means on the
  2023+2024 game-level features, train a small decision tree or
  logistic regression as a *one-vs-rest* classifier per cluster, then
  apply Tree SHAP. Top SHAP features describe what makes that cluster
  distinctive — e.g., a "pitcher-duel" cluster may be dominated by low
  `H`, low `hits_allowed`, low `late_runs`.
- **Senior Wang's top features as anchors**: `run_per_hit`,
  `innings_pitched`, `H`, `scored_first`, `whip_like`, `hr_allowed`,
  `hits_allowed`, `AB`, `middle_runs`, `late_runs` are good candidates
  to display in PDP-style "feature vs cluster centroid" plots; they
  give a baseball-sensible vocabulary for naming clusters.
- **Permutation-style sanity checks for clustering**: shuffle one
  feature column, re-cluster, and measure how much the partition
  changes (ARI / NMI). Features that, when shuffled, destroy the
  clustering are the ones "driving" it — the unsupervised analogue of
  permutation importance.
- **Local explanation of outliers**: for a game flagged as an outlier
  by Mahalanobis or t-SNE, run LIME against a `is_outlier` classifier
  to learn which CPBL features pushed the row away from the mass.
- **Stability across 2023 vs 2024**: compute SHAP / loading magnitudes
  separately on each season, then compare; large shifts hint at rule
  changes, ballpark effects, or data drift that EDA must address.
