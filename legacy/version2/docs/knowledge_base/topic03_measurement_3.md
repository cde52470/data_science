# Topic 03 — Measurement Part 3: How to Evaluate Model Output

## 1. Topic Summary

This lecture (by Prof. Jia-Ming Chang, NCCU CS) is the third instalment of the
"measurement" thread in the Data Science course. It systematically surveys the
different families of evaluation metrics used in supervised and unsupervised
learning, organised by the **type of model output**:

- Classification (hard labels): accuracy, precision, recall, F1, sensitivity,
  specificity, false-positive rate, type I / type II errors, micro vs. macro
  averages.
- Scoring / Regression (real-valued output): residuals, MAE / relative MAE,
  RMSE, RSS / TSS, R^2, Pearson correlation.
- Probability estimation (output in [0,1]): double-density plot, ROC-AUC,
  PR-AUC (AUPRC), log-likelihood, deviance, pseudo-R^2, AIC, binary
  cross-entropy (BCE) / Bernoulli likelihood.
- Ranking: Spearman's rank correlation coefficient.
- Clustering: internal indices (Silhouette, Calinski-Harabasz, intra- vs.
  inter-cluster distances) and external indices (Normalized Mutual
  Information / NMI), illustrated with synthetic R `kmeans` runs.

A recurring theme is that no single number is "the right answer": metric
choice has to follow the **business / domain cost** of each error type
(spam filter vs. tumour detection vs. COVID-19 sieve, "hair" vs. "waste"
clusters, etc.). Prevalence (class imbalance) and the cost asymmetry between
type I and type II errors drive the decision between ROC-AUC and PR-AUC and
between precision-heavy and recall-heavy thresholds. The lecture also
introduces the language ("inference vs. prediction", "estimate f") used in
ISLR Ch. 2 to motivate why we even bother evaluating.

The lecture closes with a clustering tour (since the CPBL final project
ends in unsupervised feature discovery), framing both "without labels"
(internal) and "with labels" (external) evaluation, and pointing forward to
`topic08_unsupervised.pptx` for deeper coverage.

## 2. Outline / Section Structure

1. **Copyright / Recap** — Materials drawn from *ISLR* (James et al., 2013),
   *Practical Data Science with R* (Zumel & Mount, Manning 2019), and
   *R for Data Science*. Quick recap of last week: R operators (`<-` vs. `=`,
   `&` vs. `&&`), primary R types, Git/GitHub for code management,
   `code03.zip` example bundle.
2. **Today's plan** — Cha. 05 of *Practical Data Science with R*
   ("Choosing and evaluating models") and Cha. 02 of *ISLR* ("Statistical
   Learning").
3. **Schematic model construction and evaluation** — model evaluation as
   quantifying performance aligned to the business goal; classification
   uses precision / recall, scoring uses RMSE, probability tasks need
   probabilistic metrics.
4. **Model evaluation and critique** — "is it accurate enough?", "does it
   beat the obvious guess?", "do coefficients / clusters make sense?".
5. **The accuracy of the Model** — Why estimate f? Inference vs. prediction
   (Advertising data: which medium drives sales?).
6. **Evaluating models** by output type:
   - Classification, scoring, probability, ranking, clustering.
   - Regression (quantitative) vs. classification (qualitative).
7. **Evaluating classification models**
   - Confusion matrix (R example: decision tree on German Credit Data
     `GCDData.RData`, `rpart` `Good.Loan` model).
   - TP / FP / TN / FN definitions, accuracy, precision, recall, FPR.
   - Spam logistic regression example (`spamD.tsv`, `glm` with `binomial`
     link, `spamExam.R`).
   - Threshold tuning trades precision for recall (`pred > 0.9` vs. `> 0.1`).
   - The F1 score and the Akismet-filter example.
   - Accuracy is misleading for unbalanced classes (null model never
     predicts the rare event but is "accurate").
   - Sensitivity = TPR = recall; Specificity = TNR.
   - Type I / II errors, related to sensitivity / specificity, with bilingual
     glossary (信心水平, 檢定強度).
8. **Covid-19 general sieve (April 2020)** — prevalence-dependent vs.
   prevalence-independent metrics; HIV diagnostic worked example showing
   how PPV collapses to 15.4% at 1% prevalence even with 90% sensitivity /
   95% specificity. Includes Taiwan-specific discussion of PPV = 0.4865
   under low prevalence and PCR vs. rapid-test precision.
9. **Multi-class classification** —
   `sklearn.metrics.classification_report`; turning a K-class confusion
   matrix into K binary confusion matrices and averaging via micro vs.
   macro.
10. **Evaluating scoring models**
    - Residuals (`residual.R` plotting residual segments with `ggplot2`).
    - Absolute error, mean absolute error, relative absolute error
      (with the cautionary 3-purchase example $0/$0/$25).
    - MSE, RMSE, RSS, TSS.
    - R^2 / coefficient of determination — ratio of error to total variance;
      under squared-error loss in linear regression, R^2 equals the squared
      Pearson correlation of true vs. predicted.
    - Pearson correlation r ignores shifts and scale; correlation of 0.8
      gives R^2 = 0.64 < 0.7 target.
11. **Evaluating probability models**
    - Double-density plot of predicted probabilities split by label.
    - ROC curve (TPR vs. FPR) and ROC-AUC = probability that a random
      positive ranks above a random negative. R example uses package
      `ROCR`.
    - Threshold selection on ROC: Youden's J (max TPR - FPR), closest to
      (0,1), max F1.
    - PR-AUC (AUPRC): precision vs. recall. Baseline = prevalence.
    - ROC vs. AUPRC — under heavy class imbalance ROC is optimistic,
      AUPRC is robust. Example: 1% positives, AUC = 0.95 but precision
      ~0.1.
    - Caveat from Hand (2009) — ROC-AUC is not a fully coherent measure.
    - Log-likelihood: sum of logs of probability assigned to the actual
      class; 0 = perfect; comparison with null-model log-likelihood for
      spam (-134.95 vs. -306.90).
    - Binary Cross-Entropy (BCE) / Bernoulli PMF $f(y;p)=p^{y}(1-p)^{1-y}$.
    - Deviance = -2(logL - S); pseudo-R^2 = 1 - deviance(model)/deviance(null).
    - AIC = deviance + 2k (parameter penalty); smaller is better.
12. **Evaluating ranking models** — Spearman's rank correlation coefficient
    on assigned ranks treated as a numeric score.
13. **Evaluating clustering models**
    - Notional customer-segmentation example.
    - R demo `clusterModel.R`: random 2-D points clustered with `kmeans`,
      `chull` for cluster hulls, `ggplot2` for visualisation.
    - "Hair clusters" (too small) and "waste clusters" (too large) as
      diagnostics.
    - Internal vs. external validation framework.
14. **Internal metrics** — intra-cluster distance ↓, inter-cluster distance
    ↑; introduced via `dcast` of pairwise-distance matrix; named metrics:
    **Silhouette** (1987, range -1..1) and **Calinski-Harabasz** (1974).
15. **External metrics** —
    - Normalized Mutual Information (NMI) defined via Mutual Information
      $I(Y;C) = H(Y) - H(Y|C)$ and entropies of the label and cluster
      partitions; R package `aricode`.
    - NMI is invariant to label permutation, normalised across different
      number of clusters; range 0..1.
16. **Looking ahead** — Pointers to *topic08_unsupervised.pptx* for
    deeper coverage of cluster validation; references to benchmark Tables
    in Genome Biology and IEEE for "when is each method best?".

## 3. Key Concepts

- **Inference vs. Prediction**: inference asks which predictors matter and
  in what shape (linear / non-linear); prediction asks how well y_hat
  approximates y. The same model can serve either purpose, but the
  evaluation metric should follow the question.
- **Confusion matrix terminology**: row = actual class, column = predicted
  class; diagonal = correct calls. For binary problems we tag entries TP,
  FP, FN, TN relative to a designated "positive" class.
- **Accuracy = (TP+TN)/(TP+TN+FP+FN)**. Useless when the base rate is very
  imbalanced — a "null model" that always predicts the majority class can
  reach high accuracy while being useless.
- **Precision = TP/(TP+FP)** ("when I say yes, how often am I right?");
  **Recall = TP/(TP+FN)** ("of the actual positives, how many did I catch?").
  Precision = confirmation; recall = utility.
- **Sensitivity vs. Specificity**: Sensitivity = TPR = Recall; Specificity
  = TNR = TN/(TN+FP). Null classifiers always zero one or the other.
- **Type I (false-positive) vs. Type II (false-negative) errors**: which
  one matters more depends on cost (spam — type I worst because real mail
  is lost; tumour — type II worst because missing a tumour is fatal).
- **PPV vs. NPV** (positive / negative predictive value): unlike
  sensitivity / specificity, these depend on prevalence. The COVID-19 /
  HIV worked examples show that low prevalence can drive PPV down even for
  excellent tests.
- **F1 score**: harmonic mean of precision and recall; preferred summary
  when both matter and classes are unbalanced.
- **Micro vs. macro averaging**: in multi-class, micro pools all
  per-class TPs/FPs/FNs before computing the metric (favours frequent
  classes), macro computes the metric per class and averages (treats
  classes equally).
- **Residual = y - y_hat**. Errors aggregate into MAE, MSE, RMSE.
- **R^2** = 1 - RSS/TSS; under squared-error loss and the right model
  class, equal to the square of Pearson r between y and y_hat. Pearson r
  is invariant to shift and scale, so r ≈ 0.8 still leaves 36% of
  variance unexplained.
- **ROC-AUC**: probabilistic interpretation = chance a random positive
  scores above a random negative. Baseline 0.5 = random; 1.0 = perfect.
- **PR-AUC (AUPRC)**: average precision across recall thresholds.
  Baseline = prevalence; preferred under class imbalance because it
  punishes false positives directly.
- **Threshold tuning**: Youden's J = arg max (TPR - FPR), closest-to-(0,1)
  on ROC, max-F1 on PR; choice driven by error cost asymmetry.
- **Log-likelihood / deviance / pseudo-R^2 / AIC** — a hierarchy of
  probability-aware scores. Deviance is unnormalised (only comparable on
  the same data); AIC adds a parameter penalty.
- **Spearman's rank correlation** — evaluates monotone agreement; the
  go-to metric when the model's job is to order rows rather than to
  predict exact values.
- **Clustering validation**:
  - Internal — minimise intra-cluster distance, maximise inter-cluster
    distance. Silhouette s_i = (b_i - a_i)/max(a_i, b_i) with a_i =
    average intra-cluster distance for point i and b_i = average
    nearest-other-cluster distance. Calinski-Harabasz uses the ratio of
    between- to within-cluster dispersion.
  - External — measure agreement with a ground-truth partition; NMI
    normalises mutual information by the entropies of the partitions.
    NMI is permutation-invariant, so cluster labels need not match
    class labels for the score to be 1.

## 4. Methods & Algorithms

| Method | When | Math / Idea | Python | Caveats |
|---|---|---|---|---|
| Accuracy | Roughly balanced classes; cheap sanity check | $(TP+TN)/N$ | `sklearn.metrics.accuracy_score` | Useless under imbalance; null model can beat it. |
| Precision | False-positive cost dominates (spam, fraud accusation) | $TP/(TP+FP)$ | `sklearn.metrics.precision_score` | Undefined when no positives are predicted; sensitive to threshold. |
| Recall / Sensitivity / TPR | False-negative cost dominates (tumour, leak detection) | $TP/(TP+FN)$ | `sklearn.metrics.recall_score` | Can be inflated by predicting positive for all. |
| Specificity / TNR | Need a measure mirroring recall on negatives | $TN/(TN+FP)$ | `1 - FPR`; manual from confusion matrix | Inflated in multi-class one-vs-rest because TN is huge. |
| F1 | Want a single number balancing P & R; imbalanced classes | $2PR/(P+R)$ | `sklearn.metrics.f1_score` | Treats P and R equally; for unequal cost use $F_\beta$. |
| Confusion matrix | Always — for any classifier | $C_{ij}$ = #(actual i, predicted j) | `sklearn.metrics.confusion_matrix` | Choose positive class explicitly; for multi-class examine off-diagonals. |
| PPV / NPV | Reporting clinical / screening usefulness | $TP/(TP+FP)$ / $TN/(TN+FN)$ | Manual from confusion matrix | Prevalence-dependent; same test gives very different PPV at 1% vs. 50% prevalence. |
| Multi-class report (micro/macro) | $\geq 3$ classes | One-vs-rest binary matrix per class, then aggregate | `sklearn.metrics.classification_report` | Micro favours frequent classes; macro can over-reward rare classes; specificity is inflated due to large TN. |
| MAE / RMSE | Regression / scoring | $MAE=\frac{1}{N}\sum|e_i|$, $RMSE=\sqrt{\frac{1}{N}\sum e_i^{2}}$ | `mean_absolute_error`, `mean_squared_error` (sqrt) | RMSE punishes large errors; MAE is robust. Don't make a single MAE the project goal blindly. |
| Relative absolute error | Cross-dataset comparison | $\sum|e_i|/\sum|y_i|$ | Manual | Breaks when $\sum|y_i|$ ≈ 0. |
| Pearson correlation r | Shape-of-fit on continuous y | $r=\frac{\sum(x-\bar x)(y-\bar y)}{\sqrt{\sum(x-\bar x)^{2}\sum(y-\bar y)^{2}}}$ | `np.corrcoef`, `scipy.stats.pearsonr` | Ignores shift & scale; r=0.8 only explains 64% of variance. |
| R^2 | Linear regression goodness-of-fit | $R^{2} = 1 - RSS/TSS$; under sq. loss = $r^{2}$ | `sklearn.metrics.r2_score` | Can be negative for non-linear models; depends on test set. |
| Double density plot | Visual diagnostic for probability classifiers | Density of predicted score, faceted by true label | `seaborn.kdeplot(..., hue=label)` | Needs enough positives in each bin; can mask multi-modality. |
| ROC-AUC | Ranking quality, balanced or mildly imbalanced | Area under TPR-vs-FPR curve | `sklearn.metrics.roc_auc_score`, `roc_curve` | Optimistic under heavy imbalance; not a coherent loss (Hand 2009). |
| PR-AUC (AUPRC) | Rare-positive problems (TF binding, disease genes, fraud) | Area under precision-vs-recall curve | `sklearn.metrics.average_precision_score` | Baseline = prevalence; can differ a lot between train and deploy if prevalence shifts. |
| Youden's J threshold | Need single operating point on ROC | $J^{*} = \arg\max_{t}(TPR(t) - FPR(t))$ | Loop over thresholds returned by `roc_curve` | Ignores cost asymmetry. |
| Max-F1 threshold | Balance precision & recall under imbalance | $t^{*} = \arg\max_{t} F1(t)$ | `precision_recall_curve` then F1 sweep | Selecting threshold on test set leaks information; use CV. |
| Log-likelihood | Calibration-aware comparison | $LL=\sum_i y_i \ln p_i + (1-y_i)\ln(1-p_i)$ | `sklearn.metrics.log_loss` (= -LL/N) | Penalises confident wrong predictions infinitely if $p_i \in \{0,1\}$; clip probabilities. |
| Binary cross-entropy (BCE) | Probability classifier loss / metric | $-\frac{1}{N}\sum [y\ln p + (1-y)\ln(1-p)]$ | `sklearn.metrics.log_loss`, `tf.keras.losses.BinaryCrossentropy` | Same caveat as LL; ensure outputs are probabilities, not logits. |
| Deviance | Model comparison on same data | $D = -2(LL - LL_{sat})$ | Manual; `statsmodels` GLM has `.deviance` | Unnormalised — only compare on identical datasets. |
| Pseudo-R^2 | "R^2-like" summary for probability models | $1 - D_{model}/D_{null}$ | Manual from log-likelihoods | Several variants exist (McFadden, Cox-Snell, Nagelkerke); document which one. |
| AIC | Model selection with differing complexity | $\textit{deviance} + 2k$ | `statsmodels` `.aic`, `sklearn` not direct | Prefers complex models with weak data; consider BIC too. |
| Spearman's rho | Ranking models | Pearson r on ranks of y vs. y_hat | `scipy.stats.spearmanr` | Ties handled differently across libs; rank correlation hides magnitude errors. |
| Silhouette | Internal clustering; choosing k | $s_i = (b_i - a_i)/\max(a_i, b_i)$, $\bar s$ over all i | `sklearn.metrics.silhouette_score` | O(n^2) distances; for large data use sampling. |
| Calinski-Harabasz | Internal clustering; pick k | $CH = \frac{tr(B_k)/(k-1)}{tr(W_k)/(n-k)}$ | `sklearn.metrics.calinski_harabasz_score` | Tends to favour higher k; assumes convex clusters. |
| Intra/Inter distance table | Quick diagnostic; small k | Mean pairwise Euclidean distance per (cluster, cluster) | `pandas.pivot_table` on long-format pair distances | O(n^2); cluster ordering depends on rng. |
| Normalised Mutual Information (NMI) | External clustering with ground truth | $NMI = I(Y;C)/\sqrt{H(Y)H(C)}$ (or arith/min/max variants) | `sklearn.metrics.normalized_mutual_info_score` | Different normalisations give different values; permutation-invariant. |

## 5. Code Snippets

The lecture's code is mostly R, but the project pipeline is Python. The
snippets below paraphrase the key R demos and pair each with the Python
equivalent for the CPBL notebook.

### 5.1 Confusion matrix (R, decision tree on German Credit Data)

```r
library(rpart)
load('GCDData.RData')
model <- rpart(Good.Loan ~ Duration.in.month +
               Installment.rate.in.percentage.of.disposable.income +
               Credit.amount + Other.installment.plans,
               data=d, control=rpart.control(maxdepth=4),
               method="class")

resultframe <- data.frame(Good.Loan=creditdata$Good.Loan,
                          pred=predict(model, type="class"))
rtab <- table(resultframe)   # rows = actual, cols = predicted
```

Python equivalent (for any classifier we use downstream):

```python
from sklearn.metrics import confusion_matrix, classification_report
y_pred = clf.predict(X_test)
print(confusion_matrix(y_test, y_pred))
print(classification_report(y_test, y_pred, digits=3))
```

### 5.2 Spam logistic regression and threshold sweep (R)

```r
spamD     <- read.table('spamD.tsv', header=TRUE, sep='\t')
spamTrain <- subset(spamD, rgroup >= 10)
spamTest  <- subset(spamD, rgroup <  10)
spamVars  <- setdiff(colnames(spamD), c('rgroup','spam'))
spamForm  <- as.formula(paste('spam=="spam"',
                              paste(spamVars, collapse=' + '), sep=' ~ '))
spamModel <- glm(spamForm, family=binomial(link='logit'), data=spamTrain)
spamTest$pred <- predict(spamModel, newdata=spamTest, type='response')

table(truth=spamTest$spam, prediction=spamTest$pred > 0.5)
table(truth=spamTest$spam, prediction=spamTest$pred > 0.9)  # higher precision
table(truth=spamTest$spam, prediction=spamTest$pred > 0.1)  # higher recall
```

### 5.3 ROC curve and AUC with `ROCR` (R)

```r
library(ROCR)
eval <- prediction(spamTest$pred, spamTest$spam)
plot(performance(eval, "tpr", "fpr"))
attributes(performance(eval, "auc"))$y.values[[1]]
```

Python equivalent (used later for CPBL "predict who wins" baseline if any):

```python
from sklearn.metrics import roc_curve, roc_auc_score
fpr, tpr, thr = roc_curve(y_test, scores)
auc = roc_auc_score(y_test, scores)
```

### 5.4 Log-likelihood vs. null model (R)

```r
ll_model <- sum(ifelse(spamTest$spam == 'spam',
                       log(spamTest$pred),
                       log(1 - spamTest$pred)))
pNull <- mean(spamTest$spam == 'spam')
ll_null <- sum(spamTest$spam == 'spam') * log(pNull) +
           sum(spamTest$spam != 'spam') * log(1 - pNull)
# -134.95 (model)  vs.  -306.90 (null)
pseudoR2 <- 1 - (-2 * ll_model) / (-2 * ll_null)
```

Python equivalent (log-loss is per-row average negative LL):

```python
from sklearn.metrics import log_loss
ll = -log_loss(y_test, p_hat, normalize=False)             # total LL
ll_null = -log_loss(y_test, [y_test.mean()]*len(y_test),
                    normalize=False)
pseudo_r2 = 1 - (-2*ll) / (-2*ll_null)
```

### 5.5 K-means clustering and intra/inter distance table (R)

```r
set.seed(32297)
d   <- data.frame(x=runif(100), y=runif(100))
clus <- kmeans(d, centers=5)
d$cluster <- clus$cluster

library(reshape2)
n <- nrow(d)
pairs <- data.frame(
  ca   = as.vector(outer(1:n, 1:n, function(a,b) d[a,'cluster'])),
  cb   = as.vector(outer(1:n, 1:n, function(a,b) d[b,'cluster'])),
  dist = as.vector(outer(1:n, 1:n,
            function(a,b) sqrt((d[a,'x']-d[b,'x'])^2 +
                               (d[a,'y']-d[b,'y'])^2))))
dcast(pairs, ca ~ cb, value.var='dist', mean)
# diagonal = intra, off-diagonal = inter
```

Python equivalent (CPBL pipeline path):

```python
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score, calinski_harabasz_score
from sklearn.preprocessing import StandardScaler
import numpy as np, pandas as pd

X_std = StandardScaler().fit_transform(X)
km    = KMeans(n_clusters=4, n_init=20, random_state=0).fit(X_std)

print('silhouette       :', silhouette_score(X_std, km.labels_))
print('calinski_harabasz:', calinski_harabasz_score(X_std, km.labels_))

# Intra / inter distance matrix
from scipy.spatial.distance import cdist
D = cdist(X_std, X_std)
lbl = km.labels_
tab = pd.DataFrame(D).assign(a=lbl).melt(id_vars='a', var_name='j',
                                          value_name='d')
tab['b'] = lbl[tab['j'].astype(int).values]
intra_inter = tab.groupby(['a','b'])['d'].mean().unstack()
```

### 5.6 External clustering metric (NMI) — R and Python

```r
library(aricode)
NMI(c(0,0,1,1), c(0,0,1,1))   # 1, perfect
NMI(c(0,0,1,1), c(1,1,0,0))   # 1, permutation-invariant
NMI(c(0,0,1,1), c(1,0,0,1))   # 0, no mutual information
```

```python
from sklearn.metrics import normalized_mutual_info_score as nmi
nmi([0,0,1,1], [0,0,1,1])     # 1.0
nmi([0,0,1,1], [1,1,0,0])     # 1.0  (label-permutation invariant)
nmi([0,0,1,1], [1,0,0,1])     # 0.0
```

### 5.7 Sketched 2-D residual plot used in the lecture

```r
d <- data.frame(y=(1:10)^2, x=1:10)
model <- lm(y~x, data=d)
d$prediction <- predict(model, newdata=d)
library(ggplot2)
ggplot(d) + geom_point(aes(x,y)) +
  geom_line(aes(x, prediction), color='blue') +
  geom_segment(aes(x=x, y=prediction, yend=y, xend=x))
```

Python counterpart for a CPBL regression diagnostic:

```python
import matplotlib.pyplot as plt
plt.scatter(X, y, label='actual')
plt.plot(X, y_hat, color='blue', label='prediction')
for xi, yi, ph in zip(X, y, y_hat):
    plt.vlines(xi, ph, yi, colors='gray', linewidth=0.5)
```

## 6. Notable Examples / Datasets

- **German Credit Data** (`GCDData.RData`) — decision tree for predicting
  "Good.Loan"; classic confusion-matrix demo.
- **Spambase** (`spamD.tsv`, full dataset on UCI / `WinVector/zmPDSwR`) —
  logistic regression with `glm(..., family=binomial)`; used to illustrate
  threshold choice, ROC, AUC and log-likelihood vs. null.
- **Akismet spam filter** — practical example for asymmetric Type I / II
  costs (cannot lose a real email).
- **Advertising** (from ISLR Cha. 2 / 3) — used to introduce inference
  questions: which media drive sales? how much does TV add?.
- **HIV diagnostic test** (50% prevalence vs. 1% prevalence) — worked
  example for sensitivity / specificity vs. PPV / NPV.
- **COVID-19 antibody / PCR / rapid testing** (Taiwan 2020) — case study
  where reported PPV ≈ 0.486, illustrating prevalence-dependent metrics.
- **`(1:10)^2` synthetic dataset** — toy regression to visualise residuals.
- **`runif(100)` 2-D points** — toy synthetic clustering, used to show
  "hair" and "waste" clusters and intra/inter distance tables.
- **External benchmarks pointed to**: Tables 3 & 4 of the Genome Biology
  benchmarking paper (Duo et al. 2018-style scRNA clustering comparison)
  and Table II of an IEEE single-cell paper — references for "which
  metric / method is best where".

## 7. Pitfalls

- **Accuracy is misleading under class imbalance.** The null model that
  always predicts the majority class can be 98% accurate while detecting
  zero true positives. Always inspect the confusion matrix and the per-
  class precision / recall.
- **Sensitivity / specificity are prevalence-independent; PPV / NPV are
  not.** Reporting only sensitivity / specificity hides the test's
  decision usefulness in deployment. Recompute predictive values at the
  expected deployment prevalence.
- **R^2 is brittle.** It is defined for a specific dataset and is the
  squared Pearson correlation only under squared loss and the right model
  class. Outside of that, "R^2" returned by `sklearn.metrics.r2_score`
  can go negative (model worse than predicting the mean). r = 0.8 only
  explains 64% of variance.
- **Pearson r ignores shift and scale.** Two series that differ by a
  constant offset still have r = 1; do not conclude that the prediction
  is calibrated.
- **Threshold = 0.5 is arbitrary.** It almost never matches the cost
  trade-off you care about. Pick a threshold from a ROC or PR curve using
  Youden's J, closest-to-(0,1), or max-F1, on a validation split — never
  on the test split.
- **ROC-AUC is optimistic under heavy imbalance.** A very large TN pool
  keeps FPR tiny even when many false positives occur. For rare
  positives (fraud, disease genes), prefer PR-AUC.
- **Hand (2009) coherence problem.** ROC-AUC implicitly uses a cost
  distribution that depends on the classifier itself; do not over-
  interpret tiny AUC differences.
- **Log-likelihood / log-loss blows up at p = 0 or p = 1.** Clip predicted
  probabilities to `[eps, 1-eps]`. Probabilistic metrics need calibrated
  probabilities; tree ensembles often need `CalibratedClassifierCV`.
- **Deviance is not normalised** — only compare on identical datasets.
- **Pseudo-R^2 has many definitions** (McFadden, Cox-Snell, Nagelkerke);
  state which one you use.
- **AIC penalises but does not solve overfitting** — small samples bias
  AIC; consider BIC and out-of-sample evaluation.
- **Multi-class specificity is inflated** by treating each class one-vs-
  rest, because the negative class pool dominates. Compare classes via
  per-class precision / recall and the macro-F1.
- **Micro vs. macro choice matters.** Micro is dominated by frequent
  classes; macro can over-reward classes with very few examples and
  random labels.
- **Choosing k in clustering by silhouette alone is dangerous.**
  Silhouette favours compact, equally-sized, convex clusters; combine
  with Calinski-Harabasz, gap statistic, or domain plausibility checks.
- **Cluster labels are arbitrary.** NMI (and ARI) are permutation-
  invariant — do not compare confusion matrices between clusterings
  directly.
- **"Hair" / "waste" clusters**: a cluster with one or two points is
  usually a degenerate result of k-means initialisation; report cluster
  sizes alongside silhouette scores.
- **Don't pick the metric to make the model look good.** Pick it from
  the business / domain cost of each error type before model selection.

## 8. Cross-references

- **Topic 02 (Measurement 2)** — descriptive statistics and basic
  visualisation; this lecture extends those summaries to model-output
  evaluation.
- **Topic 04 / 05 — PCA and feature explanation**
  (`topic05-1_PCA-SVD.md`, `topic05-2_featureExplain.md`) — uses
  PCA-derived features that we then cluster; the evaluation metrics
  from this lecture (silhouette, CH, NMI) feed back into choosing the
  number of components / clusters.
- **Topic 08 — Unsupervised methods** (`topic08_unsupervised.pptx`) —
  explicit pointer from this lecture for deeper coverage of Silhouette
  and Calinski-Harabasz.
- **ISLR Ch. 2 ("Statistical Learning")** — inference vs. prediction,
  the bias-variance trade-off, the irreducible error term in "estimating
  f".
- **Practical Data Science with R, Ch. 5** — the parent chapter for the
  metric catalogue presented here.
- **R packages**: `rpart`, `glm`, `ROCR`, `aricode`, `reshape2`,
  `ggplot2`.
- **Python equivalents**: `sklearn.metrics`, `scipy.stats.spearmanr`,
  `statsmodels` (deviance, AIC), `sklearn.cluster.KMeans`,
  `sklearn.metrics.normalized_mutual_info_score`.

## 9. Relevance to CPBL Descriptive Stats & EDA (max 5 bullets)

- Senior Wang's consensus features (`run_per_hit`, `innings_pitched`, `H`,
  `scored_first`, `whip_like`, `hr_allowed`, `hits_allowed`, `AB`,
  `middle_runs`, `late_runs`) mix scoring-like and probability-like
  signals. Use **descriptive summaries plus Pearson r** to detect
  redundant pairs before PCA — but remember r is shift/scale invariant,
  so a 0.8 correlation still leaves 36% unique variance and may be worth
  keeping in the unsupervised feature search.
- For the unsupervised "feature discovery" deliverable on 2023+2024 CPBL
  data, evaluate k-means / hierarchical clusters with **silhouette** and
  **Calinski-Harabasz** as internal metrics, and visualise the
  **intra/inter distance matrix** to detect hair/waste clusters. The
  lecture's R demo translates directly to the Python `sklearn` calls in
  Section 5.5.
- Wins / losses or "scored_first" can serve as **weak external labels**
  for cluster validation; compare clusterings of team-game vectors
  against these labels using **NMI** (permutation-invariant, so cluster
  IDs don't need to match the label encoding).
- Class-imbalance lessons apply directly. "Comeback wins" or "shutout
  losses" are rare positives in a season-level dataset, so if we later
  fit any predictive baseline, prefer **PR-AUC / AUPRC** over ROC-AUC and
  set the operating threshold by **max-F1** or **Youden's J**, not 0.5.
- The lecture's residual / R^2 framework anchors the **descriptive stats
  block** of the notebook: when reporting team-level run-scoring models
  or pitcher ERA-like quantities, present RMSE plus R^2, but also include
  the residual plot the lecture shows so reviewers can see whether the
  model under-predicts low-scoring games (a likely CPBL pattern).
