# Application of Machine Learning Models for Baseball Outcome Prediction (Lo et al., 2025)

> Citation: Lo, T.-C.; Lee, C.-Y.; Chen, C.-L.; Hsieh, T.-Y.; Chen, C.-H.; Lin,
> Y.-K. *Application of Machine Learning Models for Baseball Outcome
> Prediction.* Appl. Sci. 2025, 15, 7081. DOI: 10.3390/app15137081.
> Source file in this KB: extracted plain text of the article (MDPI HTML
> export, ~59 KB).

## 1. Topic Summary (one paragraph)

This is a peer-reviewed applied-ML study that builds **supervised classifiers**
to predict the per-game **Win/Loss (W/L) outcome** of regular-season games in
the **Chinese Professional Baseball League (CPBL)**, 2021–2023. The authors
collect 859 distinct games (1738 W/L team-records after dropping 31 tied
games) from the official CPBL site and **Baseball Rebas Data Company** —
the same data source used by our final-project pipeline. They engineer **21
batter-side + 16 pitcher-side features**, including classic counting stats
(AB, H, BB, SO, ...) and **advanced sabermetrics** (wOBA, wRAA, wRC+, FIP,
WHIP, PLOB%, BABIP, H/9, K/9). Six models — Decision Tree, Logistic
Regression, ANN, Random Forest, XGBoost, LightGBM — are tuned with grid
search inside **5-fold cross-validation**, evaluated on seven metrics
(accuracy, F1, sensitivity, specificity, PPV, NPV, AUC-ROC), and then
opened up with **feature-importance + SHAP** to identify which inputs
drive predictions. Logistic Regression and XGBoost win, hitting 0.91 mean
accuracy and 0.97 AUC. SHAP highlights **wRC+, PLOB%, wRAA, WHIP** as the
most influential predictors, supporting the practical thesis that
**combining interpretable ML with sabermetrics** gives coaches and
analysts a usable lens on CPBL outcomes.

## 2. Outline / Section Structure (hierarchical bullets)

- **Front matter / Abstract / Keywords**
  - Goal: build & evaluate ML models for CPBL outcome prediction.
  - 859 games, 2021–2023, both traditional and sabermetric features.
  - Five-fold CV; LR and XGBoost dominate; SHAP picks wRC+ and PLOB%.
- **1. Introduction**
  - Big Data and AI/ML in sports analytics (Moneyball motif).
  - Brief survey of prior work on baseball/basketball/football outcome
    prediction (ANN, LR, SVM, decision trees, 1D-CNN).
  - The accuracy-vs-interpretability trade-off; motivation for
    **Explainable AI (XAI)**, esp. **SHAP**.
- **2. Method**
  - 2.0 Pipeline: data → preprocessing → training (5-fold CV) → metrics
    → SHAP interpretation (Figure 1 block diagram).
  - 2.0a **Data**: official CPBL + Baseball Rebas; 900 → 859 games after
    dropping ties; binary W/L target; 21 batter + 16 pitcher features
    (Table 1).
  - 2.1 **Machine Learning Methods**: DT, LR, ANN (1 hidden layer, 64
    units, ReLU, dropout 0.3, Adam, cross-entropy), RF, XGBoost,
    LightGBM.
  - 2.1a **Hyperparameter Tuning**: grid search inside 5-fold CV; per-model
    search spaces (Table 2).
  - 2.2 **Evaluation Metrics**: accuracy, F1, sensitivity (recall),
    specificity, PPV, NPV, AUC-ROC, plus running time. AUC bands:
    excellent ≥ 0.90, good 0.80–0.90, fair 0.70–0.80, poor 0.60–0.70.
- **3. Results**
  - 3.0 Model comparison table (Table 3): per-fold and mean scores.
  - 3.1 ROC curves (Figure 2): LR 0.970, XGB 0.968, LGBM 0.968, RF 0.962,
    ANN 0.943, DT 0.850.
  - 3.2 **Feature importance** (XGBoost, Figure 3 / Table 4): wRC+ 0.21,
    PLOB% 0.11, wRAA 0.10, WHIP 0.06, wOBA 0.05, H9 0.05, OPS 0.05,
    FIP 0.04, P_HR 0.03, OBP/AVG 0.02 …
  - 3.3 **SHAP summary plot** (Figure 4): per-instance contributions,
    direction (positive → win), magnitude.
  - 3.4 **SHAP dependence plots** (Figure 5a/b): wRAA × PLOB%, wRC+ × WHIP
    interaction effects.
- **4. Discussion**
  - Why XGBoost / RF / LR work well on this structured tabular problem.
  - Deep dives on top features: wRC+, wRAA, wOBA, PLOB%, FIP — what they
    mean, why they predict winning, prior literature support.
  - Coaching takeaways: optimize lineups by wRC+; deploy high-PLOB%
    pitchers in pressure innings.
- **5. Limitations & Future Work**
  - Data quality dependence; opacity of ensembles; CPBL-only training
    limits transferability; no external validation; no SHAP interaction
    values / PDP / ICE; suggest time-series / RNN extensions and
    cross-league evaluation.
- **References (39 entries)** — sabermetrics texts, prior ML-for-sport
  papers, SHAP/XAI papers.

## 3. Key Concepts (paraphrased)

- **Target variable**: per-team game outcome **Win/Loss** as a binary
  label. Tied games are dropped to keep the problem binary.
- **Sabermetric features used in the paper** (paraphrased glossary):
  - **wOBA** (weighted on-base average): linear-weighted version of OBP
    that gives each on-base event its run value; ~9.9% importance.
  - **wRAA** (weighted runs above average): runs a hitter contributes
    above league average; depends on plate appearances.
  - **wRC+** (weighted runs created plus): wOBA-based, park- and
    league-adjusted run-creation rate. **Top predictor** (importance 0.21
    in XGBoost). Lets you compare players across eras / parks.
  - **FIP** (fielding-independent pitching): pitcher quality estimated
    only from K, BB, HR — isolates defense.
  - **WHIP** (walks + hits per inning pitched): baserunners allowed per
    inning; a control-of-baserunners metric.
  - **PLOB%** (pitcher left-on-base %): share of allowed runners stranded
    (excluding HR). High PLOB% ⇒ pitcher escapes jams. **#2 feature** by
    SHAP and importance.
  - **BABIP, H/9, K/9, B/9, G/F, NP/IP** also collected.
- **Big-Data / ML framing**: classical statistics emphasizes causal
  inference; ML prioritizes predictive accuracy, often at the cost of
  interpretability. XAI is the bridge.
- **XAI taxonomy** (citing Linardatos et al. 2020): intrinsic
  interpretability, model-to-model interpretability, and post-hoc
  interpretability. SHAP is post-hoc.
- **SHAP** (SHapley Additive exPlanations): game-theoretic per-feature
  attribution; positive SHAP value → pushes prediction toward "win",
  negative → toward "loss"; supports both global (summary plot) and local
  (per-game) explanations.
- **5-fold cross-validation**: data partitioned 5 ways; each model
  trained 5× on 4 folds and scored on the held-out 1 fold; metrics
  reported as fold-wise + mean for fairness across models.
- **Class imbalance not strongly emphasized** in this paper because each
  game contributes a win-row and a loss-row, yielding a near-balanced
  binary problem; still, AUC is recommended for robustness.
- **Accuracy vs. interpretability trade-off**: ensembles (XGB, LGBM, RF)
  are accurate but opaque; decision trees are transparent but weaker.
  The paper resolves this by *using XGBoost for prediction and SHAP for
  explanation* rather than picking only one or the other.

## 4. Methods & Algorithms

### 4.1 Decision Tree (DT)

- **When used**: baseline classifier; cheap to train; high transparency.
- **Idea**: recursive binary splits on feature values; leaves carry the
  predicted class.
- **Hyperparameters** (final): `criterion='gini'`, `max_depth=5`,
  `min_samples_split=10`. Search grid: `max_depth ∈ {3,5,7,10}`,
  `min_samples_split ∈ {2,5,10,20}`.
- **sklearn**: `DecisionTreeClassifier(criterion='gini', max_depth=5,
  min_samples_split=10)`.
- **Caveats**: prone to overfit if unpruned; single trees are unstable
  across folds (see DT row of Table 3 — accuracy 0.84–0.86).

### 4.2 Logistic Regression (LR)

- **When used**: linear baseline; surprisingly strong on this dataset
  (best AUC = 0.970).
- **Math**: `P(y=1 | x) = sigmoid(w · x + b)` with cross-entropy /
  log-loss; L2 penalty `||w||_2^2`.
- **Hyperparameters**: `penalty='l2'`, `solver='lbfgs'`, `max_iter=1000`;
  inverse regularization strength `C ∈ {0.001, 0.01, 0.1, 1, 10}`.
- **sklearn**:
  `LogisticRegression(penalty='l2', solver='lbfgs', max_iter=1000, C=...)`.
- **Caveats**: assumes (roughly) linear log-odds in features; benefits
  greatly when inputs are scaled and predictive sabermetrics (wRC+,
  wRAA) already capture most of the signal in linear form.

### 4.3 Artificial Neural Network (ANN)

- **When used**: nonlinear classifier; tested whether deep representations
  help on this fairly small tabular dataset.
- **Architecture (final)**: 3 layers — input, **64-unit hidden layer with
  ReLU**, output. **Dropout = 0.3** for regularization. Loss =
  binary cross-entropy. Optimizer = Adam.
- **Hyperparameters**: `learning_rate ∈ {0.001, 0.01}`,
  `batch_size ∈ {32, 64}`, up to 50 epochs, early stopping
  patience = 10.
- **Keras-ish snippet** (paraphrased from the paper's description):
  ```python
  model = Sequential([
      Dense(64, activation='relu', input_shape=(n_features,)),
      Dropout(0.3),
      Dense(1, activation='sigmoid'),
  ])
  model.compile(optimizer=Adam(lr), loss='binary_crossentropy')
  ```
- **Caveats**: highest sensitivity (recall up to 0.96) but lowest
  specificity (as low as 0.75) — tends to **over-predict wins**. Also
  the slowest model: mean run time 46.8 s, vs. DT 0.2 s.

### 4.4 Random Forest (RF)

- **When used**: bagged ensemble of decision trees; strong, robust,
  somewhat interpretable via mean-decrease-in-impurity feature scores.
- **Idea**: bootstrap samples + random feature subset at each split;
  majority-vote / averaged probability.
- **Hyperparameters (final)**: `n_estimators=100`, `max_depth=10`,
  `min_samples_split=10`, `bootstrap=True`. Grid: `n_estimators
  ∈ {100, 200}`, `max_depth ∈ {5, 10, 15}`, `min_samples_split
  ∈ {2, 10}`.
- **sklearn**: `RandomForestClassifier(n_estimators=100, max_depth=10,
  min_samples_split=10, bootstrap=True, random_state=...)`.
- **Caveats**: ensemble obscures individual decision paths; feature
  importance can be biased toward high-cardinality features, so SHAP is
  preferred for the final analysis.

### 4.5 XGBoost (Extreme Gradient Boosting)

- **When used**: high-performance gradient-boosted-tree classifier; the
  paper's interpretability flagship (SHAP runs on this model).
- **Idea**: sequentially fit trees to the gradient of the loss with
  respect to the current ensemble's prediction; add regularization on
  tree complexity. Loss minimized:
  `L(phi) = sum_i loss(y_i, y_hat_i) + sum_k Omega(f_k)`
  where `Omega(f) = gamma * T + 0.5 * lambda * ||w||^2` penalizes the
  number of leaves `T` and the leaf-weight magnitude `w`.
- **Hyperparameters (final)**: `n_estimators=100`, `max_depth=6`,
  `learning_rate=0.1`, `subsample=0.8`, `colsample_bytree=0.8`. Grid:
  `learning_rate ∈ {0.01, 0.1, 0.2}`, `max_depth ∈ {3, 6, 9}`,
  `subsample, colsample_bytree ∈ {0.6, 0.8, 1.0}`,
  `reg_alpha, reg_lambda ∈ {0, 0.1, 1}`. Early stopping on the
  validation fold.
- **Python**:
  `xgboost.XGBClassifier(n_estimators=100, max_depth=6, learning_rate=0.1,
  subsample=0.8, colsample_bytree=0.8, ...)`.
- **Caveats**: opaque; SHAP needed for explanation. The authors also
  note that XGBoost beats neural nets on small/medium structured data
  (Wu et al., 2021).

### 4.6 LightGBM

- **When used**: speed-optimized gradient boosting; same role as XGB but
  faster on larger / leaf-wise growth.
- **Hyperparameters (final)**: `n_estimators=100`, `learning_rate=0.1`,
  `num_leaves=31`, `max_depth=-1`. Grid: `num_leaves ∈ {31, 63}`,
  `max_depth ∈ {-1, 5, 10}`, early stopping.
- **Python**: `lightgbm.LGBMClassifier(n_estimators=100,
  learning_rate=0.1, num_leaves=31, max_depth=-1, ...)`.
- **Caveats**: leaf-wise growth can overfit small datasets — limit
  `num_leaves` and use early stopping.

### 4.7 Evaluation Metrics

Concise formulas (paraphrased):

- **Accuracy** = `(TP + TN) / (P + N)`
- **F1** = `2 · Precision · Recall / (Precision + Recall)`
- **Sensitivity (Recall, TPR)** = `TP / (TP + FN)`
- **Specificity (TNR)** = `TN / (TN + FP)`
- **PPV (Precision)** = `TP / (TP + FP)`
- **NPV** = `TN / (TN + FN)`
- **AUC-ROC**: area under the ROC curve; 0.5 = chance, 1.0 = perfect.

AUC interpretation bands the paper uses: excellent 0.90–1.00, good
0.80–0.90, fair 0.70–0.80, poor 0.60–0.70, failing < 0.60.

### 4.8 SHAP (Post-hoc Interpretation)

- **When used**: applied to the best model (XGBoost) to attribute each
  feature's contribution to each prediction.
- **Math**: feature-level Shapley value
  `phi_j = sum_{S subset N \ {j}} [|S|! (|N|-|S|-1)! / |N|!] · (v(S ∪ {j}) − v(S))`
  where `v(S)` is the prediction of the model using only the features
  in `S`.
- **Outputs used**:
  - **SHAP summary plot** (Figure 4): each row = feature, dots = games,
    colored by feature magnitude (red = high, blue = low), x = SHAP value.
  - **SHAP dependence plots** (Figure 5): pairwise interactions e.g.
    wRAA × PLOB%, wRC+ × WHIP.
- **Python**:
  ```python
  import shap
  explainer = shap.TreeExplainer(xgb_model)
  shap_values = explainer.shap_values(X)
  shap.summary_plot(shap_values, X)
  shap.dependence_plot('wRAA', shap_values, X, interaction_index='PLOB%')
  ```
- **Caveats**: only main + pairwise effects shown; the authors flag that
  full **SHAP interaction values** and PDP / ICE could be added in
  future work. SHAP also assumes feature-additivity for `g`; correlated
  features can spread credit ambiguously.

## 5. Code Snippets (short, well-attributed)

The paper itself does not embed code blocks in the running text; the
full implementation is released as a Google Colab notebook
(<https://colab.research.google.com/drive/1iDYo5dIUSGOva0m1e4t9C1ADef1u2PFl?usp=sharing>).
Based on the described pipeline, equivalent Python sketches are:

```python
# Five-fold CV evaluation harness (paraphrased)
from sklearn.model_selection import StratifiedKFold, cross_validate
from sklearn.metrics import make_scorer, f1_score, roc_auc_score

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
scoring = {
    'acc': 'accuracy',
    'f1':  'f1',
    'auc': 'roc_auc',
    'recall': 'recall',
}
results = cross_validate(model, X, y, cv=cv, scoring=scoring)
```

```python
# Grid search inside 5-fold CV (e.g. XGBoost)
from sklearn.model_selection import GridSearchCV
import xgboost as xgb

param_grid = {
    'n_estimators':     [100, 200],
    'learning_rate':    [0.01, 0.1, 0.2],
    'max_depth':        [3, 6, 9],
    'subsample':        [0.6, 0.8, 1.0],
    'colsample_bytree': [0.6, 0.8, 1.0],
    'reg_alpha':        [0, 0.1, 1],
    'reg_lambda':       [0, 0.1, 1],
}
gs = GridSearchCV(xgb.XGBClassifier(objective='binary:logistic'),
                  param_grid, scoring='roc_auc', cv=5, n_jobs=-1)
gs.fit(X_train, y_train)
```

```python
# Post-hoc explanation
import shap
explainer = shap.TreeExplainer(gs.best_estimator_)
shap_values = explainer.shap_values(X_test)
shap.summary_plot(shap_values, X_test)
```

## 6. Notable Examples or Datasets used in the lecture

- **Primary dataset**: CPBL regular-season games **2021–2023**, scraped
  from the official CPBL website **and Baseball Rebas Data Company**.
  Initial 900 games → 859 after removing 31 ties → **1738 team-game
  rows** (each game contributes a winner row and a loser row).
- **Features** (Table 1):
  - **Batter side (21)**: AB, R, RBI, 1B, 2B, 3B, HR, H, BB, SO, SH, SF,
    AVG, OBP, SLG, OPS, IsoP, G/F, wOBA, wRAA, wRC+.
  - **Pitcher side (16)**: BF, NP, Strike, P_H, P_HR, P_BB, P_SO, B/9,
    H/9, K/9, S%, BABIP, WHIP, G/F, NP/IP, PLOB%.
  - **Target**: W/L (binary).
- **Final model leaderboard** (mean across 5 folds, Table 3):
  - LR: acc 0.91, AUC 0.97, 1.9 s
  - XGB: acc 0.91, AUC 0.97, 0.9 s
  - LGBM: acc 0.90, AUC 0.97, 1.0 s
  - RF: acc 0.90, AUC 0.96, 2.4 s
  - ANN: acc 0.87, AUC 0.95, 46.8 s
  - DT: acc 0.85, AUC 0.85, 0.2 s
- **Feature-importance top-10 from XGBoost** (Table 4):
  1. wRC+ (0.21)
  2. PLOB% (0.11)
  3. wRAA (0.10)
  4. WHIP (0.06)
  5. wOBA (0.05)
  6. H/9 (0.05)
  7. OPS (0.05)
  8. FIP (0.04)
  9. P_HR (0.03)
  10. OBP (0.02)
- **SHAP dependence highlights** (Figure 5):
  - wRAA × PLOB%: offensive value is *moderated by* the team's ability
    to strand opposing baserunners — a strong "interaction" finding.
  - wRC+ × WHIP: high wRC+ pays off more when WHIP is low (good pitching).
- **External comparisons** in the literature review: prior MLB / NBA /
  NFL studies with LR (~61–69%), ANN (72–94%), DT (~78%), SVM (~60–69%).

## 7. Pitfalls / common mistakes mentioned

- **Tied games** must be removed for binary classification — they are
  not a third class, but they would silently degrade an accuracy metric.
- **OPS = OBP + SLG arithmetic sum** is criticized as a *naïve* combined
  metric that ignores the relative run-values of each event type. wOBA
  is preferred.
- **Accuracy alone is misleading** for skewed or borderline-balanced
  datasets — use **F1, AUC, sensitivity, specificity, PPV, NPV** as
  well. The authors flag AUC as the primary metric.
- **Black-box models** (RF, XGB, ANN, LGBM) can hide their reasoning;
  the paper invests in SHAP explicitly because coaches need to *trust*
  recommendations.
- **ANN trade-off**: high recall came with poor specificity and 200× the
  decision-tree's runtime — accuracy gain may not be worth deployment
  cost.
- **Data quality**: missing or noisy game records degrade ensemble
  performance more than simple linear models (since trees can latch
  onto spurious splits).
- **No external validation**: 5-fold CV inside the same 2021–2023 CPBL
  data does not prove generalization to 2024+ or to KBO/MLB; transfer
  learning recommended.
- **No SHAP interaction values, PDP, or ICE** were used — main-effect
  SHAP can miss conditional dependencies among correlated sabermetrics.

## 8. Cross-references (other topics / files mentioned)

- **`topic05-2_featureExplain.md`** — LIME & SHAP foundations (Shapley
  values, additive-attribution framework, Kernel SHAP pseudo-code).
- **`topic05-1_PCA-SVD.txt` / `topic05_featureReduction.txt`** — for
  dimensionality reduction that complements feature-importance ranking.
- **`topic07_data.txt`** — data-collection / preprocessing playbook
  relevant to the CPBL → JSON ingestion stage.
- **`topic08_unsupervised.txt`** — clustering / dim-reduction methods
  that we'll actually use; this paper is **supervised**, so it serves as
  a *feature-discovery oracle* rather than a methodological template.
- **`topic09_supervised1_mem.txt`** — supervised-learning fundamentals
  (DT, LR, RF, XGB, evaluation metrics) appear in lecture form there.
- **Senior Wang's 2024 CPBL analysis** — rule-based labels + supervised
  models; his top-consensus features (`run_per_hit`, `innings_pitched`,
  `H`, `scored_first`, `whip_like`, `hr_allowed`, `hits_allowed`, `AB`,
  `middle_runs`, `late_runs`) overlap with this paper's pitching focus
  (WHIP-like, hits-allowed, HR-allowed) and offensive efficiency (AB,
  run_per_hit ↔ wRC+/wRAA in concept).
- **External library docs**: `xgboost`, `lightgbm`, `sklearn`, `shap`.
- **Sabermetric background**: Tango et al. "The Book" (linear weights →
  wOBA); FanGraphs glossary for wRC+, FIP, PLOB%.

## 9. Relevance to CPBL unsupervised feature discovery (max 5 bullet lines)

- This paper validates that **wRC+, PLOB%, wRAA, WHIP, wOBA, FIP, H/9,
  OPS** carry most of the W/L signal on CPBL 2021–2023 — use them as
  prime candidates for PCA inputs, cluster axes, and feature-engineering
  targets when preprocessing our 2023+2024 rebas.tw JSON.
- Senior Wang's consensus list maps almost 1-to-1 onto this paper's
  top-10: `whip_like ↔ WHIP`, `hr_allowed ↔ P_HR`, `hits_allowed ↔ H/9`,
  `H/AB ↔ run_per_hit`-style ratios, `innings_pitched` underlies WHIP
  and FIP — so we can confidently keep those engineered features and
  add **wRC+ / wRAA approximations** even in our unsupervised pass.
- Methodologically the paper is *supervised*, but its **SHAP rankings
  function as an interpretable "feature importance prior"** we can use
  to weight PCA loadings, validate cluster meanings, or filter the
  starting feature set before k-means / Gaussian mixture clustering.
- The SHAP **interaction findings (wRAA × PLOB%, wRC+ × WHIP)** suggest
  that offense-only or pitching-only clusters will be misleading; our
  unsupervised model should keep both offensive and pitching dimensions
  and possibly engineer interaction terms (e.g. `wRC_x_WHIP`,
  `run_per_hit / whip_like`).
- Data-sourcing parity: both we and they use **Baseball Rebas** data —
  field definitions and variable scales should be directly comparable,
  reducing preprocessing risk; just remember to **drop tied games** and
  build per-game team-rows in the same fashion.
